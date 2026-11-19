import 'package:flutter/material.dart';
import 'package:jellyfin_picker/core/theme/candy_theme.dart';
import 'package:jellyfin_picker/l10n/generated/app_localizations.dart';

enum DiscoveryTriState { any, yes, no }

/// A facet value's place in the filter.
enum DiscoveryChipState { off, include, exclude }

/// Values to require and values to exclude for one facet.
final class DiscoveryFacetSelection<T> {
  DiscoveryFacetSelection({
    Iterable<T> included = const [],
    Iterable<T> excluded = const [],
  }) : included = included.toSet(),
       excluded = excluded.toSet()..removeAll(included);

  final Set<T> included;
  final Set<T> excluded;

  int get count => included.length + excluded.length;

  DiscoveryChipState stateOf(T value) => included.contains(value)
      ? DiscoveryChipState.include
      : excluded.contains(value)
      ? DiscoveryChipState.exclude
      : DiscoveryChipState.off;

  /// Off → require → exclude → off.
  void cycle(T value) {
    switch (stateOf(value)) {
      case DiscoveryChipState.off:
        included.add(value);
      case DiscoveryChipState.include:
        included.remove(value);
        excluded.add(value);
      case DiscoveryChipState.exclude:
        excluded.remove(value);
    }
  }
}

/// A flat, titled group inside a filter tab. An optional [value] summarises
/// the current choice on the right of the title.
final class DiscoveryFilterGroup extends StatelessWidget {
  const DiscoveryFilterGroup({
    required this.title,
    required this.child,
    this.value,
    this.highlightValue = false,
    this.gap = CandySpacing.compact,
    super.key,
  });

  /// Space between the title and the controls; outlined fields with floating
  /// labels need more than chips do.
  final double gap;
  final String title;
  final String? value;
  final bool highlightValue;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: CandySpacing.compact,
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (summary != null)
              Text(
                summary,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: highlightValue
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
          ],
        ),
        child,
      ],
    );
  }
}

/// Vertical rhythm for a filter tab: generous gaps between groups.
final class DiscoveryFilterTabList extends StatelessWidget {
  const DiscoveryFilterTabList({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      CandySpacing.page,
      CandySpacing.page,
      CandySpacing.page,
      CandySpacing.section,
    ),
    children: <Widget>[
      for (final (index, child) in children.indexed) ...<Widget>[
        if (index > 0) const SizedBox(height: CandySpacing.section - 4),
        child,
      ],
    ],
  );
}

/// Chips that cycle between off, required (✓), and excluded (⊘).
final class DiscoveryChoiceWrap<T> extends StatelessWidget {
  const DiscoveryChoiceWrap({
    required this.values,
    required this.selection,
    required this.keyFor,
    required this.onChanged,
    this.labelFor,
    super.key,
  });

  final List<T> values;
  final DiscoveryFacetSelection<T> selection;
  final Key Function(T value) keyFor;
  final VoidCallback onChanged;
  final String Function(T value)? labelFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: CandySpacing.compact / 1.5,
      runSpacing: CandySpacing.compact / 1.5,
      children: values
          .map((value) {
            final state = selection.stateOf(value);
            final label = labelFor?.call(value) ?? '$value';
            final excluded = state == DiscoveryChipState.exclude;
            return Semantics(
              value: switch (state) {
                DiscoveryChipState.off => null,
                DiscoveryChipState.include => l10n.discoveryChipRequired,
                DiscoveryChipState.exclude => l10n.discoveryChipExcluded,
              },
              child: FilterChip(
                key: keyFor(value),
                label: Text(
                  label,
                  style: excluded
                      ? TextStyle(
                          color: scheme.onErrorContainer,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: scheme.onErrorContainer,
                        )
                      : null,
                ),
                selected: state != DiscoveryChipState.off,
                showCheckmark: false,
                avatar: switch (state) {
                  DiscoveryChipState.off => null,
                  DiscoveryChipState.include => Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: scheme.onPrimary,
                  ),
                  DiscoveryChipState.exclude => Icon(
                    Icons.block_rounded,
                    size: 18,
                    color: scheme.onErrorContainer,
                  ),
                },
                // Set per chip: the theme's selected color is always amber.
                color: WidgetStateProperty.resolveWith<Color?>(
                  (states) => !states.contains(WidgetState.selected)
                      ? null
                      : excluded
                      ? scheme.errorContainer
                      : scheme.primary,
                ),
                side: excluded
                    ? BorderSide(color: scheme.error.withValues(alpha: 0.6))
                    : null,
                onSelected: (_) {
                  selection.cycle(value);
                  onChanged();
                },
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

/// Choice chips for a metadata facet, titled with a live count.
final class DiscoveryMetadataChoices<T> extends StatelessWidget {
  const DiscoveryMetadataChoices({
    required this.label,
    required this.values,
    required this.selection,
    required this.keyFor,
    required this.onChanged,
    this.labelFor,
    super.key,
  });

  final String label;
  final List<T> values;
  final DiscoveryFacetSelection<T> selection;
  final Key Function(T value) keyFor;
  final VoidCallback onChanged;
  final String Function(T value)? labelFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DiscoveryFilterGroup(
      title: label,
      value: selection.count == 0
          ? l10n.discoveryAnyLabel
          : <String>[
              if (selection.included.isNotEmpty)
                l10n.discoveryRequiredCount(selection.included.length),
              if (selection.excluded.isNotEmpty)
                l10n.discoveryExcludedCount(selection.excluded.length),
            ].join(' · '),
      highlightValue: selection.count > 0,
      child: DiscoveryChoiceWrap<T>(
        values: values,
        selection: selection,
        keyFor: keyFor,
        onChanged: onChanged,
        labelFor: labelFor,
      ),
    );
  }
}

/// Any / Yes / No as a single segmented control.
final class DiscoveryTriStateField extends StatelessWidget {
  const DiscoveryTriStateField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final DiscoveryTriState value;
  final ValueChanged<DiscoveryTriState> onChanged;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    return DiscoveryFilterGroup(
      title: label,
      child: SegmentedButton<DiscoveryTriState>(
        showSelectedIcon: false,
        segments: <ButtonSegment<DiscoveryTriState>>[
          ButtonSegment<DiscoveryTriState>(
            value: DiscoveryTriState.any,
            label: Text(localization.discoveryAnyLabel),
          ),
          ButtonSegment<DiscoveryTriState>(
            value: DiscoveryTriState.yes,
            label: Text(localization.discoveryYesLabel),
          ),
          ButtonSegment<DiscoveryTriState>(
            value: DiscoveryTriState.no,
            label: Text(localization.discoveryNoLabel),
          ),
        ],
        selected: <DiscoveryTriState>{value},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}
