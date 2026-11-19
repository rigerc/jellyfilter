import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_models.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Content tab: genres, decades, and content ratings.
final class DiscoveryContentFilterTab extends StatelessWidget {
  const DiscoveryContentFilterTab({required this.data, super.key});

  final DiscoveryMetadataFilterData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DiscoveryFilterTabList(
      children: <Widget>[
        Row(
          spacing: CandySpacing.compact / 1.5,
          children: <Widget>[
            Icon(
              Icons.touch_app_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: Text(
                l10n.discoveryChipLegend,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (data.availableGenres.isNotEmpty)
          DiscoveryMetadataChoices<String>(
            label: l10n.discoveryGenresTitle,
            values: data.availableGenres,
            selection: data.genres,
            keyFor: WidgetKeys.discoveryGenre,
            labelFor: _titleCase,
            onChanged: data.onSelectionChanged,
          )
        else
          TextField(
            key: WidgetKeys.discoveryGenresField,
            controller: data.genresController,
            decoration: InputDecoration(
              labelText: l10n.discoveryGenresFilterLabel,
            ),
          ),
        if (data.availableTags.isNotEmpty ||
            data.tags.included.isNotEmpty ||
            data.tags.excluded.isNotEmpty)
          DiscoveryTagChoices(
            available: data.availableTags,
            selection: data.tags,
            onChanged: data.onSelectionChanged,
          ),
        if (data.availableDecades.isNotEmpty)
          DiscoveryMetadataChoices<int>(
            label: l10n.discoveryDecadeFilterLabel,
            values: data.availableDecades,
            selection: data.decades,
            keyFor: WidgetKeys.discoveryDecade,
            labelFor: (value) => '${value}s',
            onChanged: data.onSelectionChanged,
          ),
        if (data.availableRatings.isNotEmpty)
          DiscoveryMetadataChoices<String>(
            label: l10n.discoveryOfficialRatingsFilterLabel,
            values: _byAudienceAge(data.availableRatings),
            selection: data.officialRatings,
            keyFor: WidgetKeys.discoveryOfficialRating,
            onChanged: data.onSelectionChanged,
          ),
      ],
    );
  }

  /// Orders common certificates from youngest audience to oldest; anything
  /// unrecognised follows alphabetically.
  static List<String> _byAudienceAge(List<String> ratings) {
    const order = <String>[
      'TV-Y',
      'TV-Y7',
      'G',
      'TV-G',
      'PG',
      'TV-PG',
      'PG-13',
      'TV-14',
      'R',
      'TV-MA',
      'NC-17',
      'NR',
      'UNRATED',
    ];
    int rank(String value) {
      final index = order.indexOf(value.toUpperCase());
      return index < 0 ? order.length : index;
    }

    return List<String>.of(ratings)..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  }

  static String _titleCase(String value) => value.isEmpty
      ? value
      : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}

/// Tag chips for libraries with many tags: chosen tags first, then the most
/// used ones, with a search field to reach the rest.
final class DiscoveryTagChoices extends StatefulWidget {
  const DiscoveryTagChoices({
    required this.available,
    required this.selection,
    required this.onChanged,
    super.key,
  });

  /// Every known tag, most used first.
  final List<String> available;
  final DiscoveryFacetSelection<String> selection;
  final VoidCallback onChanged;

  /// Chips shown at once; more than this is slow to lay out and to scan.
  static const visibleLimit = 30;

  @override
  State<DiscoveryTagChoices> createState() => _DiscoveryTagChoicesState();
}

final class _DiscoveryTagChoicesState extends State<DiscoveryTagChoices> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selection = widget.selection;
    final chosen = <String>[...selection.included, ...selection.excluded];
    final query = _query.text.trim().toLowerCase();
    final pool = widget.available.where((tag) => !chosen.contains(tag));
    final matches = query.isEmpty
        ? pool
        : pool.where((tag) => tag.toLowerCase().contains(query));
    final shown = matches.take(DiscoveryTagChoices.visibleLimit).toList();
    final total = query.isEmpty ? widget.available.length : null;
    return DiscoveryFilterGroup(
      title: l10n.discoveryTagsTab,
      value: selection.count == 0
          ? l10n.discoveryAnyLabel
          : <String>[
              if (selection.included.isNotEmpty)
                l10n.discoveryRequiredCount(selection.included.length),
              if (selection.excluded.isNotEmpty)
                l10n.discoveryExcludedCount(selection.excluded.length),
            ].join(' · '),
      highlightValue: selection.count > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CandySpacing.compact,
        children: <Widget>[
          // Search sits above the chips so matches appear right below it.
          if (widget.available.length > DiscoveryTagChoices.visibleLimit)
            TextField(
              key: WidgetKeys.discoveryTagSearch,
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.discoveryFindTagHint,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          DiscoveryChoiceWrap<String>(
            values: <String>[...chosen, ...shown],
            selection: selection,
            keyFor: WidgetKeys.discoveryTagFilter,
            onChanged: widget.onChanged,
          ),
          if (total != null && total > shown.length + chosen.length)
            Text(
              l10n.discoveryTagsShownLabel(shown.length, total),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
