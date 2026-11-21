import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Handy, built-in filter presets shown in the Presets tab.
///
/// These are UI suggestions only: they are not persisted as user presets and are
/// unaffected by saving, resetting, or clearing discovery data.
List<DiscoverySuggestedPreset> buildDiscoveryDefaultPresets(
  AppLocalizations l10n, {
  CatalogMediaType mediaType = CatalogMediaType.movie,
}) => mediaType == CatalogMediaType.series
    ? _seriesPresets(l10n)
    : _moviePresets(l10n);

List<DiscoverySuggestedPreset> _seriesPresets(
  AppLocalizations l10n,
) => <DiscoverySuggestedPreset>[
  (
    id: 'finish_started',
    label: l10n.discoveryPresetFinishStartedLabel,
    filter: const CatalogFilter(
      watchProgress: <CatalogWatchProgress>{CatalogWatchProgress.inProgress},
      sort: CatalogSort.newEpisodes,
    ),
  ),
  (
    id: 'bingeable_minis',
    label: l10n.discoveryPresetBingeableMinisLabel,
    filter: const CatalogFilter(
      seriesLengths: <CatalogSeriesLength>{CatalogSeriesLength.miniseries},
      seriesStatuses: <CatalogSeriesStatus>{CatalogSeriesStatus.ended},
      watchProgress: <CatalogWatchProgress>{CatalogWatchProgress.notStarted},
    ),
  ),
  (
    id: 'still_airing',
    label: l10n.discoveryPresetStillAiringLabel,
    filter: const CatalogFilter(
      seriesStatuses: <CatalogSeriesStatus>{CatalogSeriesStatus.continuing},
      sort: CatalogSort.newEpisodes,
    ),
  ),
  (
    id: 'unstarted_gems',
    label: l10n.discoveryPresetUnstartedGemsLabel,
    filter: const CatalogFilter(
      watchProgress: <CatalogWatchProgress>{CatalogWatchProgress.notStarted},
      minimumCommunityRating: 7.5,
    ),
  ),
  (
    id: 'favorites',
    label: l10n.discoveryPresetFavoritesLabel,
    filter: const CatalogFilter(favorite: true),
  ),
];

List<DiscoverySuggestedPreset> _moviePresets(
  AppLocalizations l10n,
) => <DiscoverySuggestedPreset>[
  (
    id: 'unwatched',
    label: l10n.discoveryPresetUnwatchedLabel,
    filter: const CatalogFilter(watched: false),
  ),
  (
    id: 'favorites',
    label: l10n.discoveryPresetFavoritesLabel,
    filter: const CatalogFilter(favorite: true),
  ),
  (
    id: 'new_and_unseen',
    label: l10n.discoveryPresetNewAndUnseenLabel,
    filter: const CatalogFilter(
      watched: false,
      addedWithin: CatalogAddedWindow.thirtyDays,
    ),
  ),
  (
    id: 'unwatched_gems',
    label: l10n.discoveryPresetUnwatchedGemsLabel,
    filter: const CatalogFilter(watched: false, minimumCommunityRating: 7.5),
  ),
  (
    id: 'short_gems',
    label: l10n.discoveryPresetShortGemsLabel,
    filter: const CatalogFilter(
      watched: false,
      maximumRuntimeMinutes: 100,
      minimumCommunityRating: 7.0,
    ),
  ),
  (
    id: 'critics_picks',
    label: l10n.discoveryPresetCriticsPicksLabel,
    filter: const CatalogFilter(minimumCriticRating: 75.0),
  ),
];
