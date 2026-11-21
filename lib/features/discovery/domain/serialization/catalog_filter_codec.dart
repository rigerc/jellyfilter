import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';

abstract final class CatalogFilterCodec {
  static Map<String, Object?> encode(CatalogFilter filter) => <String, Object?>{
    'libraryId': filter.libraryId,
    'mediaTypes': filter.mediaTypes.map((type) => type.name).toList()..sort(),
    'searchTerm': filter.searchTerm,
    'addedWithin': filter.addedWithin?.name,
    'sort': filter.sort.name,
    'minimumRuntimeMinutes': filter.minimumRuntimeMinutes,
    'maximumRuntimeMinutes': filter.maximumRuntimeMinutes,
    'minimumCommunityRating': filter.minimumCommunityRating,
    'maximumCommunityRating': filter.maximumCommunityRating,
    'minimumCriticRating': filter.minimumCriticRating,
    'maximumCriticRating': filter.maximumCriticRating,
    'genres': filter.genres.toList()..sort(),
    'decades': filter.decades.toList()..sort(),
    'officialRatings': filter.officialRatings.toList()..sort(),
    'seriesStatuses':
        filter.seriesStatuses.map((status) => status.name).toList()..sort(),
    'seriesLengths': filter.seriesLengths.map((length) => length.name).toList()
      ..sort(),
    'watchProgress':
        filter.watchProgress.map((progress) => progress.name).toList()..sort(),
    'watched': filter.watched,
    'favorite': filter.favorite,
    'sortReversed': filter.sortReversed,
    'tags': filter.tags.toList()..sort(),
    'excludedGenres': filter.excludedGenres.toList()..sort(),
    'excludedTags': filter.excludedTags.toList()..sort(),
    'excludedDecades': filter.excludedDecades.toList()..sort(),
    'excludedOfficialRatings': filter.excludedOfficialRatings.toList()..sort(),
  };

  static CatalogFilter? decode(Object? value) {
    if (value is! Map) {
      return null;
    }
    final mediaTypes = _mediaTypes(value['mediaTypes']);
    final libraryId = value.containsKey('libraryId')
        ? _nullableString(value['libraryId'])
        : null;
    final genres = _strings(value['genres']);
    final decades = _integers(value['decades']);
    final searchTerm = value.containsKey('searchTerm')
        ? _string(value['searchTerm'])
        : '';
    final addedWithin = _addedWithin(value['addedWithin']);
    final sort = _sort(value['sort']);
    final officialRatings = value.containsKey('officialRatings')
        ? _strings(value['officialRatings'])
        : <String>{};
    // Added later: absent in older saves, so missing means empty.
    Set<String>? optionalStrings(String key) =>
        value.containsKey(key) ? _strings(value[key]) : <String>{};
    final tags = optionalStrings('tags');
    final excludedGenres = optionalStrings('excludedGenres');
    final excludedTags = optionalStrings('excludedTags');
    final excludedOfficialRatings = optionalStrings('excludedOfficialRatings');
    final excludedDecades = value.containsKey('excludedDecades')
        ? _integers(value['excludedDecades'])
        : <int>{};
    final sortReversed = value['sortReversed'];
    if (tags == null ||
        excludedGenres == null ||
        excludedTags == null ||
        excludedOfficialRatings == null ||
        excludedDecades == null ||
        (sortReversed != null && sortReversed is! bool) ||
        <String>[
          ...tags,
          ...excludedGenres,
          ...excludedTags,
          ...excludedOfficialRatings,
        ].any((item) => item.trim().isEmpty) ||
        excludedDecades.any((decade) => decade < 0 || decade % 10 != 0)) {
      return null;
    }
    final seriesStatuses = value.containsKey('seriesStatuses')
        ? _seriesStatuses(value['seriesStatuses'])
        : <CatalogSeriesStatus>{};
    final seriesLengths = value.containsKey('seriesLengths')
        ? _enumSet(value['seriesLengths'], CatalogSeriesLength.values)
        : <CatalogSeriesLength>{};
    final watchProgress = value.containsKey('watchProgress')
        ? _enumSet(value['watchProgress'], CatalogWatchProgress.values)
        : <CatalogWatchProgress>{};
    if (mediaTypes == null ||
        seriesLengths == null ||
        watchProgress == null ||
        genres == null ||
        decades == null ||
        searchTerm == null ||
        officialRatings == null ||
        seriesStatuses == null ||
        (value.containsKey('libraryId') &&
            value['libraryId'] != null &&
            libraryId == null) ||
        (value.containsKey('addedWithin') &&
            value['addedWithin'] != null &&
            addedWithin == null) ||
        (value.containsKey('sort') && value['sort'] != null && sort == null)) {
      return null;
    }
    final minimumRuntime = _int(value['minimumRuntimeMinutes']);
    final maximumRuntime = _int(value['maximumRuntimeMinutes']);
    final minimumCommunity = _double(value['minimumCommunityRating']);
    final maximumCommunity = _double(value['maximumCommunityRating']);
    final minimumCritic = _double(value['minimumCriticRating']);
    final maximumCritic = _double(value['maximumCriticRating']);
    if (!_isNumberOrNull(value['minimumRuntimeMinutes'], minimumRuntime) ||
        !_isNumberOrNull(value['maximumRuntimeMinutes'], maximumRuntime) ||
        !_isNumberOrNull(value['minimumCommunityRating'], minimumCommunity) ||
        !_isNumberOrNull(value['maximumCommunityRating'], maximumCommunity) ||
        !_isNumberOrNull(value['minimumCriticRating'], minimumCritic) ||
        !_isNumberOrNull(value['maximumCriticRating'], maximumCritic) ||
        !_isBoolOrNull(value['watched']) ||
        !_isBoolOrNull(value['favorite'])) {
      return null;
    }
    if (!_isValidRange(minimumRuntime, maximumRuntime, 0) ||
        !_isValidRange(minimumCommunity, maximumCommunity, 0, 10) ||
        !_isValidRange(minimumCritic, maximumCritic, 0, 100) ||
        decades.any((decade) => decade < 0 || decade % 10 != 0) ||
        genres.any((genre) => genre.trim().isEmpty) ||
        officialRatings.any((rating) => rating.trim().isEmpty)) {
      return null;
    }
    return CatalogFilter(
      libraryId: libraryId,
      mediaTypes: mediaTypes,
      searchTerm: searchTerm,
      addedWithin: addedWithin,
      sort: sort ?? CatalogSort.defaultOrder,
      minimumRuntimeMinutes: minimumRuntime,
      maximumRuntimeMinutes: maximumRuntime,
      minimumCommunityRating: minimumCommunity,
      maximumCommunityRating: maximumCommunity,
      minimumCriticRating: minimumCritic,
      maximumCriticRating: maximumCritic,
      genres: genres,
      decades: decades,
      officialRatings: officialRatings,
      seriesStatuses: seriesStatuses,
      seriesLengths: seriesLengths,
      watchProgress: watchProgress,
      watched: value['watched'] as bool?,
      favorite: value['favorite'] as bool?,
      sortReversed: sortReversed == true,
      tags: tags,
      excludedGenres: excludedGenres,
      excludedTags: excludedTags,
      excludedDecades: excludedDecades,
      excludedOfficialRatings: excludedOfficialRatings,
    );
  }

