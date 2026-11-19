import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/shuffle_duration.dart';

final class DiscoveryState {
  DiscoveryState({
    Iterable<CatalogCandidate> candidates = const <CatalogCandidate>[],
    this.filter = const CatalogFilter(),
    Map<String, CatalogFilter> presets = const <String, CatalogFilter>{},
    Iterable<String> likedIds = const <String>[],
    Iterable<String> rejectedIds = const <String>[],
    Iterable<String> recentPickIds = const <String>[],
    this.mode = DiscoveryMode.grid,
    this.position = 0,
    this.currentRevealId,
    this.currentPickId,
    this.isHydrated = false,
    this.persistenceError = false,
    this.noEligibleCandidates = false,
    double favoriteBias = 0,
    this.fadeWatched = false,
    this.shuffleDuration = ShuffleDuration.standard,
  }) : favoriteBias = favoriteBias.isNaN ? 0 : favoriteBias.clamp(0, 1),
       candidates = List<CatalogCandidate>.unmodifiable(candidates),
       presets = Map<String, CatalogFilter>.unmodifiable(presets),
       rejectedIds = Set<String>.unmodifiable(rejectedIds),
       likedIds = Set<String>.unmodifiable(
         likedIds.toSet()..removeAll(rejectedIds),
       ),
       recentPickIds = List<String>.unmodifiable(recentPickIds);

  final List<CatalogCandidate> candidates;
  final CatalogFilter filter;
  final Map<String, CatalogFilter> presets;
  final Set<String> likedIds;
  final Set<String> rejectedIds;
  final List<String> recentPickIds;
  final DiscoveryMode mode;
  final int position;
  final String? currentRevealId;
  final String? currentPickId;
  final bool isHydrated;
  final bool persistenceError;
  final bool noEligibleCandidates;

  /// Minimum share of shuffle picks drawn from Jellyfin favorites, 0–1.
  final double favoriteBias;

  /// Whether watched titles are shown dimmed.
  final bool fadeWatched;
  final ShuffleDuration shuffleDuration;

  // Derived lists are computed once per state; every view reads them.
  late final List<CatalogCandidate> filteredCandidates = List.unmodifiable(
    candidates.where(filter.matches),
  );

  late final List<CatalogCandidate> undecidedCandidates = filteredCandidates
      .where(
        (candidate) =>
            !likedIds.contains(candidate.id) &&
            !rejectedIds.contains(candidate.id),
      )
      .toList(growable: false);

  /// Shuffle may pick any unrejected title matching the active filters.
  late final List<CatalogCandidate> eligibleCandidates = filteredCandidates
      .where((candidate) => !rejectedIds.contains(candidate.id))
      .toList(growable: false);

  DiscoveryState copyWith({
    Iterable<CatalogCandidate>? candidates,
    CatalogFilter? filter,
    Map<String, CatalogFilter>? presets,
    Iterable<String>? likedIds,
    Iterable<String>? rejectedIds,
    Iterable<String>? recentPickIds,
    DiscoveryMode? mode,
    int? position,
    Object? currentRevealId = _unset,
    Object? currentPickId = _unset,
    bool? isHydrated,
    bool? persistenceError,
    bool? noEligibleCandidates,
    double? favoriteBias,
    bool? fadeWatched,
    ShuffleDuration? shuffleDuration,
  }) => DiscoveryState(
    candidates: candidates ?? this.candidates,
    filter: filter ?? this.filter,
    presets: presets ?? this.presets,
    likedIds: likedIds ?? this.likedIds,
    rejectedIds: rejectedIds ?? this.rejectedIds,
    recentPickIds: recentPickIds ?? this.recentPickIds,
    mode: mode ?? this.mode,
    position: position ?? this.position,
    currentRevealId: identical(currentRevealId, _unset)
        ? this.currentRevealId
        : currentRevealId as String?,
    currentPickId: identical(currentPickId, _unset)
        ? this.currentPickId
        : currentPickId as String?,
    isHydrated: isHydrated ?? this.isHydrated,
    persistenceError: persistenceError ?? this.persistenceError,
    noEligibleCandidates: noEligibleCandidates ?? this.noEligibleCandidates,
    favoriteBias: favoriteBias ?? this.favoriteBias,
    fadeWatched: fadeWatched ?? this.fadeWatched,
    shuffleDuration: shuffleDuration ?? this.shuffleDuration,
  );
}

const _unset = Object();
