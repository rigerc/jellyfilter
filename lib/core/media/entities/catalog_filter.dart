import 'dart:collection';

import 'package:jellyfin_picker/core/media/entities/catalog_candidate.dart';

enum CatalogAddedWindow {
  sevenDays,
  thirtyDays,
  ninetyDays,
  threeHundredSixtyFiveDays;

  int get days => switch (this) {
    CatalogAddedWindow.sevenDays => 7,
    CatalogAddedWindow.thirtyDays => 30,
    CatalogAddedWindow.ninetyDays => 90,
    CatalogAddedWindow.threeHundredSixtyFiveDays => 365,
  };
}

enum CatalogSort {
  defaultOrder,
  random,
  recentlyAdded,
  title,
  releaseYear,
  communityRating,
  runtime,
}

enum CatalogSeriesStatus { continuing, ended }

/// Filter dimensions are ANDed; multi-valued attributes require every value.
final class CatalogFilter {
  const CatalogFilter({
    Set<CatalogMediaType> mediaTypes = const <CatalogMediaType>{},
    this.libraryId,
    this.searchTerm = '',
    this.addedWithin,
    this.dateWindowAnchor,
    this.sort = CatalogSort.defaultOrder,
    this.minimumRuntimeMinutes,
    this.maximumRuntimeMinutes,
    this.minimumCommunityRating,
    this.maximumCommunityRating,
    this.minimumCriticRating,
    this.maximumCriticRating,
    Set<String> genres = const <String>{},
    Set<int> decades = const <int>{},
    Set<String> officialRatings = const <String>{},
    Set<CatalogSeriesStatus> seriesStatuses = const <CatalogSeriesStatus>{},
    this.watched,
    this.favorite,
    this.sortReversed = false,
    Set<String> tags = const <String>{},
    Set<String> excludedGenres = const <String>{},
    Set<String> excludedTags = const <String>{},
    Set<int> excludedDecades = const <int>{},
    Set<String> excludedOfficialRatings = const <String>{},
  }) : // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _tags = tags,
       // ignore: prefer_initializing_formals
       _excludedGenres = excludedGenres,
       // ignore: prefer_initializing_formals
       _excludedTags = excludedTags,
       // ignore: prefer_initializing_formals
       _excludedDecades = excludedDecades,
       // ignore: prefer_initializing_formals
       _excludedOfficialRatings = excludedOfficialRatings,
       // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _mediaTypes = mediaTypes,
       // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _genres = genres,
       // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _decades = decades,
       // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _officialRatings = officialRatings,
       // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _seriesStatuses = seriesStatuses;

  final Set<CatalogMediaType> _mediaTypes;
  final String? libraryId;
  final String searchTerm;
  final CatalogAddedWindow? addedWithin;
  final DateTime? dateWindowAnchor;
  final CatalogSort sort;
  final int? minimumRuntimeMinutes;
  final int? maximumRuntimeMinutes;
  final double? minimumCommunityRating;
  final double? maximumCommunityRating;
  final double? minimumCriticRating;
  final double? maximumCriticRating;
  final Set<String> _genres;
  final Set<int> _decades;
  final Set<String> _officialRatings;
  final Set<CatalogSeriesStatus> _seriesStatuses;
  final bool? watched;
  final bool? favorite;

  /// Runs the chosen sort in the opposite direction.
  final bool sortReversed;
  final Set<String> _tags;
  final Set<String> _excludedGenres;
  final Set<String> _excludedTags;
  final Set<int> _excludedDecades;
  final Set<String> _excludedOfficialRatings;

  /// Tags a title must all carry.
  Set<String> get tags => UnmodifiableSetView<String>(_tags);

  /// Values a title must not have. Jellyfin cannot exclude these on the
  /// server, so they are applied while results stream in.
  Set<String> get excludedGenres =>
      UnmodifiableSetView<String>(_excludedGenres);

  Set<String> get excludedTags => UnmodifiableSetView<String>(_excludedTags);

  Set<int> get excludedDecades => UnmodifiableSetView<int>(_excludedDecades);

  Set<String> get excludedOfficialRatings =>
      UnmodifiableSetView<String>(_excludedOfficialRatings);

