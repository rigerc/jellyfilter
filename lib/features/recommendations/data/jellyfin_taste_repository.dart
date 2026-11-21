import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/network/media_browser_authorization.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/failures/taste_failure.dart';
import 'package:jellyfilter/features/recommendations/domain/repositories/taste_repository.dart';

/// Reads taste data from Jellyfin without images, keeping downloads small.
///
/// It learns about one kind of title, movies or TV series, so each kind
/// builds its own taste.
final class JellyfinTasteRepository implements TasteRepository {
  JellyfinTasteRepository({
    required this.client,
    required this.serverUrl,
    required this.accessToken,
    required this.deviceId,
    required this.userId,
    this.mediaType = CatalogMediaType.movie,
    this.timeout = const Duration(seconds: 15),
  });

  /// The kind of title whose taste this repository reads.
  final CatalogMediaType mediaType;

  bool get _series => mediaType == CatalogMediaType.series;

  /// Jellyfin's item type for [mediaType].
  String get _itemType => _series ? 'Series' : 'Movie';

  final http.Client client;
  final String serverUrl;
  final String accessToken;
  final String deviceId;
  final String userId;
  final Duration timeout;

  /// Items per history page.
  static const historyPageSize = 200;

  /// Upper bound on items read per history query.
  static const maxHistoryItems = 3000;

  /// Items per id lookup; long id lists make URLs too long for some proxies.
  static const idBatchSize = 50;

  /// Upper bound on movies read per person.
  static const maxPersonMovies = 500;

  static const _fields = 'Genres,Tags,Studios';

  @override
  Future<List<TasteItem>> loadHistory() async {
    final items = <String, TasteItem>{};
    if (_series) {
      for (final item in await _watchedSeries()) {
        items[item.id] = item;
      }
    }
    // Jellyfin ANDs item filters, so each kind of interaction is its own
    // query. Played titles come newest first so a cap drops the oldest.
    for (final query in <Map<String, String>>[
      // A series counts as watched through its episodes, read above.
      if (!_series)
        {
          'filters': 'IsPlayed',
          'sortBy': 'DatePlayed',
          'sortOrder': 'Descending',
        },
      {'filters': 'IsFavoriteOrLikes', 'sortBy': 'SortName'},
      {'filters': 'Dislikes', 'sortBy': 'SortName'},
    ]) {
      var startIndex = 0;
      while (startIndex < maxHistoryItems) {
        final page = await _getItems(<String, String>{
          ...query,
          'includeItemTypes': _itemType,
          'recursive': 'true',
          'fields': _fields,
          'enableUserData': 'true',
          'enableTotalRecordCount': 'true',
          'startIndex': '$startIndex',
          'limit': '$historyPageSize',
        });
        for (final item in page.items) {
          items.putIfAbsent(item.id, () => item);
        }
        startIndex += page.rawCount;
        final total = page.total;
        if (page.rawCount == 0 || total == null || startIndex >= total) {
          break;
        }
      }
    }
    return List<TasteItem>.unmodifiable(items.values);
  }

  /// Series with played episodes, newest first. Each carries how many
  /// episodes were played as its play count, so a show watched for a whole
  /// season outweighs a pilot.
  Future<List<TasteItem>> _watchedSeries() async {
    final episodes = <String, ({int count, DateTime? last})>{};
    var startIndex = 0;
    while (startIndex < maxHistoryItems) {
      final response = await _get(<String, String>{
        'filters': 'IsPlayed',
        'sortBy': 'DatePlayed',
        'sortOrder': 'Descending',
        'includeItemTypes': 'Episode',
        'recursive': 'true',
        'fields': '',
        'enableUserData': 'true',
        'enableTotalRecordCount': 'true',
        'startIndex': '$startIndex',
        'limit': '$historyPageSize',
      });
      final raw = _rawItems(response);
      for (final episode in raw) {
        final seriesId = episode['SeriesId'];
        if (episode['Type'] != 'Episode' ||
            seriesId is! String ||
            seriesId.isEmpty) {
          continue;
        }
        final userData = episode['UserData'];
        final played = userData is Map ? userData['LastPlayedDate'] : null;
        final playedAt = played is String
            ? DateTime.tryParse(played)?.toUtc()
            : null;
        final previous = episodes[seriesId];
        final last = previous?.last;
        episodes[seriesId] = (
          count: (previous?.count ?? 0) + 1,
          last: last == null || (playedAt != null && playedAt.isAfter(last))
              ? playedAt ?? last
              : last,
        );
      }
      startIndex += raw.length;
      final total = response['TotalRecordCount'];
      if (raw.isEmpty || total is! int || startIndex >= total) {
        break;
      }
    }
    if (episodes.isEmpty) {
      return const <TasteItem>[];
    }
    final series = await loadItems(episodes.keys.toSet());
    return <TasteItem>[
      for (final item in series)
        if (episodes[item.id] case final watched?)
          item.withWatchHistory(
            playCount: watched.count,
            lastPlayed: watched.last ?? item.lastPlayed,
          ),
    ];
  }

  @override
  Future<List<TasteItem>> loadItems(
    Set<String> ids, {
    bool withPeople = false,
  }) async {
    final requested = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final items = <TasteItem>[];
    for (var offset = 0; offset < requested.length; offset += idBatchSize) {
      final batch = requested.skip(offset).take(idBatchSize).toSet();
      final page = await _getItems(<String, String>{
        'ids': batch.join(','),
        'fields': withPeople ? '$_fields,People' : _fields,
        'enableUserData': 'true',
        'enableTotalRecordCount': 'false',
        'limit': '${batch.length}',
      });
      items.addAll(page.items.where((item) => batch.contains(item.id)));
    }
    return List<TasteItem>.unmodifiable(items);
  }

