import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/media/entities/media_affinity.dart';
import 'package:jellyfilter/features/discovery/domain/entities/browse_layout.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/domain/entities/shuffle_duration.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/discovery_store.dart';

final class DiscoveryCubit extends Cubit<DiscoveryState> {
  DiscoveryCubit({
    required this.store,
    required this.scopeKey,
    required this.selector,
    this.mediaType = CatalogMediaType.movie,
    DateTime Function()? now,
  }) : _clock = now ?? _utcNow,
       super(DiscoveryState(mediaType: mediaType));

  /// The kind of title this cubit discovers. Filters are trimmed to it.
  final CatalogMediaType mediaType;
  final DiscoveryStore store;
  final String scopeKey;
  final DiscoverySelector selector;
  final DateTime Function() _clock;
  int _generation = 0;

  /// The snapshot storage will hold once queued writes finish, so unchanged
  /// state is not rewritten.
  DiscoverySnapshot? _lastWritten;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> hydrate() async {
    final generation = ++_generation;
    DiscoverySnapshot? snapshot;
    var failed = false;
    await _writeQueue;
    try {
      snapshot = await store.read(scopeKey);
    } on Object catch (_) {
      failed = true;
    }
    if (isClosed || generation != _generation) {
      return;
    }
    final restored = snapshot;
    if (restored == null) {
      emit(state.copyWith(isHydrated: true, persistenceError: failed));
      return;
    }
    _lastWritten = restored;
    emit(
      state.copyWith(
        filter: _withFreshDateWindowAnchor(_forMediaType(restored.filter)),
        presets: restored.presets.map(
          (name, filter) => MapEntry(name, _forMediaType(filter)),
        ),
        likedIds: restored.likedIds,
        rejectedIds: restored.rejectedIds,
        recentPickIds: restored.recentPickIds,
        mode: restored.mode,
        position: restored.position,
        currentRevealId: restored.currentRevealId,
        currentPickId: restored.currentPickId,
        favoriteBias: restored.favoriteBias,
        fadeWatched: restored.fadeWatched,
        shuffleDuration: restored.shuffleDuration,
        browseLayout: restored.browseLayout,
        isHydrated: true,
        persistenceError: failed,
      ),
    );
  }

  Future<void> replaceCandidates(Iterable<CatalogCandidate> candidates) =>
      _commit(_withCandidates(List<CatalogCandidate>.of(candidates)));

  Future<void> appendCandidates(Iterable<CatalogCandidate> candidates) =>
      _commit(
        _withCandidates(<CatalogCandidate>[...state.candidates, ...candidates]),
      );

  Future<void> updateCandidate(CatalogCandidate candidate) {
    final index = state.candidates.indexWhere(
      (current) => current.id == candidate.id,
    );
    final favorite = candidate.favorite;
    if (index < 0 ||
        favorite == null ||
        state.candidates[index].favorite == favorite) {
      return Future<void>.value();
    }
    final candidates = List<CatalogCandidate>.of(state.candidates);
    candidates[index] = candidates[index].copyWith(favorite: favorite);
    return _commit(_withCandidates(candidates));
  }

  Future<void> updateFilter(CatalogFilter filter) =>
      _commit(_withFilter(_withFreshDateWindowAnchor(_forMediaType(filter))));

  /// Takes on the view settings of [other], the session being left, so
  /// switching between movies and shows keeps the same tab and layout.
  Future<void> adoptPresentation(DiscoveryState other) => _commit(
    state.copyWith(
      mode: other.mode,
      browseLayout: other.browseLayout,
      fadeWatched: other.fadeWatched,
      shuffleDuration: other.shuffleDuration,
    ),
  );

  CatalogFilter _forMediaType(CatalogFilter filter) =>
      filter.forMediaType(mediaType);

  Future<void> resetFilters() => updateFilter(const CatalogFilter());

  Future<void> setMode(DiscoveryMode mode) =>
      _commit(state.copyWith(mode: mode));

  /// Replaces the personal ranking. It is rebuilt each session, never saved.
  Future<void> updateAffinity(MediaAffinity affinity) =>
      identical(affinity, state.affinity)
      ? Future<void>.value()
      : _commit(state.copyWith(affinity: affinity));

  /// Switches Shuffle between the filtered titles and the best personal
  /// matches among them.
  Future<void> setShuffleForYou(bool forYou) => forYou == state.shuffleForYou
      ? Future<void>.value()
      : _commit(
          state.copyWith(
            shuffleForYou: forYou,
            currentRevealId: null,
            currentPickId: null,
          ),
        );

  Future<void> setFadeWatched(bool fade) => fade == state.fadeWatched
      ? Future<void>.value()
      : _commit(state.copyWith(fadeWatched: fade));

  Future<void> setShuffleDuration(ShuffleDuration duration) =>
      duration == state.shuffleDuration
      ? Future<void>.value()
      : _commit(state.copyWith(shuffleDuration: duration));

  Future<void> setBrowseLayout(BrowseLayout layout) =>
      layout == state.browseLayout
      ? Future<void>.value()
      : _commit(state.copyWith(browseLayout: layout));

