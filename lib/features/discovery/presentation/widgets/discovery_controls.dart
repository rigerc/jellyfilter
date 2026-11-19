import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_query_sections.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_header.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

final class DiscoveryControls extends StatelessWidget {
  const DiscoveryControls({
    required this.onClear,
    this.libraries = const <CatalogLibrary>[],
    this.facets = const CatalogFacets(),
    super.key,
  });

  final VoidCallback onClear;
  final List<CatalogLibrary> libraries;
  final CatalogFacets facets;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryCubit, DiscoveryState>(
      buildWhen: (previous, current) =>
          previous.filteredCandidates.length !=
              current.filteredCandidates.length ||
          previous.filter != current.filter ||
          previous.mode != current.mode ||
          previous.fadeWatched != current.fadeWatched,
      builder: (context, state) {
        void openFilters() => showDiscoveryFilters(
          context,
          state.filter,
          candidates: state.candidates,
          libraries: libraries,
          facets: facets,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DiscoveryHeader(
              candidateCount: state.filteredCandidates.length,
              filter: state.filter,
              onOpenFilters: openFilters,
              onClear: onClear,
              onSortChanged: state.mode == DiscoveryMode.shuffle
                  ? null
                  : (sort) => context.read<DiscoveryCubit>().updateFilter(
                      state.filter.copyWith(
                        sort: sort,
                        // A new order starts in its natural direction.
                        sortReversed: sort == state.filter.sort
                            ? state.filter.sortReversed
                            : false,
                      ),
                    ),
              onSortReversedChanged: state.mode == DiscoveryMode.shuffle
                  ? null
                  : (reversed) => context.read<DiscoveryCubit>().updateFilter(
                      state.filter.copyWith(sortReversed: reversed),
                    ),
              fadeWatched: state.fadeWatched,
              onFadeWatchedChanged: context
                  .read<DiscoveryCubit>()
                  .setFadeWatched,
            ),
            DiscoveryActiveFilters(
              filter: state.filter,
              mode: state.mode,
              libraries: libraries,
              onOpenFilters: openFilters,
            ),
          ],
        );
      },
    );
  }
}

typedef _ActiveFilter = ({
  String id,
  String label,
  CatalogFilter Function(CatalogFilter filter) remove,
});

/// A strip of the filters shaping the current view, shown above the titles
/// in every mode. Tapping a chip opens the filter sheet; its × removes it.
final class DiscoveryActiveFilters extends StatelessWidget {
  const DiscoveryActiveFilters({
    required this.filter,
    required this.mode,
    required this.onOpenFilters,
    this.libraries = const <CatalogLibrary>[],
    super.key,
  });

