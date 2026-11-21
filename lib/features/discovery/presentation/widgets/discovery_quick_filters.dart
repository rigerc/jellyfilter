import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

final class DiscoveryQuickFilters extends StatelessWidget {
  const DiscoveryQuickFilters({required this.data, super.key});

  final DiscoveryQuickFilterData data;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final filters =
        <
          ({
            Key key,
            String label,
            bool selected,
            ValueChanged<bool> onSelected,
          })
        >[
          (
            key: WidgetKeys.discoveryRecentFilter,
            label: localization.discoveryQuickRecentLabel,
            selected: data.recent,
            onSelected: data.onRecentChanged,
          ),
          (
            key: WidgetKeys.discoveryUnwatchedFilter,
            label: localization.discoveryQuickUnwatchedLabel,
            selected: data.unwatched,
            onSelected: data.onUnwatchedChanged,
          ),
          (
            key: WidgetKeys.discoveryFavoritesFilter,
            label: localization.discoveryQuickFavoritesLabel,
            selected: data.favorites,
            onSelected: data.onFavoritesChanged,
          ),
          if ((data.inProgress, data.onInProgressChanged) case (
            final selected?,
            final onSelected?,
          ))
            (
              key: WidgetKeys.discoveryInProgressFilter,
              label: localization.discoveryWatchProgressInProgress,
              selected: selected,
              onSelected: onSelected,
            ),
        ];
    return DiscoveryFilterGroup(
      title: localization.discoveryQuickFiltersLabel,
      child: Wrap(
        spacing: CandySpacing.compact / 1.5,
        runSpacing: CandySpacing.compact / 1.5,
        children: filters
            .map(
              (filter) => FilterChip(
                key: filter.key,
                label: Text(filter.label),
                selected: filter.selected,
                onSelected: filter.onSelected,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