  /// Sets how strongly Shuffle favors Jellyfin favorites, snapped to 5% steps.
  Future<void> setFavoriteBias(double bias) {
    final normalized = bias.isFinite
        ? ((bias.clamp(0, 1) * 20).round() / 20).toDouble()
        : 0.0;
    if (normalized == state.favoriteBias) {
      return Future<void>.value();
    }
    return _commit(state.copyWith(favoriteBias: normalized));
  }

  Future<void> like(String id) {
    if (!_isUndecided(id)) {
      return Future<void>.value();
    }
    return _commit(
      state.copyWith(
        likedIds: <String>{...state.likedIds, id},
        position: _nextPosition,
      ),
    );
  }

  Future<void> reject(String id) {
    if (!_isUndecided(id)) {
      return Future<void>.value();
    }
    final clearReveal = state.currentRevealId == id;
    return _commit(
      state.copyWith(
        rejectedIds: <String>{...state.rejectedIds, id},
        position: _nextPosition,
        currentRevealId: clearReveal ? null : state.currentRevealId,
        currentPickId: clearReveal ? null : state.currentPickId,
      ),
    );
  }

  Future<void> dismiss(String id) => reject(id);

  Future<void> clearReveal() =>
      _commit(state.copyWith(currentRevealId: null, currentPickId: null));

  Future<void> revealNext() {
    final eligible = state.eligibleCandidates;
    if (eligible.isEmpty) {
      return _commit(
        state.copyWith(
          currentRevealId: null,
          currentPickId: null,
          noEligibleCandidates: true,
        ),
      );
    }
    final alternatives = eligible
        .where((candidate) => !state.recentPickIds.contains(candidate.id))
        .toList(growable: false);
    final fresh = alternatives.isEmpty ? eligible : alternatives;
    final matches = state.shuffleForYou
        ? _forYouPool(fresh)
        : const <CatalogCandidate>[];
    final pool = matches.isNotEmpty ? matches : _favoredPool(fresh, eligible);
    final selectedId = matches.isNotEmpty
        ? _weightedPick(matches)
        : selector.select(
            pool.map((candidate) => candidate.id).toList(growable: false),
          );
    if (selectedId == null ||
        !pool.any((candidate) => candidate.id == selectedId)) {
      return Future<void>.value();
    }
    final recent = <String>[...state.recentPickIds, selectedId];
    return _commit(
      state.copyWith(
        recentPickIds: recent.length > 50
            ? recent.sublist(recent.length - 50)
            : recent,
        currentRevealId: selectedId,
        currentPickId: selectedId,
        noEligibleCandidates: false,
      ),
    );
  }

  /// Saves [filter] (the applied filter by default) under [name].
  /// Narrows [pool] to favorites on a roll under the favorite bias. When every
  /// favorite was picked recently, recent favorites are allowed again so a
  /// strong bias still lands on one.
  List<CatalogCandidate> _favoredPool(
    List<CatalogCandidate> pool,
    List<CatalogCandidate> eligible,
  ) {
    final bias = state.favoriteBias;
    if (bias <= 0) {
      return pool;
    }
    bool isFavorite(CatalogCandidate candidate) => candidate.favorite == true;
    var favorites = pool.where(isFavorite).toList(growable: false);
    if (favorites.isEmpty) {
      favorites = eligible.where(isFavorite).toList(growable: false);
    }
    if (favorites.isEmpty || selector.nextChance() >= bias) {
      return pool;
    }
    return favorites;
  }

  /// How many of the best personal matches Shuffle chooses between.
  static const forYouPoolSize = 30;

  /// The best-ranked titles in [pool], best first. Empty when none are
  /// ranked, so Shuffle falls back to the whole pool.
  List<CatalogCandidate> _forYouPool(List<CatalogCandidate> pool) {
    final affinity = state.affinity;
    final ranked =
        pool
            .where((candidate) => affinity.rankOf(candidate.id) != null)
            .toList()
          ..sort(
            (left, right) => (affinity.rankOf(left.id) ?? 0).compareTo(
              affinity.rankOf(right.id) ?? 0,
            ),
          );
    return ranked.take(forYouPoolSize).toList(growable: false);
  }

  /// Picks from [ranked] with linearly falling odds: the best match is
  /// [forYouPoolSize] times likelier than the last.
  String _weightedPick(List<CatalogCandidate> ranked) {
    final count = ranked.length;
    final total = count * (count + 1) / 2;
    var roll = selector.nextChance().clamp(0.0, 1.0) * total;
    for (final (index, candidate) in ranked.indexed) {
      roll -= count - index;
      if (roll < 0) {
        return candidate.id;
      }
    }
    return ranked.last.id;
  }

