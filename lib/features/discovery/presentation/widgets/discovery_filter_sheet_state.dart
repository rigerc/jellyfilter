import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_default_presets.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_form.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_filter_sections.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

final class DiscoveryFilterSheet extends StatefulWidget {
  const DiscoveryFilterSheet({
    required this.filter,
    this.candidates = const <CatalogCandidate>[],
    this.libraries = const <CatalogLibrary>[],
    this.facets = const CatalogFacets(),
    super.key,
  });

  final CatalogFilter filter;
  final Iterable<CatalogCandidate> candidates;
  final List<CatalogLibrary> libraries;
  final CatalogFacets facets;

  @override
  State<DiscoveryFilterSheet> createState() => _DiscoveryFilterSheetState();
}

final class _DiscoveryFilterSheetState extends State<DiscoveryFilterSheet> {
  static const _maxRuntime = 300.0;
  final _search = TextEditingController();
  final _genresText = TextEditingController();
  final _presetText = TextEditingController();
  late String? _libraryId;
  late DiscoveryFacetSelection<String> _genres;
  late DiscoveryFacetSelection<String> _tags;
  late DiscoveryFacetSelection<int> _decades;
  late DiscoveryFacetSelection<String> _ratings;
  late bool _sortReversed;
  late RangeValues _runtime;
  late double _community;
  late double _critic;
  late DiscoveryTriState _watched;
  late DiscoveryTriState _favorite;
  late CatalogSort _sort;
  late CatalogAddedWindow? _addedWithin;
  late Set<CatalogSeriesStatus> _seriesStatuses;
  late Set<CatalogSeriesLength> _seriesLengths;
  late Set<CatalogWatchProgress> _watchProgress;

  /// Whether the sheet filters TV series, which adds the Show tab.
  late final bool _series;
  late final List<CatalogCandidate> _candidateList;

  /// Every known tag, most used first. Libraries can hold thousands of tags
  /// (Jellyfin stores TMDb keywords as tags), so this is built once.
  late final List<String> _tagUniverse;

