import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_metadata_section.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_preset_section.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_query_sections.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_rating_section.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// The filter sheet: a fixed header, four tabs of grouped controls, and a
/// pinned apply bar so the primary action never scrolls away.
final class DiscoveryFilterBody extends StatelessWidget {
  const DiscoveryFilterBody({
    required this.quickFilters,
    required this.query,
    required this.ratings,
    required this.metadata,
    required this.presets,
    required this.onReset,
    required this.onApply,
    super.key,
  });

  final DiscoveryQuickFilterData quickFilters;
  final DiscoveryQueryFilterData query;
  final DiscoveryRatingFilterData ratings;
  final DiscoveryMetadataFilterData metadata;
  final DiscoveryPresetFilterData presets;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    // Leave room for the status bar and the sheet's drag handle.
    final height = math.max(
      0.0,
      math.min(media.size.height * 0.88, media.size.height - media.padding.top),
    );
    final counts = <int>[_basicsCount, _contentCount, _ratingsCount, 0];
    final tabs = <({String label, IconData icon})>[
      (label: l10n.discoveryFilterTabBasics, icon: Icons.tune_rounded),
      (label: l10n.discoveryFilterTabContent, icon: Icons.category_outlined),
      (label: l10n.discoveryFilterTabRatings, icon: Icons.star_outline_rounded),
      (label: l10n.discoveryFilterTabPresets, icon: Icons.bookmarks_outlined),
    ];
    final active = counts.fold<int>(0, (sum, count) => sum + count);
    return DefaultTabController(
      length: tabs.length,
      child: SizedBox(
        key: WidgetKeys.discoveryFilterSheet,
        height: height,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CandySpacing.page,
                  0,
                  CandySpacing.compact,
                  CandySpacing.compact / 2,
                ),
                child: Row(
                  spacing: CandySpacing.compact,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.discoveryFilterSheetTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFamily: CandyTypography.display,
                              fontWeight: CandyTypography.displayWeight,
                            ),
                          ),
                          Text(
                            l10n.discoveryActiveCountLabel(active),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: active > 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      key: WidgetKeys.discoveryResetFilters,
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: Text(l10n.discoveryResetAllLabel),
                    ),
                  ],
                ),
              ),
              TabBar(
                dividerColor: CandyColors.outline,
                indicatorColor: theme.colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: theme.textTheme.labelLarge,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: <Widget>[
                  for (final (index, tab) in tabs.indexed)
                    Tab(
                      key: WidgetKeys.discoveryFilterTab(index),
                      child: _TabLabel(label: tab.label, count: counts[index]),
                    ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    DiscoveryBasicsFilterTab(
                      query: query,
                      quickFilters: quickFilters,
                      metadata: metadata,
                    ),
                    DiscoveryContentFilterTab(data: metadata),
                    DiscoveryRatingFilterTab(data: ratings),
                    DiscoveryPresetFilterTab(data: presets),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: CandyColors.outline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      CandySpacing.page,
                      CandySpacing.compact,
                      CandySpacing.page,
                      CandySpacing.compact,
                    ),
                    child: FilledButton.icon(
                      key: WidgetKeys.discoveryApplyFilters,
                      onPressed: onApply,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.discoveryApplyFiltersLabel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _basicsCount => <bool>[
    query.searchController.text.trim().isNotEmpty,
    query.libraryId != null,
    query.sort != CatalogSort.defaultOrder || query.sortReversed,
    query.addedWithin != null,
    metadata.watched != DiscoveryTriState.any,
    metadata.favorite != DiscoveryTriState.any,
  ].where((active) => active).length;

  int get _contentCount =>
      (metadata.genres.count > 0
          ? metadata.genres.count
          : metadata.genresController.text.trim().isEmpty
          ? 0
          : 1) +
      metadata.tags.count +
      metadata.decades.count +
      metadata.officialRatings.count;

  int get _ratingsCount => <bool>[
    ratings.runtime.start > 0 ||
        ratings.runtime.end < DiscoveryRatingFilterTab.maxRuntime,
    ratings.community > 0,
    ratings.critic > 0,
  ].where((active) => active).length;
}

final class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: <Widget>[
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : CandyMotion.quick,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: count == 0
              ? const SizedBox.shrink(key: ValueKey<int>(0))
              : Container(
                  key: ValueKey<int>(count),
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(CandyShapes.pill),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