  bool get hasExclusions =>
      _excludedGenres.isNotEmpty ||
      _excludedTags.isNotEmpty ||
      _excludedDecades.isNotEmpty ||
      _excludedOfficialRatings.isNotEmpty;

  /// Constraints the server only partly applies, so a page can come back
  /// with nothing left after local refinement.
  bool get needsLocalRefinement =>
      genres.length > 1 || _tags.length > 1 || hasExclusions;

  /// Whether this sort has a direction to reverse.
  bool get canReverseSort =>
      sort != CatalogSort.defaultOrder && sort != CatalogSort.random;

  Set<CatalogMediaType> get mediaTypes =>
      UnmodifiableSetView<CatalogMediaType>(_mediaTypes);

  Set<String> get genres => UnmodifiableSetView<String>(_genres);

  Set<int> get decades => UnmodifiableSetView<int>(_decades);

  Set<String> get officialRatings =>
      UnmodifiableSetView<String>(_officialRatings);

  Set<CatalogSeriesStatus> get seriesStatuses =>
      UnmodifiableSetView<CatalogSeriesStatus>(_seriesStatuses);

  bool get isActive =>
      libraryId != null ||
      mediaTypes.isNotEmpty ||
      searchTerm.trim().isNotEmpty ||
      addedWithin != null ||
      minimumRuntimeMinutes != null ||
      maximumRuntimeMinutes != null ||
      minimumCommunityRating != null ||
      maximumCommunityRating != null ||
      minimumCriticRating != null ||
      maximumCriticRating != null ||
      genres.isNotEmpty ||
      decades.isNotEmpty ||
      _hasOfficialRatingConstraint ||
      seriesStatuses.isNotEmpty ||
      watched != null ||
      favorite != null ||
      _tags.isNotEmpty ||
      hasExclusions;

  bool matches(CatalogCandidate candidate, {DateTime? now}) =>
      _matchesMediaType(candidate) &&
      _matchesSearch(candidate) &&
      _matchesAddedWithin(candidate, now) &&
      _matchesNumericRanges(candidate) &&
      _matchesGenres(candidate) &&
      _matchesTags(candidate) &&
      _matchesExclusions(candidate) &&
      _matchesDecades(candidate) &&
      _matchesOfficialRating(candidate) &&
      _matchesSeries(candidate) &&
      _matchesFlags(candidate);

  bool _matchesMediaType(CatalogCandidate candidate) =>
      candidate.mediaType == CatalogMediaType.movie &&
      (mediaTypes.isEmpty || mediaTypes.contains(CatalogMediaType.movie));

  bool _matchesSearch(CatalogCandidate candidate) {
    final normalizedSearchTerm = _prepared.search;
    return normalizedSearchTerm.isEmpty ||
        _normalize(candidate.name).contains(normalizedSearchTerm);
  }

  bool _matchesAddedWithin(CatalogCandidate candidate, DateTime? now) {
    final window = addedWithin;
    if (window == null) {
      return true;
    }
    final dateCreated = candidate.dateCreated;
    if (dateCreated == null) {
      return false;
    }
    final currentTime = (now ?? dateWindowAnchor ?? DateTime.now()).toUtc();
    final cutoff = currentTime.subtract(Duration(days: window.days));
    final normalizedDateCreated = dateCreated.toUtc();
    return normalizedDateCreated.isAfter(cutoff) ||
        normalizedDateCreated.isAtSameMomentAs(cutoff);
  }

  bool _matchesNumericRanges(CatalogCandidate candidate) =>
      _matchesRange(
        candidate.runtimeMinutes,
        minimumRuntimeMinutes,
        maximumRuntimeMinutes,
      ) &&
      _matchesRange(
        candidate.communityRating,
        minimumCommunityRating,
        maximumCommunityRating,
      ) &&
      _matchesRange(
        candidate.criticRating,
        minimumCriticRating,
        maximumCriticRating,
      );

  bool _matchesGenres(CatalogCandidate candidate) {
    final selectedGenres = _prepared.genres;
    return selectedGenres.isEmpty ||
        _normalizedFacets(candidate).genres.containsAll(selectedGenres);
  }

  bool _matchesTags(CatalogCandidate candidate) {
    final required = _prepared.tags;
    return required.isEmpty ||
        _normalizedFacets(candidate).tags.containsAll(required);
  }