  @override
  void initState() {
    super.initState();
    final filter = widget.filter;
    _candidateList = List<CatalogCandidate>.unmodifiable(widget.candidates);
    final usage = <String, int>{};
    for (final candidate in _candidateList) {
      for (final tag in candidate.tags) {
        usage[tag] = (usage[tag] ?? 0) + 1;
      }
    }
    _tagUniverse = List<String>.unmodifiable(
      <String>{...usage.keys, ...widget.facets.tags}.toList()..sort((a, b) {
        final byUse = (usage[b] ?? 0).compareTo(usage[a] ?? 0);
        return byUse != 0 ? byUse : a.toLowerCase().compareTo(b.toLowerCase());
      }),
    );
    _search.text = filter.searchTerm;
    _genresText.text = filter.genres.join(', ');
    _libraryId =
        widget.libraries.any((library) => library.id == filter.libraryId)
        ? filter.libraryId
        : null;
    _genres = DiscoveryFacetSelection<String>(
      included: filter.genres,
      excluded: filter.excludedGenres,
    );
    _tags = DiscoveryFacetSelection<String>(
      included: filter.tags,
      excluded: filter.excludedTags,
    );
    _decades = DiscoveryFacetSelection<int>(
      included: filter.decades,
      excluded: filter.excludedDecades,
    );
    _ratings = DiscoveryFacetSelection<String>(
      included: filter.officialRatings,
      excluded: filter.excludedOfficialRatings,
    );
    _sortReversed = filter.sortReversed;
    _runtime = RangeValues(
      (filter.minimumRuntimeMinutes ?? 0).toDouble(),
      (filter.maximumRuntimeMinutes ?? _maxRuntime).toDouble(),
    );
    _community = filter.minimumCommunityRating ?? 0;
    _critic = filter.minimumCriticRating ?? 0;
    _watched = _triState(filter.watched);
    _favorite = _triState(filter.favorite);
    _sort = filter.sort;
    _addedWithin = filter.addedWithin;
    _seriesStatuses = filter.seriesStatuses;
    _seriesLengths = filter.seriesLengths;
    _watchProgress = filter.watchProgress;
    _series =
        context.read<DiscoveryCubit>().mediaType == CatalogMediaType.series;
    // Keep the tab badges in step with typed search and genre text.
    _search.addListener(_refresh);
    _genresText.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    _genresText.dispose();
    _presetText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DiscoveryCubit>().state;
    return DiscoveryFilterBody(
      quickFilters: (
        recent: _addedWithin == CatalogAddedWindow.thirtyDays,
        unwatched: _watched == DiscoveryTriState.no,
        favorites: _favorite == DiscoveryTriState.yes,
        onRecentChanged: (selected) => setState(
          () => _addedWithin = selected ? CatalogAddedWindow.thirtyDays : null,
        ),
        onUnwatchedChanged: (selected) => setState(
          () => _watched = selected
              ? DiscoveryTriState.no
              : DiscoveryTriState.any,
        ),
        onFavoritesChanged: (selected) => setState(
          () => _favorite = selected
              ? DiscoveryTriState.yes
              : DiscoveryTriState.any,
        ),
        inProgress: _series
            ? _watchProgress.contains(CatalogWatchProgress.inProgress)
            : null,
        onInProgressChanged: _series
            ? (selected) => setState(
                () => _watchProgress = selected
                    ? <CatalogWatchProgress>{
                        ..._watchProgress,
                        CatalogWatchProgress.inProgress,
                      }
                    : (Set<CatalogWatchProgress>.of(_watchProgress)
                        ..remove(CatalogWatchProgress.inProgress)),
              )
            : null,
      ),
      series: _series
          ? (
              statuses: _seriesStatuses,
              lengths: _seriesLengths,
              progress: _watchProgress,
              onStatusesChanged: (value) =>
                  setState(() => _seriesStatuses = value),
              onLengthsChanged: (value) =>
                  setState(() => _seriesLengths = value),
              onProgressChanged: (value) =>
                  setState(() => _watchProgress = value),
            )
          : null,
      query: (
        searchController: _search,
        libraries: widget.libraries,
        libraryId: _libraryId,
        sort: _sort,
        sortReversed: _sortReversed,
        addedWithin: _addedWithin,
        onSortChanged: (value) => setState(() {
          // A new order starts in its natural direction.
          if (value != _sort) _sortReversed = false;
          _sort = value;
        }),
        onSortReversedChanged: (value) => setState(() => _sortReversed = value),
        onLibraryChanged: (value) => setState(() => _libraryId = value),
        onAddedWithinChanged: (value) => setState(() => _addedWithin = value),
      ),
      ratings: (
        runtime: _runtime,
        community: _community,
        critic: _critic,
        onRuntimeChanged: (value) => setState(() => _runtime = value),
        onCommunityChanged: (value) => setState(() => _community = value),
        onCriticChanged: (value) => setState(() => _critic = value),
      ),
      metadata: (
        genresController: _genresText,
        genres: _genres,
        tags: _tags,
        decades: _decades,
        officialRatings: _ratings,
        watched: _watched,
        favorite: _favorite,
        availableGenres: _genresFromCandidates,
        availableTags: _tagsFromCandidates,
        availableDecades: _decadesFromCandidates,
        availableRatings: _ratingsFromCandidates,
        onSelectionChanged: _refresh,
        onWatchedChanged: (value) => setState(() => _watched = value),
        onFavoriteChanged: (value) => setState(() => _favorite = value),
      ),
      presets: (
        nameController: _presetText,
        presets: state.presets,
        suggestedPresets: buildDiscoveryDefaultPresets(
          AppLocalizations.of(context),
          mediaType: state.mediaType,
        ),
        onApply: _applyPreset,
        onApplySuggested: _applySuggested,
        onDelete: _deletePreset,
        onSave: _savePreset,
      ),
      onReset: _reset,
      onApply: _apply,
    );
  }

