import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Presets tab: apply a handy or saved lineup, or save the filters set here.
final class DiscoveryPresetFilterTab extends StatelessWidget {
  const DiscoveryPresetFilterTab({required this.data, super.key});

  final DiscoveryPresetFilterData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DiscoveryFilterTabList(
      children: <Widget>[
        DiscoveryFilterGroup(
          title: l10n.discoverySuggestedPresetsLabel,
          child: Wrap(
            spacing: CandySpacing.compact / 1.5,
            runSpacing: CandySpacing.compact / 1.5,
            children: data.suggestedPresets
                .map(
                  (preset) => ActionChip(
                    key: WidgetKeys.discoverySuggestedPreset(preset.id),
                    avatar: const Icon(Icons.auto_awesome_outlined),
                    label: Text(preset.label),
                    onPressed: () => data.onApplySuggested(preset.filter),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        DiscoveryFilterGroup(
          title: l10n.discoverySavedPresetsLabel,
          value: data.presets.isEmpty ? null : '${data.presets.length}',
          child: data.presets.isEmpty
              ? Text(
                  l10n.discoveryPresetsEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Wrap(
                  spacing: CandySpacing.compact / 1.5,
                  runSpacing: CandySpacing.compact / 1.5,
                  children: data.presets.keys
                      .map(
                        (name) => InputChip(
                          key: WidgetKeys.discoveryPreset(name),
                          avatar: const Icon(Icons.bookmark_rounded),
                          label: Text(name),
                          onPressed: () => data.onApply(name),
                          deleteIcon: const Icon(Icons.close_rounded, size: 18),
                          deleteButtonTooltipMessage: l10n
                              .discoveryDeletePresetLabel(name),
                          onDeleted: () => data.onDelete(name),
                        ),
                      )
                      .toList(growable: false),
                ),
        ),
        DiscoveryFilterGroup(
          title: l10n.discoverySavePresetLabel,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CandySpacing.compact,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: WidgetKeys.discoveryPresetName,
                  controller: data.nameController,
                  maxLength: 50,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => data.onSave(),
                  decoration: InputDecoration(
                    hintText: l10n.discoveryPresetNameLabel,
                    counterText: '',
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: WidgetKeys.discoverySavePreset,
                tooltip: l10n.discoverySavePresetLabel,
                onPressed: data.onSave,
                icon: const Icon(Icons.bookmark_add_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
