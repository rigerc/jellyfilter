import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/media_affinity.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/failures/taste_failure.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/recommendation_engine.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/taste_features.dart';
import 'package:jellyfilter/features/recommendations/domain/repositories/taste_repository.dart';

final class RecommendationState {
  RecommendationState({
    MediaAffinity? affinity,
    this.isActive = false,
    this.isLearning = false,
  }) : affinity = affinity ?? MediaAffinity.empty;

  final MediaAffinity affinity;

  /// Whether the user has asked for recommendations this session. Nothing
  /// is fetched before then.
  final bool isActive;

  /// Whether history or people data is still being fetched.
  final bool isLearning;

  RecommendationState copyWith({
    MediaAffinity? affinity,
    bool? isActive,
    bool? isLearning,
  }) => RecommendationState(
    affinity: affinity ?? this.affinity,
    isActive: isActive ?? this.isActive,
    isLearning: isLearning ?? this.isLearning,
  );
}

/// Learns the user's taste from Jellyfin history and local choices, then
/// ranks the loaded catalog.
///
/// Learning happens in stages, re-ranking after each: watch history, the
/// catalog details of chosen titles outside the catalog, people for the
/// strongest evidence, then the movies of the strongest people.
final class RecommendationCubit extends Cubit<RecommendationState> {
  RecommendationCubit({required this.repository, DateTime Function()? now})
    : _clock = now ?? _utcNow,
      super(RecommendationState());

  /// Evidence movies whose people are fetched.
  static const evidencePeopleLimit = 150;

  /// Profile people whose movies are looked up.
  static const personLimit = 25;

  /// Chosen titles outside the catalog whose details are fetched.
  static const choiceLookupLimit = 500;

  final TasteRepository repository;
  final DateTime Function() _clock;

  List<CatalogCandidate> _candidates = const <CatalogCandidate>[];
  LocalTasteChoices _choices = LocalTasteChoices.none;
  List<TasteItem>? _history;
  final Map<String, TasteItem> _lookedUpItems = <String, TasteItem>{};
  final Set<String> _lookupRequested = <String>{};
  final Map<String, List<TastePerson>> _people = <String, List<TastePerson>>{};
  final Set<String> _peopleRequested = <String>{};
  final Map<String, Set<String>> _personMovies = <String, Set<String>>{};
  final Set<String> _personRequested = <String>{};
  RankingResult? _ranking;
  Future<void>? _learning;
  bool _dirty = false;

  /// Completes once the current learning pass, if any, has finished.
  Future<void> get settled => _learning ?? Future<void>.value();

  /// Replaces the titles to rank and the choices that shape taste.
  Future<void> update({
    required List<CatalogCandidate> candidates,
    required LocalTasteChoices choices,
  }) {
    if (identical(candidates, _candidates) && choices.sameAs(_choices)) {
      return settled;
    }
    _candidates = candidates;
    _choices = choices;
    if (!state.isActive) {
      return settled;
    }
    _rank();
    return _learn();
  }

  /// Starts learning and ranking. Later calls do nothing.
  Future<void> activate() {
    if (isClosed || state.isActive) {
      return settled;
    }
    emit(state.copyWith(isActive: true));
    _rank();
    return _learn();
  }

  /// Reads watch history again, such as after returning to the app.
  Future<void> refreshHistory() {
    if (isClosed || !state.isActive) {
      return settled;
    }
    _history = null;
    return _learn();
  }

  Future<void> _learn() {
    _dirty = true;
    return _learning ??= _runLearning().whenComplete(() => _learning = null);
  }

  Future<void> _runLearning() async {
    _emit(state.copyWith(isLearning: true));
    while (_dirty && !isClosed) {
      _dirty = false;
      await _step();
    }
    _emit(state.copyWith(isLearning: false));
  }

  Future<void> _step() async {
    if (_history == null) {
      try {
        _history = await repository.loadHistory();
      } on TasteFailure {
        // Rank from the catalog alone; a later refresh tries again.
        _history = const <TasteItem>[];
      }
      _rank();
    }
    if (isClosed) {
      return;
    }

    final known = _evidence().keys.toSet();
    final missing = _choices.allIds
        .where((id) => !known.contains(id) && !_lookupRequested.contains(id))
        .take(choiceLookupLimit)
        .toSet();
    if (missing.isNotEmpty) {
      _lookupRequested.addAll(missing);
      try {
        for (final item in await repository.loadItems(missing)) {
          _lookedUpItems[item.id] = item;
        }
      } on TasteFailure {
        // Those choices simply do not count.
      }
      _rank();
    }
    if (isClosed) {
      return;
    }

    final needPeople =
        (_ranking?.strongestEvidenceIds(evidencePeopleLimit) ??
                const <String>[])
            .where((id) => !_peopleRequested.contains(id))
            .toSet();
    if (needPeople.isNotEmpty) {
      _peopleRequested.addAll(needPeople);
      try {
        final items = await repository.loadItems(needPeople, withPeople: true);
        for (final item in items) {
          _people[item.id] = item.people;
        }
      } on TasteFailure {
        // Rank on genres, studios, tags, and decades alone.
      }
      _rank();
    }
    if (isClosed) {
      return;
    }

    final needPersons =
        (_ranking?.strongestPeople(personLimit) ?? const <TastePersonRef>[])
            .where(
              (person) => !_personRequested.contains(
                TasteFeatures.personKey(person.role, person.id),
              ),
            )
            .toList(growable: false);
    if (needPersons.isEmpty) {
      return;
    }
    for (final person in needPersons) {
      final key = TasteFeatures.personKey(person.role, person.id);
      _personRequested.add(key);
      try {
        _personMovies[key] = await repository.loadMovieIdsWithPerson(
          person.id,
          person.role,
        );
      } on TasteFailure {
        // Skip this person.
      }
      if (isClosed) {
        return;
      }
    }
    _rank();
    // New people data can surface new strongest evidence or people.
    _dirty = true;
  }

  /// Every movie with known traits, freshest data last.
  Map<String, TasteItem> _evidence() {
    final items = <String, TasteItem>{
      for (final item in _history ?? const <TasteItem>[]) item.id: item,
      ..._lookedUpItems,
      for (final candidate in _candidates) candidate.id: _toItem(candidate),
    };
    for (final MapEntry(key: id, value: people) in _people.entries) {
      final item = items[id];
      if (item != null) {
        items[id] = item.withPeople(people);
      }
    }
    return items;
  }

  void _rank() {
    if (isClosed || !state.isActive) {
      return;
    }
    final evidence = _evidence();
    final ranking = RecommendationEngine.rank(
      candidates: _candidates
          .map((candidate) => evidence[candidate.id])
          .whereType<TasteItem>(),
      evidence: evidence.values,
      choices: _choices,
      now: _clock(),
      personMovies: _personMovies,
    );
    _ranking = ranking;
    _emit(state.copyWith(affinity: ranking.affinity));
  }

  void _emit(RecommendationState next) {
    if (!isClosed) {
      emit(next);
    }
  }

  static TasteItem _toItem(CatalogCandidate candidate) => TasteItem(
    id: candidate.id,
    name: candidate.name,
    genres: candidate.genres,
    studios: candidate.studios,
    tags: candidate.tags,
    year: candidate.year,
    communityRating: candidate.communityRating,
    played: candidate.watched == true,
    playCount: candidate.playCount ?? 0,
    favorite: candidate.favorite == true,
    likes: candidate.likes,
    rating: candidate.userRating,
    lastPlayed: candidate.lastPlayed,
  );

  static DateTime _utcNow() => DateTime.now().toUtc();
}
