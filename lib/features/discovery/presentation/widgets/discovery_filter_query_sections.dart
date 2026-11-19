import 'package:flutter/material.dart';
import 'package:jellyfin_picker/core/assets/app_assets.dart';
import 'package:jellyfin_picker/core/keys/widget_keys.dart';
import 'package:jellyfin_picker/core/media/entities/catalog_filter.dart';
import 'package:jellyfin_picker/core/theme/candy_theme.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_quick_filters.dart';
import 'package:jellyfin_picker/l10n/generated/app_localizations.dart';

/// Basics tab: search, quick filters, library and order, recency, status.
final class DiscoveryBasicsFilterTab extends StatelessWidget {
  const DiscoveryBasicsFilterTab({
    required this.query,
    required this.quickFilters,
    required this.metadata,
    super.key,
  });

  final DiscoveryQueryFilterData query;
  final DiscoveryQuickFilterData quickFilters;
  final DiscoveryMetadataFilterData metadata;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DiscoveryFilterTabList(
      children: <Widget>[
        TextField(
          key: WidgetKeys.discoverySearchField,
          controller: query.searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.discoverySearchTitleLabel,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(CandySpacing.compact / 1.5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(CandyShapes.compact),
                child: ExcludeSemantics(
                  child: Image.asset(
                    AppAssets.searchIcon,
                    width: CandyIconSize.action,
                    height: CandyIconSize.action,
                    cacheWidth: CandyImages.artworkCacheWidth,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ),
        DiscoveryQuickFilters(data: quickFilters),
        DiscoveryFilterGroup(
          title: l10n.discoveryOrderTitle,
          gap: CandySpacing.cardGap + 4,
          child: Column(
            spacing: CandySpacing.cardGap + 4,
            children: <Widget>[
              DropdownButtonFormField<String?>(
                key: WidgetKeys.discoveryLibraryField,
                isExpanded: true,
                initialValue: query.libraryId,
                decoration: InputDecoration(
                  labelText: l10n.discoveryLibraryLabel,
                ),
                items: <DropdownMenuItem<String?>>[
                  DropdownMenuItem<String?>(
                    child: Text(l10n.discoveryAllLibrariesLabel),
                  ),
                  ...query.libraries.map(
                    (library) => DropdownMenuItem<String?>(
                      value: library.id,
                      child: Text(library.name),
                    ),
                  ),
                ],
                onChanged: query.onLibraryChanged,
              ),
              Row(
                spacing: CandySpacing.compact / 1.5,
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<CatalogSort>(
                      key: WidgetKeys.discoverySortField,
                      isExpanded: true,
                      initialValue: query.sort,
                      decoration: InputDecoration(
                        labelText: l10n.discoverySortLabel,
                      ),
                      items: CatalogSort.values
                          .map(
                            (value) => DropdownMenuItem<CatalogSort>(
                              value: value,
                              child: Text(sortLabel(l10n, value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) query.onSortChanged(value);
                      },
                    ),
                  ),
                  DiscoveryReverseSortButton(
                    sort: query.sort,
                    reversed: query.sortReversed,
                    onChanged: query.onSortReversedChanged,
                  ),
                ],
              ),
              DropdownButtonFormField<CatalogAddedWindow?>(
                key: WidgetKeys.discoveryAddedWithinField,
                isExpanded: true,
                initialValue: query.addedWithin,
                decoration: InputDecoration(
                  labelText: l10n.discoveryAddedWithinLabel,
                ),
                items: <DropdownMenuItem<CatalogAddedWindow?>>[
                  DropdownMenuItem<CatalogAddedWindow?>(
                    child: Text(l10n.discoveryAddedWithinAnyLabel),
                  ),
                  ...CatalogAddedWindow.values.map(
                    (value) => DropdownMenuItem<CatalogAddedWindow?>(
                      value: value,
                      child: Text(windowLabel(l10n, value)),
                    ),
                  ),
                ],
                onChanged: query.onAddedWithinChanged,
              ),
            ],
          ),
        ),
        DiscoveryTriStateField(
          key: WidgetKeys.discoveryWatchedField,
          label: l10n.discoveryWatchedTitle,
          value: metadata.watched,
          onChanged: metadata.onWatchedChanged,
        ),
        DiscoveryTriStateField(
          key: WidgetKeys.discoveryFavoriteField,
          label: l10n.discoveryFavoriteTitle,
          value: metadata.favorite,
          onChanged: metadata.onFavoriteChanged,
        ),
      ],
    );
  }

  static String sortLabel(AppLocalizations l10n, CatalogSort value) =>
      switch (value) {
        CatalogSort.defaultOrder => l10n.discoverySortDefaultLabel,
        CatalogSort.random => l10n.discoverySortRandomLabel,
        CatalogSort.recentlyAdded => l10n.discoverySortRecentlyAddedLabel,
        CatalogSort.title => l10n.discoverySortTitleLabel,
        CatalogSort.releaseYear => l10n.discoverySortReleaseYearLabel,
        CatalogSort.communityRating => l10n.discoverySortCommunityRatingLabel,
        CatalogSort.runtime => l10n.discoverySortRuntimeLabel,
      };

  static String windowLabel(AppLocalizations l10n, CatalogAddedWindow value) =>
      switch (value) {
        CatalogAddedWindow.sevenDays => l10n.discoveryAddedWithinWeekLabel,
        CatalogAddedWindow.thirtyDays => l10n.discoveryAddedWithinMonthLabel,
        CatalogAddedWindow.ninetyDays => l10n.discoveryAddedWithinQuarterLabel,
        CatalogAddedWindow.threeHundredSixtyFiveDays =>
          l10n.discoveryAddedWithinYearLabel,
      };
}

/// Flips the sort direction; disabled for orders without one.
final class DiscoveryReverseSortButton extends StatelessWidget {
  const DiscoveryReverseSortButton({
    required this.sort,
    required this.reversed,
    required this.onChanged,
    super.key,
  });

  final CatalogSort sort;
  final bool reversed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canReverse = CatalogFilter(sort: sort).canReverseSort;
    final active = canReverse && reversed;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      toggled: active,
      child: IconButton.filledTonal(
        key: WidgetKeys.discoveryReverseSort,
        tooltip: l10n.discoveryReverseSortLabel,
        onPressed: canReverse ? () => onChanged(!reversed) : null,
        style: active
            ? IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              )
            : null,
        icon: const Icon(Icons.swap_vert_rounded),
      ),
    );
  }
}
