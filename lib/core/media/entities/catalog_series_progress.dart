import 'dart:collection';

/// One season of a TV series, with the user's progress through it.
final class CatalogSeason {
  const CatalogSeason({
    required this.id,
    required this.name,
    this.number,
    this.episodeCount,
    this.unplayedEpisodeCount,
  });

  final String id;
  final String name;

  /// The season number; 0 is usually specials.
  final int? number;
  final int? episodeCount;
  final int? unplayedEpisodeCount;

  /// Episodes the user has played, when both counts are known.
  int? get playedEpisodeCount {
    final total = episodeCount;
    final unplayed = unplayedEpisodeCount;
    if (total == null || unplayed == null || unplayed > total) {
      return null;
    }
    return total - unplayed;
  }
}

/// One episode of a TV series.
final class CatalogEpisode {
  const CatalogEpisode({
    required this.id,
    required this.name,
    this.seasonNumber,
    this.episodeNumber,
    this.runtimeMinutes,
  });

  final String id;
  final String name;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? runtimeMinutes;
}

/// A series' seasons and the episode to watch next.
final class CatalogSeriesProgress {
  CatalogSeriesProgress({
    List<CatalogSeason> seasons = const <CatalogSeason>[],
    this.nextUp,
  }) : seasons = UnmodifiableListView<CatalogSeason>(seasons);

  final List<CatalogSeason> seasons;

  /// The next episode to watch, if Jellyfin knows one.
  final CatalogEpisode? nextUp;
}