  bool _matchesExclusions(CatalogCandidate candidate) {
    if (!hasExclusions) {
      return true;
    }
    final prepared = _prepared;
    final facets = _normalizedFacets(candidate);
    final year = candidate.year;
    final rating = candidate.officialRating;
    return !facets.genres.any(prepared.excludedGenres.contains) &&
        !facets.tags.any(prepared.excludedTags.contains) &&
        !(year != null && _excludedDecades.contains((year ~/ 10) * 10)) &&
        !(rating != null &&
            prepared.excludedRatings.contains(_normalize(rating)));
  }

  /// Normalized forms of this filter's text constraints, computed once per
  /// filter instead of once per title checked.
  _PreparedFilter get _prepared => _preparedCache[this] ??= _PreparedFilter(
    search: _normalize(searchTerm),
    genres: _genres.map(_normalize).toSet(),
    tags: _tags.map(_normalize).toSet(),
    excludedGenres: _excludedGenres.map(_normalize).toSet(),
    excludedTags: _excludedTags.map(_normalize).toSet(),
    excludedRatings: _excludedOfficialRatings.map(_normalize).toSet(),
    ratings: _officialRatings
        .map(_normalize)
        .where((rating) => rating.isNotEmpty)
        .toSet(),
  );

  static final Expando<_PreparedFilter> _preparedCache =
      Expando<_PreparedFilter>('CatalogFilter.prepared');

  /// A title's normalized genres and tags, computed once per title.
  static _NormalizedFacets _normalizedFacets(CatalogCandidate candidate) =>
      _facetCache[candidate] ??= _NormalizedFacets(
        genres: candidate.genres.map(_normalize).toSet(),
        tags: candidate.tags.map(_normalize).toSet(),
      );

  static final Expando<_NormalizedFacets> _facetCache =
      Expando<_NormalizedFacets>('CatalogCandidate.normalizedFacets');

  bool _matchesDecades(CatalogCandidate candidate) {
    if (decades.isEmpty) {
      return true;
    }
    final year = candidate.year;
    return year != null && decades.contains((year ~/ 10) * 10);
  }

  bool _matchesOfficialRating(CatalogCandidate candidate) {
    final selectedOfficialRatings = _normalizedOfficialRatings;
    if (selectedOfficialRatings.isEmpty) {
      return true;
    }
    final officialRating = candidate.officialRating;
    return officialRating != null &&
        selectedOfficialRatings.contains(_normalize(officialRating));
  }

  bool _matchesSeries(CatalogCandidate candidate) {
    if (seriesStatuses.isEmpty) {
      return true;
    }
    final status = candidate.status;
    return status != null && _matchesSeriesStatus(status);
  }

  bool _matchesFlags(CatalogCandidate candidate) =>
      (watched == null || candidate.watched == watched) &&
      (favorite == null || candidate.favorite == favorite);

