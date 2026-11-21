import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Show tab: whether a series is still airing, how long it runs, and how far
/// the user has got through it.
final class DiscoverySeriesFilterTab extends StatelessWidget {
  const DiscoverySeriesFilterTab({required this.data, super.key});

  final DiscoverySeriesFilterData data;

  /// How many show constraints are chosen, for the tab badge.
  static int activeCount(DiscoverySeriesFilterData data) =>
      data.statuses.length + data.lengths.length + data.progress.length;

  static String statusLabel(AppLocalizations l10n, CatalogSeriesStatus value) =>
      switch (value) {
        CatalogSeriesStatus.continuing => l10n.discoverySeriesContinuing,
        CatalogSeriesStatus.ended => l10n.discoverySeriesEnded,
      };

  static String lengthLabel(AppLocalizations l10n, CatalogSeriesLength value) =>
      switch (value) {
        CatalogSeriesLength.miniseries => l10n.discoverySeriesLengthMiniseries,
        CatalogSeriesLength.short => l10n.discoverySeriesLengthShort,
        CatalogSeriesLength.long => l10n.discoverySeriesLengthLong,
      };

  static String progressLabel(
    AppLocalizations l10n,
    CatalogWatchProgress value,
  ) => switch (value) {
    CatalogWatchProgress.notStarted => l10n.discoveryWatchProgressNotStarted,
    CatalogWatchProgress.inProgress => l10n.discoveryWatchProgressInProgress,
    CatalogWatchProgress.finished => l10n.discoveryWatchProgressFinished,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DiscoveryFilterTabList(
      children: <Widget>[
        _ChoiceGroup<CatalogSeriesStatus>(
          title: l10n.discoverySeriesStatusTitle,
          values: CatalogSeriesStatus.values,
          selected: data.statuses,
          keyFor: (value) => WidgetKeys.discoverySeriesStatus(value.name),
          labelFor: (value) => statusLabel(l10n, value),
          onChanged: data.onStatusesChanged,
        ),
        _ChoiceGroup<CatalogSeriesLength>(
          title: l10n.discoverySeriesLengthTitle,
          values: CatalogSeriesLength.values,
          selected: data.lengths,
          keyFor: (value) => WidgetKeys.discoverySeriesLength(value.name),
          labelFor: (value) => lengthLabel(l10n, value),
          onChanged: data.onLengthsChanged,
        ),
        _ChoiceGroup<CatalogWatchProgress>(
          title: l10n.discoveryWatchProgressTitle,
          values: CatalogWatchProgress.values,
          selected: data.progress,
          keyFor: (value) => WidgetKeys.discoveryWatchProgress(value.name),
          labelFor: (value) => progressLabel(l10n, value),
          onChanged: data.onProgressChanged,
        ),
      ],
    );
  }
}

final class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.keyFor,
    required this.labelFor,
    required this.onChanged,
  });

  final String title;
  final List<T> values;
  final Set<T> selected;
  final Key Function(T value) keyFor;
  final String Function(T value) labelFor;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DiscoveryFilterGroup(
      title: title,
      value: selected.isEmpty
          ? l10n.discoveryAnyLabel
          : l10n.discoverySelectedCountLabel(selected.length),
      highlightValue: selected.isNotEmpty,
      child: Wrap(
        spacing: CandySpacing.compact / 1.5,
        runSpacing: CandySpacing.compact / 1.5,
        children: <Widget>[
          for (final value in values)
            FilterChip(
              key: keyFor(value),
              label: Text(labelFor(value)),
              selected: selected.contains(value),
              onSelected: (on) => onChanged(
                on
                    ? <T>{...selected, value}
                    : (Set<T>.of(selected)..remove(value)),
              ),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
        ],
      ),
    );
  }
}