  Future<void> savePreset(String name, {CatalogFilter? filter}) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 50) {
      throw ArgumentError.value(name, 'name', 'must be 1–50 characters');
    }
    final presets = <String, CatalogFilter>{
      ...state.presets,
      normalized: _forMediaType(filter ?? state.filter),
    };
    final boundedPresets = presets.length > 20
        ? Map<String, CatalogFilter>.fromEntries(
            presets.entries.skip(presets.length - 20),
          )
        : presets;
    return _commit(state.copyWith(presets: boundedPresets));
  }

  Future<void> applyPreset(String name) {
    final filter = state.presets[name.trim()];
    return filter == null ? Future<void>.value() : updateFilter(filter);
  }

  Future<void> deletePreset(String name) {
    final normalized = name.trim();
    if (!state.presets.containsKey(normalized)) {
      return Future<void>.value();
    }
    final presets = Map<String, CatalogFilter>.of(state.presets)
      ..remove(normalized);
    return _commit(state.copyWith(presets: presets));
  }

  Future<void> clearDiscovery() async {
    final generation = ++_generation;
    _lastWritten = null;
    emit(
      state.copyWith(
        filter: const CatalogFilter(),
        presets: const <String, CatalogFilter>{},
        likedIds: const <String>{},
        rejectedIds: const <String>{},
        recentPickIds: const <String>[],
        position: 0,
        currentRevealId: null,
        currentPickId: null,
        persistenceError: false,
        noEligibleCandidates: false,
      ),
    );
    await _enqueue(() async {
      try {
        await store.clear(scopeKey);
      } on Object catch (_) {
        if (!isClosed && generation == _generation) {
          emit(state.copyWith(persistenceError: true));
        }
      }
    });
  }

  Future<void> _commit(DiscoveryState next) async {
    if (isClosed) {
      return;
    }
    final snapshot = _snapshotFromState(next);
    if (snapshot == _lastWritten) {
      // Only unsaved fields (such as candidates) changed: skip the write.
      emit(next);
      return;
    }
    final generation = ++_generation;
    // Writes run in order, so the last one queued is what storage will hold.
    _lastWritten = snapshot;
    emit(next);
    await _enqueue(() async {
      try {
        await store.write(scopeKey, snapshot);
      } on Object catch (_) {
        if (identical(_lastWritten, snapshot)) {
          _lastWritten = null;
        }
        if (!isClosed && generation == _generation) {
          emit(state.copyWith(persistenceError: true));
        }
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    _writeQueue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  DiscoveryState _withCandidates(List<CatalogCandidate> candidates) {
    final unique = <String, CatalogCandidate>{};
    // Each cubit discovers one kind of title; strays never reach its views.
    for (final candidate in candidates.where(
      (candidate) => candidate.mediaType == mediaType,
    )) {
      unique.putIfAbsent(candidate.id, () => candidate);
    }
    final values = unique.values.toList(growable: false);
    // A refreshed list (say, a favorite toggled on the current pick) keeps the
    // pick on screen until the next spin, even if it no longer fits a filter.
    final current = state.currentRevealId;
    final stillListed =
        current != null &&
        !state.rejectedIds.contains(current) &&
        values.any((item) => item.id == current);
    final reveal = stillListed
        ? current
        : _validReveal(values, state.filter, current);
    final next = state.copyWith(
      candidates: values,
      currentRevealId: reveal,
      currentPickId: reveal == null ? null : state.currentPickId,
    );
    return next.copyWith(
      noEligibleCandidates: reveal == null && next.eligibleCandidates.isEmpty,
    );
  }

  DiscoveryState _withFilter(CatalogFilter filter) {
    final reveal = _validReveal(
      state.candidates,
      filter,
      state.currentRevealId,
    );
    final next = state.copyWith(
      filter: filter,
      currentRevealId: reveal,
      currentPickId: reveal == null ? null : state.currentPickId,
    );
    return next.copyWith(
      noEligibleCandidates: reveal == null && next.eligibleCandidates.isEmpty,
    );
  }

  bool _isUndecided(String id) =>
      state.undecidedCandidates.any((candidate) => candidate.id == id);

  int get _nextPosition => state.position + 1;

  String? _validReveal(
    List<CatalogCandidate> candidates,
    CatalogFilter filter,
    String? reveal,
  ) {
    if (reveal == null) {
      return null;
    }
    final candidate = candidates.where((item) => item.id == reveal).firstOrNull;
    if (candidate == null || !filter.matches(candidate)) {
      return null;
    }
    if (state.rejectedIds.contains(reveal)) {
      return null;
    }
    return reveal;
  }

  DiscoverySnapshot _snapshotFromState(DiscoveryState value) =>
      DiscoverySnapshot(
        filter: value.filter,
        presets: value.presets,
        likedIds: value.likedIds,
        rejectedIds: value.rejectedIds,
        recentPickIds: value.recentPickIds,
        mode: value.mode,
        position: value.position,
        currentRevealId: value.currentRevealId,
        currentPickId: value.currentPickId,
        favoriteBias: value.favoriteBias,
        fadeWatched: value.fadeWatched,
        shuffleDuration: value.shuffleDuration,
        browseLayout: value.browseLayout,
      );

  CatalogFilter _withFreshDateWindowAnchor(CatalogFilter filter) {
    if (filter.addedWithin == null && filter.dateWindowAnchor == null) {
      return filter;
    }
    return filter.copyWith(
      dateWindowAnchor: filter.addedWithin == null ? null : _clock().toUtc(),
    );
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}