  CatalogFilter copyWith({
    Set<CatalogMediaType>? mediaTypes,
    Object? libraryId = _unset,
    String? searchTerm,
    Object? addedWithin = _unset,
    Object? dateWindowAnchor = _unset,
    CatalogSort? sort,
    Object? minimumRuntimeMinutes = _unset,
    Object? maximumRuntimeMinutes = _unset,
    Object? minimumCommunityRating = _unset,
    Object? maximumCommunityRating = _unset,
    Object? minimumCriticRating = _unset,
    Object? maximumCriticRating = _unset,
    Set<String>? genres,
    Set<int>? decades,
    Set<String>? officialRatings,
    Set<CatalogSeriesStatus>? seriesStatuses,
    Object? watched = _unset,
    Object? favorite = _unset,
    bool? sortReversed,
    Set<String>? tags,
    Set<String>? excludedGenres,
    Set<String>? excludedTags,
    Set<int>? excludedDecades,
    Set<String>? excludedOfficialRatings,
  }) => CatalogFilter(
    mediaTypes: mediaTypes ?? this.mediaTypes,
    libraryId: _copyString(libraryId, this.libraryId),
    searchTerm: searchTerm ?? this.searchTerm,
    addedWithin: _copyWindow(addedWithin, this.addedWithin),
    dateWindowAnchor: _copyDate(dateWindowAnchor, this.dateWindowAnchor),
    sort: sort ?? this.sort,
    minimumRuntimeMinutes: _copyInt(
      minimumRuntimeMinutes,
      this.minimumRuntimeMinutes,
    ),
    maximumRuntimeMinutes: _copyInt(
      maximumRuntimeMinutes,
      this.maximumRuntimeMinutes,
    ),
    minimumCommunityRating: _copyDouble(
      minimumCommunityRating,
      this.minimumCommunityRating,
    ),
    maximumCommunityRating: _copyDouble(
      maximumCommunityRating,
      this.maximumCommunityRating,
    ),
    minimumCriticRating: _copyDouble(
      minimumCriticRating,
      this.minimumCriticRating,
    ),
    maximumCriticRating: _copyDouble(
      maximumCriticRating,
      this.maximumCriticRating,
    ),
    genres: genres ?? this.genres,
    decades: decades ?? this.decades,
    officialRatings: officialRatings ?? this.officialRatings,
    seriesStatuses: seriesStatuses ?? this.seriesStatuses,
    watched: _copyBool(watched, this.watched),
    favorite: _copyBool(favorite, this.favorite),
    sortReversed: sortReversed ?? this.sortReversed,
    tags: tags ?? this.tags,
    excludedGenres: excludedGenres ?? this.excludedGenres,
    excludedTags: excludedTags ?? this.excludedTags,
    excludedDecades: excludedDecades ?? this.excludedDecades,
    excludedOfficialRatings:
        excludedOfficialRatings ?? this.excludedOfficialRatings,
  );

  static CatalogAddedWindow? _copyWindow(
    Object? value,
    CatalogAddedWindow? current,
  ) => identical(value, _unset)
      ? current
      : value is CatalogAddedWindow
      ? value
      : null;

  static int? _copyInt(Object? value, int? current) => identical(value, _unset)
      ? current
      : value is int
      ? value
      : null;

  static DateTime? _copyDate(Object? value, DateTime? current) =>
      identical(value, _unset)
      ? current
      : value is DateTime
      ? value
      : null;

  static double? _copyDouble(Object? value, double? current) =>
      identical(value, _unset)
      ? current
      : value is num
      ? value.toDouble()
      : null;

  static bool? _copyBool(Object? value, bool? current) =>
      identical(value, _unset)
      ? current
      : value is bool
      ? value
      : null;

  static String? _copyString(Object? value, String? current) =>
      identical(value, _unset)
      ? current
      : value is String && value.trim().isNotEmpty
      ? value.trim()
      : null;

  bool get _hasOfficialRatingConstraint =>
      _normalizedOfficialRatings.isNotEmpty;

  Set<String> get _normalizedOfficialRatings => _prepared.ratings;

  bool _matchesSeriesStatus(String status) {
    final normalizedStatus = _normalize(status);
    return seriesStatuses.any(
      (selectedStatus) => switch (selectedStatus) {
        CatalogSeriesStatus.continuing => _continuingStatuses.contains(
          normalizedStatus,
        ),
        CatalogSeriesStatus.ended => _endedStatuses.contains(normalizedStatus),
      },
    );
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(_whitespace, ' ');

  static final RegExp _whitespace = RegExp(r'\s+');

  static const _continuingStatuses = <String>{
    'continuing',
    'returning series',
    'in production',
  };

  static const _endedStatuses = <String>{'ended', 'canceled', 'cancelled'};

  bool _matchesRange<T extends num>(T? value, T? minimum, T? maximum) {
    if (minimum == null && maximum == null) {
      return true;
    }
    if (value == null) {
      return false;
    }
    return (minimum == null || value >= minimum) &&
        (maximum == null || value <= maximum);
  }
}

const _unset = Object();

final class _PreparedFilter {
  _PreparedFilter({
    required this.search,
    required this.genres,
    required this.tags,
    required this.excludedGenres,
    required this.excludedTags,
    required this.excludedRatings,
    required this.ratings,
  });

  final String search;
  final Set<String> genres;
  final Set<String> tags;
  final Set<String> excludedGenres;
  final Set<String> excludedTags;
  final Set<String> excludedRatings;
  final Set<String> ratings;
}

final class _NormalizedFacets {
  _NormalizedFacets({required this.genres, required this.tags});

  final Set<String> genres;
  final Set<String> tags;
}