  static Set<CatalogMediaType>? _mediaTypes(Object? value) {
    if (value is! List) {
      return null;
    }
    final result = <CatalogMediaType>{};
    for (final item in value) {
      final type = switch (item) {
        'movie' => CatalogMediaType.movie,
        'series' => CatalogMediaType.series,
        _ => null,
      };
      if (type == null) {
        return null;
      }
      result.add(type);
    }
    return result;
  }

  static Set<String>? _strings(Object? value) =>
      value is List && value.every((item) => item is String)
      ? value.whereType<String>().toSet()
      : null;

  static String? _string(Object? value) => value is String ? value : null;

  static CatalogAddedWindow? _addedWithin(Object? value) => switch (value) {
    'sevenDays' || 'days7' => CatalogAddedWindow.sevenDays,
    'thirtyDays' || 'days30' => CatalogAddedWindow.thirtyDays,
    'ninetyDays' || 'days90' => CatalogAddedWindow.ninetyDays,
    'threeHundredSixtyFiveDays' ||
    'days365' => CatalogAddedWindow.threeHundredSixtyFiveDays,
    _ => null,
  };

  static CatalogSort? _sort(Object? value) => switch (value) {
    'defaultOrder' => CatalogSort.defaultOrder,
    'forYou' => CatalogSort.forYou,
    'random' => CatalogSort.random,
    'recentlyAdded' => CatalogSort.recentlyAdded,
    'title' => CatalogSort.title,
    'releaseYear' => CatalogSort.releaseYear,
    'communityRating' => CatalogSort.communityRating,
    'runtime' => CatalogSort.runtime,
    'newEpisodes' => CatalogSort.newEpisodes,
    null => CatalogSort.defaultOrder,
    _ => null,
  };

  static Set<CatalogSeriesStatus>? _seriesStatuses(Object? value) {
    if (value is! List) {
      return null;
    }
    final result = <CatalogSeriesStatus>{};
    for (final item in value) {
      final status = switch (item) {
        'continuing' => CatalogSeriesStatus.continuing,
        'ended' => CatalogSeriesStatus.ended,
        _ => null,
      };
      if (status == null) {
        return null;
      }
      result.add(status);
    }
    return result;
  }

  /// Values of [values] named in [value], or null when any name is unknown.
  static Set<T>? _enumSet<T extends Enum>(Object? value, List<T> values) {
    if (value is! List) {
      return null;
    }
    final byName = <String, T>{for (final item in values) item.name: item};
    final result = <T>{};
    for (final item in value) {
      final match = byName[item];
      if (match == null) {
        return null;
      }
      result.add(match);
    }
    return result;
  }

  static Set<int>? _integers(Object? value) =>
      value is List && value.every((item) => item is int)
      ? value.whereType<int>().toSet()
      : null;

  static String? _nullableString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static int? _int(Object? value) => value is int ? value : null;

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : null;

  static bool _isNumberOrNull(Object? raw, Object? parsed) =>
      raw == null || parsed != null;

  static bool _isBoolOrNull(Object? value) => value == null || value is bool;

  static bool _isValidRange<T extends num>(
    T? minimum,
    T? maximum,
    num lowerBound, [
    num? upperBound,
  ]) {
    if (minimum != null && minimum < lowerBound) {
      return false;
    }
    if (maximum != null && maximum < lowerBound) {
      return false;
    }
    if (upperBound != null &&
        ((minimum != null && minimum > upperBound) ||
            (maximum != null && maximum > upperBound))) {
      return false;
    }
    return minimum == null || maximum == null || minimum <= maximum;
  }
}
