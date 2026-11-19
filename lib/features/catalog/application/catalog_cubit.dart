import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_filter.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_result.dart';
import 'package:jellyfilter/features/catalog/domain/failures/catalog_failure.dart';
import 'package:jellyfilter/features/catalog/domain/repositories/catalog_repository.dart';

sealed class CatalogState {
  const CatalogState();
}

final class CatalogIdle extends CatalogState {
  const CatalogIdle();
}

final class CatalogLoading extends CatalogState {
  const CatalogLoading();
}

final class CatalogLoaded extends CatalogState {
  const CatalogLoaded({
    required this.candidates,
    required this.hasMore,
    required this.nextIndex,
    required this.total,
    this.libraries = const <CatalogLibrary>[],
    this.facets = const CatalogFacets(),
    this.failure,
    this.loadingMore = false,
  });

  final List<CatalogCandidate> candidates;
  final bool hasMore;
  final int nextIndex;
  final int total;
  final List<CatalogLibrary> libraries;
  final CatalogFacets facets;
  final CatalogFailure? failure;
  final bool loadingMore;

  CatalogLoaded copyWith({
    List<CatalogCandidate>? candidates,
    bool? hasMore,
    int? nextIndex,
    int? total,
    List<CatalogLibrary>? libraries,
    CatalogFacets? facets,
    Object? failure = _unset,
    bool? loadingMore,
  }) => CatalogLoaded(
    candidates: candidates ?? this.candidates,
    hasMore: hasMore ?? this.hasMore,
    nextIndex: nextIndex ?? this.nextIndex,
    total: total ?? this.total,
    libraries: libraries ?? this.libraries,
    facets: facets ?? this.facets,
    failure: identical(failure, _unset)
        ? this.failure
        : failure as CatalogFailure?,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this.repository) : super(const CatalogIdle());

  final CatalogRepository repository;
  int _generation = 0;
  CatalogFilter _filter = const CatalogFilter();
  Set<String> _excludedIds = const <String>{};
  Set<String> _includedIds = const <String>{};
  List<CatalogLibrary>? _libraries;
  final _facetCache = <String?, CatalogFacets>{};
  final _detailCache = <String, CatalogResult<CatalogCandidate>>{};

  Future<void> load({
    CatalogFilter filter = const CatalogFilter(),
    Set<String> excludedIds = const <String>{},
    Set<String> includedIds = const <String>{},
  }) async {
    final generation = ++_generation;
    if (isClosed) {
      return;
    }
    emit(const CatalogLoading());
    _filter = filter;
    _excludedIds = Set<String>.unmodifiable(excludedIds);
    _includedIds = Set<String>.unmodifiable(includedIds);
    final librariesRequest = _libraries == null
        ? repository.loadLibraries()
        : Future<CatalogResult<List<CatalogLibrary>>>.value(
            CatalogResult<List<CatalogLibrary>>.success(_libraries),
          );
    final parentId = filter.libraryId;
    final cachedFacets = _facetCache[parentId];
    final facetsRequest = cachedFacets == null
        ? repository.loadFacets(parentId: parentId)
        : Future<CatalogResult<CatalogFacets>>.value(
            CatalogResult<CatalogFacets>.success(cachedFacets),
          );
    final pageRequest = repository.loadPage(
      filter: filter,
      excludedIds: _excludedIds,
      includedIds: _includedIds,
    );
    final page = await pageRequest;
    if (isClosed || generation != _generation) {
      return;
    }
    emit(
      CatalogLoaded(
        candidates: List<CatalogCandidate>.unmodifiable(
          page.candidates.map(_withKnownFavorite),
        ),
        hasMore: page.hasMore,
        nextIndex: page.nextIndex,
        total: page.total,
        libraries: _libraries ?? const <CatalogLibrary>[],
        facets: cachedFacets ?? const CatalogFacets(),
        failure: page.failure,
      ),
    );
    final librariesResult = await librariesRequest;
    final facetsResult = await facetsRequest;
    if (isClosed || generation != _generation) {
      return;
    }
    if (librariesResult.value case final libraries?) {
      _libraries = libraries;
    }
    if (facetsResult.value case final facets?) {
      _facetCache[parentId] = facets;
    }
    final current = state;
    if (current is CatalogLoaded) {
      emit(
        current.copyWith(
          libraries: _libraries ?? const <CatalogLibrary>[],
          facets: _facetCache[parentId] ?? const CatalogFacets(),
          failure:
              current.failure ??
              librariesResult.failure ??
              facetsResult.failure,
        ),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! CatalogLoaded ||
        !current.hasMore ||
        current.loadingMore ||
        isClosed) {
      return;
    }
    final generation = _generation;
    emit(current.copyWith(loadingMore: true));
    final page = await repository.loadPage(
      filter: _filter,
      startIndex: current.nextIndex,
      excludedIds: _excludedIds,
      includedIds: _includedIds,
    );
    // Merge onto the latest state, not the one captured before the request,
    // so favorite changes made meanwhile are not overwritten.
    final latest = state;
    if (isClosed || generation != _generation || latest is! CatalogLoaded) {
      return;
    }
    final candidates = <String, CatalogCandidate>{
      for (final candidate in latest.candidates) candidate.id: candidate,
      for (final candidate in page.candidates)
        candidate.id: _withKnownFavorite(candidate),
    }.values.toList(growable: false);
    emit(
      latest.copyWith(
        candidates: List<CatalogCandidate>.unmodifiable(candidates),
        hasMore: page.hasMore,
        nextIndex: page.nextIndex,
        total: page.total,
        failure: page.failure,
        loadingMore: false,
      ),
    );
  }

  Future<CatalogResult<CatalogCandidate>> loadDetails(String itemId) async {
    final normalizedId = itemId.trim();
    final cached = _detailCache[normalizedId];
    if (cached != null) {
      return cached;
    }
    final since = _favoriteEpoch;
    final result = await repository.loadDetails(normalizedId);
    final details = result.value;
    if (details != null) {
      // Details are fetched fresh, so they carry Jellyfin's favorite state,
      // unless the user toggled the title while the request was in flight.
      final favorite = details.favorite;
      final override = _favoriteOverrides[normalizedId];
      final newer = override != null && override.epoch > since;
      _detailCache[normalizedId] = newer
          ? CatalogResult<CatalogCandidate>.success(
              details.copyWith(favorite: override.value),
            )
          : result;
      if (favorite != null && !newer) {
        _favoriteOverrides.remove(normalizedId);
        _patchFavorites((id) => id == normalizedId ? favorite : null);
      }
    }
    return _detailCache[normalizedId] ?? result;
  }

  /// The latest known favorite state of [itemId], including local changes
  /// that Jellyfin has not confirmed yet.
  bool? favoriteOf(String itemId) {
    final override = _favoriteOverrides[itemId];
    if (override != null) {
      return override.value;
    }
    final current = state;
    if (current is! CatalogLoaded) {
      return null;
    }
    return current.candidates
        .where((candidate) => candidate.id == itemId)
        .firstOrNull
        ?.favorite;
  }

  /// Records tags just saved to Jellyfin on the loaded title and its details.
  void setTags(String itemId, Iterable<String> tags) {
    final updated = Set<String>.unmodifiable(tags);
    final cached = _detailCache[itemId]?.value;
    if (cached != null) {
      _detailCache[itemId] = CatalogResult<CatalogCandidate>.success(
        cached.copyWith(tags: updated),
      );
    }
    final current = state;
    if (current is! CatalogLoaded || isClosed) {
      return;
    }
    final index = current.candidates.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      return;
    }
    final candidates = List<CatalogCandidate>.of(current.candidates);
    candidates[index] = candidates[index].copyWith(tags: updated);
    emit(
      current.copyWith(
        candidates: List<CatalogCandidate>.unmodifiable(candidates),
      ),
    );
  }