  List<String> get _genresFromCandidates =>
      (widget.facets.genres.isEmpty
              ? _candidateList.expand((candidate) => candidate.genres)
              : widget.facets.genres)
          .followedBy(_genres.included)
          .followedBy(_genres.excluded)
          .toSet()
          .toList()
        ..sort();

  List<int> get _decadesFromCandidates =>
      (widget.facets.years.isEmpty
              ? _candidateList
                    .map((candidate) => candidate.year)
                    .whereType<int>()
              : widget.facets.years)
          .map((year) => (year ~/ 10) * 10)
          .followedBy(_decades.included)
          .followedBy(_decades.excluded)
          .toSet()
          .toList()
        ..sort();

  List<String> get _ratingsFromCandidates =>
      (widget.facets.officialRatings.isEmpty
              ? _candidateList
                    .map((candidate) => candidate.officialRating)
                    .whereType<String>()
              : widget.facets.officialRatings)
          .followedBy(_ratings.included)
          .followedBy(_ratings.excluded)
          .toSet()
          .toList()
        ..sort();

  List<String> get _tagsFromCandidates => _tagUniverse;

  /// The filter currently described by the sheet, before it is applied.
  CatalogFilter _draftFilter() {
    final genres = _genres.included.isNotEmpty || _genres.excluded.isNotEmpty
        ? _genres.included
        : _genresText.text
              .split(',')
              .map((value) => value.trim().toLowerCase())
              .where((value) => value.isNotEmpty)
              .toSet();
    return CatalogFilter(
      libraryId: _libraryId,
      searchTerm: _search.text.trim(),
      addedWithin: _addedWithin,
      sort: _sort,
      sortReversed: _sortReversed,
      minimumRuntimeMinutes: _runtime.start == 0
          ? null
          : _runtime.start.round(),
      maximumRuntimeMinutes: _runtime.end == _maxRuntime
          ? null
          : _runtime.end.round(),
      minimumCommunityRating: _community == 0 ? null : _community,
      maximumCommunityRating: widget.filter.maximumCommunityRating,
      minimumCriticRating: _critic == 0 ? null : _critic,
      maximumCriticRating: widget.filter.maximumCriticRating,
      genres: genres,
      excludedGenres: _genres.excluded,
      tags: _tags.included,
      excludedTags: _tags.excluded,
      decades: _decades.included,
      excludedDecades: _decades.excluded,
      officialRatings: _ratings.included,
      excludedOfficialRatings: _ratings.excluded,
      watched: _bool(_watched),
      favorite: _bool(_favorite),
      seriesStatuses: _seriesStatuses,
      seriesLengths: _seriesLengths,
      watchProgress: _watchProgress,
    );
  }

  Future<void> _apply() async {
    await context.read<DiscoveryCubit>().updateFilter(_draftFilter());
    if (mounted) Navigator.pop(context);
  }

  Future<void> _reset() async {
    await context.read<DiscoveryCubit>().resetFilters();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _savePreset() async {
    final name = _presetText.text.trim();
    if (name.isEmpty) return;
    await context.read<DiscoveryCubit>().savePreset(
      name,
      filter: _draftFilter(),
    );
    _presetText.clear();
  }

  Future<void> _applyPreset(String name) async {
    await context.read<DiscoveryCubit>().applyPreset(name);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _applySuggested(CatalogFilter filter) async {
    await context.read<DiscoveryCubit>().updateFilter(filter);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deletePreset(String name) =>
      context.read<DiscoveryCubit>().deletePreset(name);

  static DiscoveryTriState _triState(bool? value) => switch (value) {
    true => DiscoveryTriState.yes,
    false => DiscoveryTriState.no,
    null => DiscoveryTriState.any,
  };

  static bool? _bool(DiscoveryTriState value) => switch (value) {
    DiscoveryTriState.any => null,
    DiscoveryTriState.yes => true,
    DiscoveryTriState.no => false,
  };
}
