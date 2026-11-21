import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_media_kind.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Ratings tab: runtime window and minimum scores.
final class DiscoveryRatingFilterTab extends StatelessWidget {
  const DiscoveryRatingFilterTab({required this.data, super.key});

  static const maxRuntime = 300.0;

  final DiscoveryRatingFilterData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final runtimeActive =
        data.runtime.start > 0 || data.runtime.end < maxRuntime;
    final runtimeEnd = data.runtime.end >= maxRuntime
        ? '${maxRuntime.round()}+'
        : '${data.runtime.end.round()}';
    return DiscoveryFilterTabList(
      children: <Widget>[
        DiscoveryFilterGroup(
          title: watchDiscoveringSeries(context)
              ? l10n.discoveryEpisodeLengthTitle
              : l10n.discoveryRuntimeTitle,
          value: runtimeActive
              ? l10n.discoveryRuntimeRangeValue(
                  data.runtime.start.round(),
                  runtimeEnd,
                )
              : l10n.discoveryAnyLabel,
          highlightValue: runtimeActive,
          child: RangeSlider(
            key: WidgetKeys.discoveryRuntimeField,
            values: data.runtime,
            max: maxRuntime,
            divisions: 30,
            labels: RangeLabels('${data.runtime.start.round()}', runtimeEnd),
            semanticFormatterCallback: (value) =>
                l10n.discoveryRuntimeMinutes(value.round()),
            onChanged: data.onRuntimeChanged,
          ),
        ),
        DiscoveryFilterGroup(
          title: l10n.discoveryCommunityTitle,
          value: data.community > 0
              ? l10n.discoveryMinimumValue(data.community.toStringAsFixed(1))
              : l10n.discoveryAnyLabel,
          highlightValue: data.community > 0,
          child: Slider(
            key: WidgetKeys.discoveryCommunityRatingField,
            value: data.community,
            max: 10,
            divisions: 20,
            label: data.community.toStringAsFixed(1),
            onChanged: data.onCommunityChanged,
          ),
        ),
        DiscoveryFilterGroup(
          title: l10n.discoveryCriticTitle,
          value: data.critic > 0
              ? l10n.discoveryMinimumValue(data.critic.toStringAsFixed(0))
              : l10n.discoveryAnyLabel,
          highlightValue: data.critic > 0,
          child: Slider(
            key: WidgetKeys.discoveryCriticRatingField,
            value: data.critic,
            max: 100,
            divisions: 20,
            label: data.critic.toStringAsFixed(0),
            onChanged: data.onCriticChanged,
          ),
        ),
      ],
    );
  }
}