  final CatalogFilter filter;
  final DiscoveryMode mode;
  final List<CatalogLibrary> libraries;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final filters = _activeFilters(l10n);
    final duration = reduceMotion ? Duration.zero : CandyMotion.standard;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        child: filters.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                key: const ValueKey<String>('active-filters'),
                padding: const EdgeInsets.only(top: CandySpacing.compact / 2),
                child: _ActiveFilterStrip(
                  filters: filters,
                  onOpenFilters: onOpenFilters,
                ),
              ),
      ),
    );
  }

  List<_ActiveFilter> _activeFilters(AppLocalizations l10n) {
    final library = filter.libraryId;
    final search = filter.searchTerm.trim();
    final added = filter.addedWithin;
    final minRuntime = filter.minimumRuntimeMinutes;
    final maxRuntime = filter.maximumRuntimeMinutes;
    final community = _range(
      filter.minimumCommunityRating,
      filter.maximumCommunityRating,
      digits: 1,
    );
    final critic = _range(
      filter.minimumCriticRating,
      filter.maximumCriticRating,
      digits: 0,
    );
    return <_ActiveFilter>[
      if (search.isNotEmpty)
        (
          id: 'search',
          label: l10n.discoveryActiveSearch(search),
          remove: (value) => value.copyWith(searchTerm: ''),
        ),
      if (library != null)
        (
          id: 'library',
          label:
              libraries
                  .where((candidate) => candidate.id == library)
                  .firstOrNull
                  ?.name ??
              l10n.discoveryLibraryLabel,
          remove: (value) => value.copyWith(libraryId: null),
        ),
      if (filter.sort != CatalogSort.defaultOrder &&
          mode != DiscoveryMode.shuffle)
        (
          id: 'sort',
          label:
              (filter.canReverseSort && filter.sortReversed
              ? l10n.discoveryActiveSortReversed
              : l10n.discoveryActiveSort)(
                DiscoveryBasicsFilterTab.sortLabel(
                  l10n,
                  filter.sort,
                ).toLowerCase(),
              ),
          remove: (value) => value.copyWith(
            sort: CatalogSort.defaultOrder,
            sortReversed: false,
          ),
        ),
      if (added != null)
        (
          id: 'added',
          label: l10n.discoveryActiveAddedWithin(added.days),
          remove: (value) => value.copyWith(addedWithin: null),
        ),
      if (filter.watched case final watched?)
        (
          id: 'watched',
          label: watched
              ? l10n.discoveryActiveWatched
              : l10n.discoveryActiveUnwatched,
          remove: (value) => value.copyWith(watched: null),
        ),
      if (filter.favorite case final favorite?)
        (
          id: 'favorite',
          label: favorite
              ? l10n.discoveryActiveFavorites
              : l10n.discoveryActiveNotFavorites,
          remove: (value) => value.copyWith(favorite: null),
        ),
      for (final genre in filter.genres.toList()..sort())
        (
          id: 'genre-$genre',
          label: _titleCase(genre),
          remove: (value) =>
              value.copyWith(genres: value.genres.difference({genre})),
        ),
      for (final decade in filter.decades.toList()..sort())
        (
          id: 'decade-$decade',
          label: '${decade}s',
          remove: (value) =>
              value.copyWith(decades: value.decades.difference({decade})),
        ),
      for (final rating in filter.officialRatings.toList()..sort())
        (
          id: 'rating-$rating',
          label: rating,
          remove: (value) => value.copyWith(
            officialRatings: value.officialRatings.difference({rating}),
          ),
        ),
      for (final tag in filter.tags.toList()..sort())
        (
          id: 'tag-$tag',
          label: l10n.discoveryActiveTag(tag),
          remove: (value) => value.copyWith(tags: value.tags.difference({tag})),
        ),
      for (final genre in filter.excludedGenres.toList()..sort())
        (
          id: 'not-genre-$genre',
          label: l10n.discoveryActiveExcluded(_titleCase(genre)),
          remove: (value) => value.copyWith(
            excludedGenres: value.excludedGenres.difference({genre}),
          ),
        ),
      for (final tag in filter.excludedTags.toList()..sort())
        (
          id: 'not-tag-$tag',
          label: l10n.discoveryActiveExcluded(l10n.discoveryActiveTag(tag)),
          remove: (value) => value.copyWith(
            excludedTags: value.excludedTags.difference({tag}),
          ),
        ),
      for (final decade in filter.excludedDecades.toList()..sort())
        (
          id: 'not-decade-$decade',
          label: l10n.discoveryActiveExcluded('${decade}s'),
          remove: (value) => value.copyWith(
            excludedDecades: value.excludedDecades.difference({decade}),
          ),
        ),
      for (final rating in filter.excludedOfficialRatings.toList()..sort())
        (
          id: 'not-rating-$rating',
          label: l10n.discoveryActiveExcluded(rating),
          remove: (value) => value.copyWith(
            excludedOfficialRatings: value.excludedOfficialRatings.difference({
              rating,
            }),
          ),
        ),
      if (minRuntime != null || maxRuntime != null)
        (
          id: 'runtime',
          label: switch ((minRuntime, maxRuntime)) {
            (final minimum?, final maximum?) =>
              l10n.discoveryActiveRuntimeRange(minimum, maximum),
            (final minimum?, null) => l10n.discoveryActiveRuntimeMinimum(
              minimum,
            ),
            (null, final maximum?) => l10n.discoveryActiveRuntimeMaximum(
              maximum,
            ),
            (null, null) => '',
          },
          remove: (value) => value.copyWith(
            minimumRuntimeMinutes: null,
            maximumRuntimeMinutes: null,
          ),
        ),
      if (community != null)
        (
          id: 'community',
          label: l10n.discoveryActiveCommunity(community),
          remove: (value) => value.copyWith(
            minimumCommunityRating: null,
            maximumCommunityRating: null,
          ),
        ),
      if (critic != null)
        (
          id: 'critic',
          label: l10n.discoveryActiveCritic(critic),
          remove: (value) => value.copyWith(
            minimumCriticRating: null,
            maximumCriticRating: null,
          ),
        ),
    ];
  }

  static String? _range(
    double? minimum,
    double? maximum, {
    required int digits,
  }) {
    String format(double value) => value.toStringAsFixed(digits);
    return switch ((minimum, maximum)) {
      (final low?, final high?) => '${format(low)}–${format(high)}',
      (final low?, null) => '${format(low)}+',
      (null, final high?) => '≤ ${format(high)}',
      (null, null) => null,
    };
  }

  static String _titleCase(String value) => value.isEmpty
      ? value
      : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}

final class _ActiveFilterStrip extends StatelessWidget {
  const _ActiveFilterStrip({
    required this.filters,
    required this.onOpenFilters,
  });

  final List<_ActiveFilter> filters;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<DiscoveryCubit>();
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: scheme.onPrimaryContainer,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      container: true,
      label: l10n.discoveryActiveFiltersLabel,
      child: SizedBox(
        key: WidgetKeys.discoveryActiveFilters,
        height: CandySpacing.minimumTouchTarget,
        // Fade the trailing edge so a clipped chip reads as "scroll for more".
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
            stops: <double>[0, 0.9, 1],
          ).createShader(bounds),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: CandySpacing.page),
            children: <Widget>[
              for (final filter in filters)
                Padding(
                  padding: const EdgeInsets.only(
                    right: CandySpacing.compact / 1.5,
                  ),
                  child: InputChip(
                    key: WidgetKeys.discoveryActiveFilterChip(filter.id),
                    label: Text(filter.label),
                    // Exclusions read as "not": coral instead of amber.
                    labelStyle: filter.id.startsWith('not-')
                        ? labelStyle?.copyWith(color: scheme.onErrorContainer)
                        : labelStyle,
                    backgroundColor: filter.id.startsWith('not-')
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onPressed: onOpenFilters,
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    deleteIconColor: filter.id.startsWith('not-')
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                    deleteButtonTooltipMessage: l10n.discoveryRemoveFilterLabel(
                      filter.label,
                    ),
                    onDeleted: () =>
                        cubit.updateFilter(filter.remove(cubit.state.filter)),
                  ),
                ),
              if (filters.length > 1)
                Center(
                  child: TextButton(
                    key: WidgetKeys.discoveryActiveFiltersClear,
                    onPressed: cubit.resetFilters,
                    child: Text(l10n.discoveryClearAllLabel),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
