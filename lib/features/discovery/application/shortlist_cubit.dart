import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/discovery_store.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';

enum ShortlistLookup { idle, loading, ready, failed }

final class ShortlistState {
  ShortlistState({
    this.entries = const <ShortlistEntry>[],
    this.movies = const <String, CatalogCandidate>{},
    this.isHydrated = false,
    this.useShortlist = false,
    this.lookup = ShortlistLookup.idle,
    this.pickId,
  });

  final List<ShortlistEntry> entries;
  final Map<String, CatalogCandidate> movies;
  final bool isHydrated;
  final bool useShortlist;
  final ShortlistLookup lookup;
  final String? pickId;

  late final Set<String> _savedIds = entries.map((entry) => entry.id).toSet();

  bool contains(String id) => _savedIds.contains(id);

  late final List<CatalogCandidate> pool = lookup == ShortlistLookup.ready
      ? List.unmodifiable(
          entries
              .map((entry) => movies[entry.id])
              .whereType<CatalogCandidate>(),
        )
      : const <CatalogCandidate>[];

  CatalogCandidate? get pick =>
      lookup == ShortlistLookup.ready && _savedIds.contains(pickId)
      ? movies[pickId]
      : null;

  ShortlistState copyWith({
    List<ShortlistEntry>? entries,
    Map<String, CatalogCandidate>? movies,
    bool? isHydrated,
    bool? useShortlist,
    ShortlistLookup? lookup,
    String? pickId,
    bool clearPick = false,
  }) => ShortlistState(
    entries: entries ?? this.entries,
    movies: movies ?? this.movies,
    isHydrated: isHydrated ?? this.isHydrated,
    useShortlist: useShortlist ?? this.useShortlist,
    lookup: lookup ?? this.lookup,
    pickId: clearPick ? null : pickId ?? this.pickId,
  );
}

final class ShortlistCubit extends Cubit<ShortlistState> {
  ShortlistCubit({
    required this.store,
    required this.loadMovies,
    required this.selector,
  }) : super(ShortlistState());

  final ShortlistStore store;
  final Future<List<CatalogCandidate>> Function(Set<String>) loadMovies;
  final DiscoverySelector selector;
  Future<void>? _hydration;
  Future<void> _writes = Future<void>.value();
  int _lookupRevision = 0;

  Future<void> hydrate() {
    if (state.isHydrated) {
      return Future<void>.value();
    }
    return _hydration ??= _read().whenComplete(() {
      _hydration = null;
    });
  }

  Future<void> _read() async {
    try {
      final entries = await store.read();
      if (!isClosed) {
        emit(
          state.copyWith(entries: List.unmodifiable(entries), isHydrated: true),
        );
      }
    } on Object {
      // Keep edits disabled until a read succeeds so a retry can't erase saves.
    }
  }

  Future<bool> toggle(CatalogCandidate movie) {
    if (movie.mediaType != CatalogMediaType.movie) {
      return Future<bool>.value(false);
    }
    return _edit((entries) {
      if (entries.any((entry) => entry.id == movie.id)) {
        return entries.where((entry) => entry.id != movie.id).toList();
      }
      return [(id: movie.id, title: movie.name), ...entries];
    });
  }

  Future<bool> add(CatalogCandidate movie) =>
      movie.mediaType == CatalogMediaType.movie
      ? restore((id: movie.id, title: movie.name), 0)
      : Future<bool>.value(false);

  Future<bool> remove(String id) => _edit(
    (entries) => entries.any((entry) => entry.id == id)
        ? entries.where((entry) => entry.id != id).toList()
        : entries,
  );

  Future<bool> restore(ShortlistEntry entry, int index) => _edit((entries) {
    if (entries.any((current) => current.id == entry.id)) {
      return entries;
    }
    return [...entries]..insert(index.clamp(0, entries.length), entry);
  });

  Future<bool> _edit(List<ShortlistEntry> Function(List<ShortlistEntry>) edit) {
    final operation = _writes.then((_) async {
      await hydrate();
      if (isClosed || !state.isHydrated) {
        return false;
      }
      final previous = state.entries;
      final edited = edit(previous);
      if (identical(edited, previous)) {
        return true;
      }
      final next = List<ShortlistEntry>.unmodifiable(edited);
      emit(state.copyWith(entries: next));
      try {
        await store.write(next);
      } on Object {
        if (!isClosed) {
          emit(state.copyWith(entries: previous));
        }
        return false;
      }
      if (isClosed) {
        return true;
      }
      final pickId = state.pickId;
      if (pickId != null && !state.contains(pickId)) {
        emit(state.copyWith(clearPick: true));
      }
      if (state.useShortlist && next.length > previous.length) {
        unawaited(refresh());
      }
      return true;
    });
    _writes = operation.then<void>((_) {});
    return operation;
  }

  void selectSource({required bool useShortlist}) {
    if (useShortlist == state.useShortlist) {
      return;
    }
    _lookupRevision++;
    emit(
      state.copyWith(
        useShortlist: useShortlist,
        lookup: ShortlistLookup.idle,
        clearPick: true,
      ),
    );
    if (useShortlist) {
      unawaited(refresh());
    }
  }

  Future<void> refresh() async {
    final revision = ++_lookupRevision;
    emit(state.copyWith(lookup: ShortlistLookup.loading));
    await hydrate();
    if (isClosed || revision != _lookupRevision) {
      return;
    }
    if (!state.isHydrated) {
      emit(state.copyWith(lookup: ShortlistLookup.failed));
      return;
    }
    final ids = state.entries.map((entry) => entry.id).toSet();
    try {
      final results = ids.isEmpty
          ? const <CatalogCandidate>[]
          : await loadMovies(ids);
      if (isClosed || revision != _lookupRevision) {
        return;
      }
      final movies = <String, CatalogCandidate>{
        for (final movie in results)
          if (movie.mediaType == CatalogMediaType.movie &&
              ids.contains(movie.id))
            movie.id: movie,
      };
      emit(
        state.copyWith(
          lookup: ShortlistLookup.ready,
          movies: Map.unmodifiable(movies),
          clearPick: !movies.containsKey(state.pickId),
        ),
      );
    } on Object {
      if (!isClosed && revision == _lookupRevision) {
        emit(state.copyWith(lookup: ShortlistLookup.failed));
      }
    }
  }

  CatalogCandidate? revealNext() {
    final pool = state.pool;
    if (pool.isEmpty) {
      return null;
    }
    final ids = [
      for (final movie in pool)
        if (pool.length == 1 || movie.id != state.pickId) movie.id,
    ];
    final selected = ids.length == 1 ? ids.single : selector.select(ids);
    if (!ids.contains(selected)) {
      return null;
    }
    emit(state.copyWith(pickId: selected));
    return state.pick;
  }

  void setFavorite(String id, bool favorite) {
    final movie = state.movies[id];
    if (movie != null && movie.favorite != favorite) {
      emit(
        state.copyWith(
          movies: Map.unmodifiable({
            ...state.movies,
            id: movie.copyWith(favorite: favorite),
          }),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _writes;
    await super.close();
  }
}