  @override
  Future<Set<String>> loadTitleIdsWithPerson(
    String personId,
    TasteRole role,
  ) async {
    final id = personId.trim();
    if (id.isEmpty) {
      return const <String>{};
    }
    final response = await _get(<String, String>{
      'personIds': id,
      'personTypes': role == TasteRole.director ? 'Director' : 'Actor',
      'includeItemTypes': _itemType,
      'recursive': 'true',
      'fields': '',
      'enableUserData': 'false',
      'enableTotalRecordCount': 'false',
      'limit': '$maxPersonMovies',
    });
    return Set<String>.unmodifiable(
      _rawItems(response)
          .where((item) => item['Type'] == _itemType)
          .map((item) => item['Id'])
          .whereType<String>()
          .where((value) => value.isNotEmpty),
    );
  }

  Future<_TastePage> _getItems(Map<String, String> query) async {
    final decoded = await _get(query);
    final raw = _rawItems(decoded);
    final total = decoded['TotalRecordCount'];
    return _TastePage(
      items: raw
          .map((item) => _parseItem(item, _itemType))
          .whereType<TasteItem>()
          .toList(growable: false),
      rawCount: raw.length,
      total: total is int && total >= 0 ? total : null,
    );
  }

  Future<Map<Object?, Object?>> _get(Map<String, String> query) async {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null || baseUrl.host.isEmpty) {
      throw const TasteFailure(TasteFailureReason.incompatible);
    }
    final uri = baseUrl.replace(
      pathSegments: <String>[
        ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        'Items',
      ],
      queryParameters: <String, String>{
        'userId': userId,
        'enableImages': 'false',
        ...query,
      },
      fragment: null,
    );
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['Authorization'] = MediaBrowserAuthorization.value(
        deviceId: deviceId,
        token: accessToken,
      );
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on HandshakeException {
      throw const TasteFailure(TasteFailureReason.unreachable);
    } on SocketException {
      throw const TasteFailure(TasteFailureReason.unreachable);
    } on TimeoutException {
      throw const TasteFailure(TasteFailureReason.unreachable);
    } on http.ClientException {
      throw const TasteFailure(TasteFailureReason.unreachable);
    }
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      throw const TasteFailure(TasteFailureReason.unauthorized);
    }
    if (status >= 500) {
      throw const TasteFailure(TasteFailureReason.server);
    }
    if (status < 200 || status >= 300) {
      throw const TasteFailure(TasteFailureReason.incompatible);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const TasteFailure(TasteFailureReason.incompatible);
    }
    if (decoded is! Map || decoded['Items'] is! List) {
      throw const TasteFailure(TasteFailureReason.incompatible);
    }
    return decoded;
  }

  static List<Map<Object?, Object?>> _rawItems(Map<Object?, Object?> body) {
    final items = body['Items'];
    return items is List
        ? items.whereType<Map<Object?, Object?>>().toList(growable: false)
        : const <Map<Object?, Object?>>[];
  }

  static TasteItem? _parseItem(Map<Object?, Object?> item, String type) {
    final id = item['Id'];
    final name = item['Name'];
    if (item['Type'] != type ||
        id is! String ||
        id.isEmpty ||
        name is! String) {
      return null;
    }
    final userData = item['UserData'];
    final data = userData is Map ? userData : const <Object?, Object?>{};
    final year = item['ProductionYear'];
    final playCount = data['PlayCount'];
    final rating = data['Rating'];
    final community = item['CommunityRating'];
    final likes = data['Likes'];
    final lastPlayed = data['LastPlayedDate'];
    return TasteItem(
      id: id,
      name: name,
      genres: _strings(item['Genres']),
      studios: _names(item['Studios']),
      tags: _strings(item['Tags']),
      people: _people(item['People']),
      year: year is int ? year : null,
      communityRating: community is num ? community.toDouble() : null,
      played: data['Played'] == true,
      playCount: playCount is int && playCount > 0 ? playCount : 0,
      favorite: data['IsFavorite'] == true,
      likes: likes is bool ? likes : null,
      rating: rating is num && rating.isFinite ? rating.toDouble() : null,
      lastPlayed: lastPlayed is String
          ? DateTime.tryParse(lastPlayed)?.toUtc()
          : null,
    );
  }

  static List<String> _strings(Object? value) => value is List
      ? value
            .whereType<String>()
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
      : const <String>[];

  static List<String> _names(Object? value) => value is List
      ? value
            .whereType<Map<Object?, Object?>>()
            .map((entry) => entry['Name'])
            .whereType<String>()
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
      : const <String>[];

  static List<TastePerson> _people(Object? value) {
    if (value is! List) {
      return const <TastePerson>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map(_person)
        .whereType<TastePerson>()
        .toList(growable: false);
  }

  static TastePerson? _person(Map<Object?, Object?> value) {
    final id = value['Id'];
    final name = value['Name'];
    final role = switch (value['Type']) {
      'Director' => TasteRole.director,
      'Actor' => TasteRole.actor,
      _ => null,
    };
    if (id is! String || id.isEmpty || name is! String || role == null) {
      return null;
    }
    return TastePerson(id: id, name: name, role: role);
  }
}

final class _TastePage {
  const _TastePage({
    required this.items,
    required this.rawCount,
    required this.total,
  });

  final List<TasteItem> items;
  final int rawCount;
  final int? total;
}
