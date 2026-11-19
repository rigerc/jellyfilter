import 'package:flutter/material.dart';
import 'package:jellyfin_picker/core/assets/app_assets.dart';
import 'package:jellyfin_picker/core/media/entities/catalog_filter.dart';
import 'package:jellyfin_picker/core/theme/candy_theme.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_header_actions.dart';
import 'package:jellyfin_picker/l10n/generated/app_localizations.dart';

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
    super.key,
  });

  final ValueChanged<CatalogSort>? onSortChanged;
  final ValueChanged<bool>? onSortReversedChanged;
  final bool fadeWatched;
  final ValueChanged<bool>? onFadeWatchedChanged;

  final int candidateCount;
  final VoidCallback onOpenFilters;
  final VoidCallback onClear;
  final CatalogFilter filter;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
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
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                localization.discoveryTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: CandyTypography.display,
                  fontWeight: CandyTypography.displayWeight,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : CandyMotion.quick,
                child: Text(
                  localization.discoveryCandidateCount(candidateCount),
                  key: ValueKey<int>(candidateCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
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
        ),
      ],
    );
  }
}
