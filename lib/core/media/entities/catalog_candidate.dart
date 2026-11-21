import 'dart:collection';

enum CatalogMediaType { movie, series }

/// What Jellyfin reports about a TV series as a whole. Every count is null
/// when the server leaves it out.
final class CatalogSeriesFacts {
  const CatalogSeriesFacts({
    this.seasonCount,
    this.episodeCount,
    this.unplayedEpisodeCount,
    this.endYear,
    this.lastEpisodeAdded,
  });

  /// Seasons on the server, specials included when Jellyfin counts them.
  final int? seasonCount;

  /// Episodes on the server.
  final int? episodeCount;

  /// Episodes the user has not played yet.
  final int? unplayedEpisodeCount;

  /// The year the series ended, for series that have.
  final int? endYear;

  /// When an episode was last added to the library, in UTC.
  final DateTime? lastEpisodeAdded;

  /// Episodes the user has played, when both counts are known.
  int? get playedEpisodeCount {
    final total = episodeCount;
    final unplayed = unplayedEpisodeCount;
    if (total == null || unplayed == null || unplayed > total) {
      return null;
    }
    return total - unplayed;
  }

  /// The share of episodes played, from 0 to 1, when known.
  double? get progress {
    final played = playedEpisodeCount;
    final total = episodeCount;
    if (played == null || total == null || total == 0) {
      return null;
    }
    return played / total;
  }

  /// Whether the user has played some, but not all, episodes.
  bool get isInProgress {
    final played = playedEpisodeCount;
    final unplayed = unplayedEpisodeCount;
    return played != null && unplayed != null && played > 0 && unplayed > 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogSeriesFacts &&
          other.seasonCount == seasonCount &&
          other.episodeCount == episodeCount &&
          other.unplayedEpisodeCount == unplayedEpisodeCount &&
          other.endYear == endYear &&
          other.lastEpisodeAdded == lastEpisodeAdded;

  @override
  int get hashCode => Object.hash(
    seasonCount,
    episodeCount,
    unplayedEpisodeCount,
    endYear,
    lastEpisodeAdded,
  );
}

final class CatalogTrailer {
  const CatalogTrailer({required this.uri, this.name});

  final Uri uri;
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogTrailer && other.uri == uri && other.name == name;

  @override
  int get hashCode => Object.hash(uri, name);
}

final class CatalogImage {
  const CatalogImage({
    required this.uri,
    required this.isFallback,
    required this.aspectRatio,
    this.blurHash,
  });

  const CatalogImage.fallback()
    : uri = null,
      isFallback = true,
      aspectRatio = 0.67,
      blurHash = null;

  final Uri? uri;
  final bool isFallback;
  final double aspectRatio;
  final String? blurHash;

  Uri? variantUri({required int maxWidth, required int quality, int? blur}) {
    final source = uri;
    if (source == null || isFallback) {
      return null;
    }
    return source.replace(
      queryParameters: <String, String>{
        ...source.queryParameters,
        'maxWidth': '$maxWidth',
        'quality': '$quality',
        if (blur != null) 'blur': '$blur',
      },
    );
  }
}

final class CatalogCandidate {
  const CatalogCandidate({
    required this.id,
    required this.name,
    required this.mediaType,
    required this.poster,
    required this.backdrop,
    this.year,
    this.dateCreated,
    this.runtimeMinutes,
    Set<String> genres = const <String>{},
    Set<String> tags = const <String>{},
    this.communityRating,
    this.criticRating,
    this.officialRating,
    this.status,
    this.overview,
    List<String> cast = const <String>[],
    List<CatalogTrailer> trailers = const <CatalogTrailer>[],
    this.watched,
    this.favorite,
    Set<String> studios = const <String>{},
    this.playCount,
    this.lastPlayed,
    this.likes,
    this.userRating,
    this.series,
  }) : // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _studios = studios,
       // ignore: prefer_initializing_formals
       _genres = genres,
       // ignore: prefer_initializing_formals
       _tags = tags,
       // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _cast = cast,
       // Public constructor names intentionally differ from backing fields.
       // ignore: prefer_initializing_formals
       _trailers = trailers;

  final String id;
  final String name;
  final CatalogMediaType mediaType;
  final int? year;
  final DateTime? dateCreated;
  final int? runtimeMinutes;
  final Set<String> _genres;
  final Set<String> _tags;
  final double? communityRating;
  final double? criticRating;
  final String? officialRating;
  final String? status;
  final String? overview;
  final List<String> _cast;
  final List<CatalogTrailer> _trailers;
  final bool? watched;
  final bool? favorite;
  final Set<String> _studios;

  /// How many times the user has played this title, when Jellyfin says.
  final int? playCount;

  /// When the user last played this title, in UTC.
  final DateTime? lastPlayed;

  /// The user's thumbs up (true) or down (false), if they set one.
  final bool? likes;

  /// The user's own rating on Jellyfin's 0–10 scale; 0 means unrated.
  final double? userRating;

  /// Seasons, episodes and progress; only TV series carry these.
  final CatalogSeriesFacts? series;
  final CatalogImage poster;
  final CatalogImage backdrop;

  Set<String> get genres => UnmodifiableSetView<String>(_genres);

  /// Studio names, as written on the server.
  Set<String> get studios => UnmodifiableSetView<String>(_studios);

  /// Jellyfin tags on the title, as written on the server.
  Set<String> get tags => UnmodifiableSetView<String>(_tags);

  List<String> get cast => UnmodifiableListView<String>(_cast);

  List<CatalogTrailer> get trailers =>
      UnmodifiableListView<CatalogTrailer>(_trailers);

  CatalogCandidate copyWith({
    Object? dateCreated = _unset,
    bool? favorite,
    Set<String>? tags,
  }) => CatalogCandidate(
    id: id,
    name: name,
    mediaType: mediaType,
    year: year,
    dateCreated: _copyDate(dateCreated, this.dateCreated),
    runtimeMinutes: runtimeMinutes,
    genres: _genres,
    tags: tags ?? _tags,
    communityRating: communityRating,
    criticRating: criticRating,
    officialRating: officialRating,
    status: status,
    overview: overview,
    cast: _cast,
    trailers: _trailers,
    watched: watched,
    favorite: favorite ?? this.favorite,
    studios: _studios,
    playCount: playCount,
    lastPlayed: lastPlayed,
    likes: likes,
    userRating: userRating,
    series: series,
    poster: poster,
    backdrop: backdrop,
  );

  static DateTime? _copyDate(Object? value, DateTime? current) =>
      identical(value, _unset)
      ? current
      : value is DateTime
      ? value
      : null;
}

const _unset = Object();