  /// Records a local favorite change (optimistic or confirmed) everywhere
  /// this cubit holds the item. It outranks any server answer that was
  /// requested before it.
  void setFavorite(String itemId, bool favorite) {
    _favoriteOverrides[itemId] = (value: favorite, epoch: ++_favoriteEpoch);
    _patchFavorites((id) => id == itemId ? favorite : null);
  }

  /// Re-reads the user's favorites from Jellyfin and corrects every loaded
  /// title. Titles toggled locally while the request was in flight keep the
  /// newer local value. Returns whether the sync succeeded.
  Future<bool> syncFavorites() async {
    final since = _favoriteEpoch;
    final result = await repository.loadFavoriteIds();
    final ids = result.value;
    if (ids == null || isClosed) {
      return false;
    }
    _favoriteOverrides.removeWhere((_, override) => override.epoch <= since);
    _patchFavorites((id) => _favoriteOverrides[id]?.value ?? ids.contains(id));
    return true;
  }

  /// Orders local favorite changes against server reads.
  int _favoriteEpoch = 0;

  /// Local favorite changes not yet superseded by a later server read. A page
  /// or sync requested before a change landed would otherwise revert it.
  final Map<String, ({bool value, int epoch})> _favoriteOverrides =
      <String, ({bool value, int epoch})>{};

  CatalogCandidate _withKnownFavorite(CatalogCandidate candidate) {
    final favorite = _favoriteOverrides[candidate.id]?.value;
    return favorite == null || candidate.favorite == favorite
        ? candidate
        : candidate.copyWith(favorite: favorite);
  }

  void _patchFavorites(bool? Function(String id) favoriteFor) {
    for (final entry in _detailCache.entries.toList()) {
      final details = entry.value.value;
      final favorite = favoriteFor(entry.key);
      if (details != null && favorite != null && details.favorite != favorite) {
        _detailCache[entry.key] = CatalogResult<CatalogCandidate>.success(
          details.copyWith(favorite: favorite),
        );
      }
    }
    final current = state;
    if (current is! CatalogLoaded || isClosed) {
      return;
    }
    var changed = false;
    final patched = <CatalogCandidate>[];
    for (final candidate in current.candidates) {
      final favorite = favoriteFor(candidate.id);
      if (favorite != null && candidate.favorite != favorite) {
        changed = true;
        patched.add(candidate.copyWith(favorite: favorite));
      } else {
        patched.add(candidate);
      }
    }
    if (changed) {
      emit(
        current.copyWith(
          candidates: List<CatalogCandidate>.unmodifiable(patched),
        ),
      );
    }
  }
}

const _unset = Object();
