import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_query_sections.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

final class DiscoveryHeaderActions extends StatelessWidget {
  const DiscoveryHeaderActions({
    required this.filterActive,
    required this.onOpenFilters,
    required this.onClear,
    this.sort = CatalogSort.defaultOrder,
    this.sortReversed = false,
    this.onSortChanged,
    this.onSortReversedChanged,
    this.fadeWatched = false,
    this.onFadeWatchedChanged,
    super.key,
  });

  final bool filterActive;
  final VoidCallback onOpenFilters;
  final VoidCallback onClear;
  final CatalogSort sort;
  final bool sortReversed;
  final ValueChanged<bool>? onSortReversedChanged;

  /// Null hides the sort menu (Shuffle always draws at random).
  final ValueChanged<CatalogSort>? onSortChanged;
  final bool fadeWatched;
  final ValueChanged<bool>? onFadeWatchedChanged;

  /// Orders offered in the header; Random lives in Shuffle.
  static const sortChoices = <CatalogSort>[
    CatalogSort.defaultOrder,
    CatalogSort.recentlyAdded,
    CatalogSort.title,
    CatalogSort.releaseYear,
    CatalogSort.communityRating,
    CatalogSort.runtime,
  ];

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    const filterIcon = Icon(Icons.filter_list_rounded);
    final onSort = onSortChanged;
    final canReverse = CatalogFilter(sort: sort).canReverseSort;
    final sorted = sort != CatalogSort.defaultOrder || sortReversed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (onSort != null)
          PopupMenuButton<CatalogSort>(
            key: WidgetKeys.discoverySortButton,
            tooltip: localization.discoverySortLabel,
            initialValue: sort,
            onSelected: onSort,
            icon: Icon(
              Icons.swap_vert_rounded,
              color: sorted ? scheme.primary : null,
            ),
            itemBuilder: (context) => <PopupMenuEntry<CatalogSort>>[
              for (final choice in sortChoices)
                CheckedPopupMenuItem<CatalogSort>(
                  key: WidgetKeys.discoverySortChoice(choice.name),
                  value: choice,
                  checked: choice == sort,
                  child: Text(
                    DiscoveryBasicsFilterTab.sortLabel(localization, choice),
                  ),
                ),
              if (onSortReversedChanged case final onReverse?) ...[
                const PopupMenuDivider(),
                CheckedPopupMenuItem<CatalogSort>(
                  key: WidgetKeys.discoveryReverseSortToggle,
                  enabled: canReverse,
                  checked: canReverse && sortReversed,
                  onTap: () => onReverse(!sortReversed),
                  child: Text(localization.discoveryReverseSortLabel),
                ),
              ],
            ],
          ),
        IconButton.filledTonal(
          key: WidgetKeys.discoveryFilterButton,
          tooltip: filterActive
              ? localization.discoveryActiveFilterLabel
              : localization.discoveryFiltersLabel,
          onPressed: onOpenFilters,
          icon: filterActive
              ? const Badge(
                  key: WidgetKeys.discoveryActiveFilterIndicator,
                  child: filterIcon,
                )
              : filterIcon,
        ),
        PopupMenuButton<void>(
          key: WidgetKeys.discoveryMoreButton,
          tooltip: localization.discoveryMoreActionsLabel,
          icon: const Icon(Icons.more_horiz_rounded),
          itemBuilder: (context) => <PopupMenuEntry<void>>[
            if (onFadeWatchedChanged case final onFade?)
              CheckedPopupMenuItem<void>(
                key: WidgetKeys.discoveryFadeWatchedToggle,
                checked: fadeWatched,
                onTap: () => onFade(!fadeWatched),
                child: Text(localization.discoveryFadeWatchedLabel),
              ),
            PopupMenuItem<void>(
              key: WidgetKeys.discoveryClearButton,
              onTap: onClear,
              child: Row(
                spacing: CandySpacing.compact,
                children: <Widget>[
                  const Icon(Icons.delete_sweep_outlined),
                  Expanded(child: Text(localization.discoveryClearLabel)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
