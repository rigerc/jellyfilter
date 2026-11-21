import 'package:flutter/material.dart';
import 'package:jellyfilter/core/assets/app_assets.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/domain/entities/browse_layout.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_header_actions.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_media_scope.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

final class DiscoveryHeader extends StatelessWidget {
  const DiscoveryHeader({
    required this.candidateCount,
    required this.onOpenFilters,
    required this.onClear,
    required this.filter,
    this.onSortChanged,
    this.onSortReversedChanged,
    this.fadeWatched = false,
    this.onFadeWatchedChanged,
    this.browseLayout = BrowseLayout.grid,
    this.onBrowseLayoutChanged,
    super.key,
  });

  final ValueChanged<CatalogSort>? onSortChanged;
  final ValueChanged<bool>? onSortReversedChanged;
  final bool fadeWatched;
  final ValueChanged<bool>? onFadeWatchedChanged;
  final BrowseLayout browseLayout;
  final ValueChanged<BrowseLayout>? onBrowseLayoutChanged;

  final int? candidateCount;
  final VoidCallback? onOpenFilters;
  final VoidCallback onClear;
  final CatalogFilter filter;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = DiscoveryMediaScope.maybeOf(context);
    final mediaType = media?.mediaType ?? CatalogMediaType.movie;
    final onMediaChanged = media?.onChanged;
    final canSwitch = media != null && media.canSwitch;
    final series = mediaType == CatalogMediaType.series;
    // With both kinds on the server the brand and title become one switch,
    // and the title names what is on screen.
    final title = !canSwitch
        ? localization.discoveryTitle
        : series
        ? localization.discoveryShowsLabel
        : localization.discoveryMoviesLabel;
    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: CandyTypography.display,
            fontWeight: CandyTypography.displayWeight,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (candidateCount case final count?)
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : CandyMotion.quick,
            child: Text(
              localization.discoveryCandidateCount(count, mediaType.name),
              key: ValueKey<int>(count),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
    final onSwitch = canSwitch ? onMediaChanged : null;
    return Row(
      spacing: CandySpacing.compact,
      children: <Widget>[
        Expanded(
          child: onSwitch != null
              ? DiscoveryMediaToggle(
                  selected: mediaType,
                  onChanged: onSwitch,
                  child: heading,
                )
              : Row(
                  spacing: CandySpacing.compact,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(CandyShapes.compact),
                      child: ExcludeSemantics(
                        child: Image.asset(
                          AppAssets.appIcon,
                          width: CandyIconSize.brand,
                          height: CandyIconSize.brand,
                          cacheWidth: CandyImages.artworkCacheWidth,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    Expanded(child: heading),
                  ],
                ),
        ),
        DiscoveryHeaderActions(
          filterActive: filter.isActive,
          onOpenFilters: onOpenFilters,
          onClear: onClear,
          sort: filter.sort,
          sortReversed: filter.sortReversed,
          onSortChanged: onSortChanged,
          onSortReversedChanged: onSortReversedChanged,
          fadeWatched: fadeWatched,
          onFadeWatchedChanged: onFadeWatchedChanged,
          browseLayout: browseLayout,
          onBrowseLayoutChanged: onBrowseLayoutChanged,
          series: series,
        ),
      ],
    );
  }
}
