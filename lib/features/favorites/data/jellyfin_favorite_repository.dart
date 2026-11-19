import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jellyfilter/core/network/media_browser_authorization.dart';
import 'package:jellyfilter/features/favorites/domain/failures/favorite_failure.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';

final class JellyfinFavoriteRepository implements FavoriteRepository {
  const JellyfinFavoriteRepository({
    required this.client,
    required this.serverUrl,
    required this.accessToken,
    required this.deviceId,
    required this.userId,
    this.timeout = const Duration(seconds: 10),
  });

  final http.Client client;
  final String serverUrl;
  final String accessToken;
  final String deviceId;
  final String userId;
  final Duration timeout;

  @override
  Future<FavoriteUpdateResult> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) async {
    final normalizedItemId = itemId.trim();
    if (normalizedItemId.isEmpty) {
      return const FavoriteUpdateFailed(InvalidFavoriteRequestFailure());
    }
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null ||
        baseUrl.host.isEmpty ||
        (baseUrl.scheme != 'https' && baseUrl.scheme != 'http') ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.query.isNotEmpty ||
        baseUrl.fragment.isNotEmpty ||
        accessToken.isEmpty ||
        deviceId.isEmpty ||
        userId.isEmpty) {
      return const FavoriteUpdateFailed(InvalidFavoriteConfigurationFailure());
    }

    final request =
        http.Request(
            isFavorite ? 'POST' : 'DELETE',
            _favoriteUri(baseUrl, normalizedItemId),
          )
          ..followRedirects = false
          ..headers['Authorization'] = MediaBrowserAuthorization.value(
            deviceId: deviceId,
            token: accessToken,
          );

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(request).timeout(timeout),
      );
    } on HandshakeException {
      return const FavoriteUpdateFailed(InvalidCertificateFavoriteFailure());
    } on SocketException {
      return const FavoriteUpdateFailed(UnreachableFavoriteFailure());
    } on TimeoutException {
      return const FavoriteUpdateFailed(UnreachableFavoriteFailure());
    } on http.ClientException {
      return const FavoriteUpdateFailed(UnreachableFavoriteFailure());
    }

    return _resultFromResponse(
      response,
      itemId: normalizedItemId,
      requestedValue: isFavorite,
    );
  }

  Uri _favoriteUri(Uri baseUrl, String itemId) => baseUrl.replace(
    pathSegments: <String>[
      ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      'UserFavoriteItems',
      itemId,
    ],
    queryParameters: <String, String>{'userId': userId},
  );

  FavoriteUpdateResult _resultFromResponse(
    http.Response response, {
    required String itemId,
    required bool requestedValue,
  }) {
    if (response.statusCode == 401) {
      return const FavoriteUpdateFailed(ExpiredFavoriteSessionFailure());
    }
    if (response.statusCode == 403) {
      return const FavoriteUpdateFailed(UnauthorizedFavoriteFailure());
    }
    if (response.statusCode == 404) {
      return const FavoriteUpdateFailed(FavoriteItemNotFoundFailure());
    }
    if (response.statusCode >= 500) {
      return const FavoriteUpdateFailed(FavoriteServerFailure());
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      return const FavoriteUpdateFailed(UnsafeFavoriteRedirectFailure());
    }
    if (response.statusCode != 200) {
      return const FavoriteUpdateFailed(IncompatibleFavoriteResponseFailure());
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['IsFavorite'] is! bool) {
        return const FavoriteUpdateFailed(
          IncompatibleFavoriteResponseFailure(),
        );
      }
      final updatedValue = decoded['IsFavorite'] as bool;
      if (updatedValue != requestedValue) {
        return const FavoriteUpdateFailed(
          IncompatibleFavoriteResponseFailure(),
        );
      }
      return FavoriteUpdated(itemId: itemId, isFavorite: updatedValue);
    } on FormatException {
      return const FavoriteUpdateFailed(IncompatibleFavoriteResponseFailure());
    }
  }
}

/// Jellyfin playlists and item tags.
///
/// Tags have no dedicated endpoint: the full item is fetched fresh, only its
/// `Tags` field is changed, and the same document is posted back — the round
/// trip Jellyfin's own metadata editor performs. That requires an
/// administrator account.
final class JellyfinLibraryActionsRepository
    implements LibraryActionsRepository {
  JellyfinLibraryActionsRepository({
    required this.client,
    required this.serverUrl,
    required this.accessToken,
    required this.deviceId,
    required this.userId,
    this.timeout = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _clock = now ?? DateTime.now;

  final http.Client client;
  final String serverUrl;
  final String accessToken;
  final String deviceId;
  final String userId;
  final Duration timeout;

  static const _cacheLifetime = Duration(seconds: 30);
  static const _membershipPageSize = 500;
  final DateTime Function() _clock;
  ({List<LibraryPlaylist> items, DateTime fetchedAt})? _playlists;
  Future<LibraryActionResult<List<LibraryPlaylist>>>? _playlistRequest;
  int _playlistEpoch = 0;
  final _members = <String, ({Set<String> ids, DateTime fetchedAt})>{};
  final _playlistWrites = <String, Future<void>>{};

  bool _fresh(DateTime fetchedAt) =>
      _clock().difference(fetchedAt) < _cacheLifetime;

  @override
  Future<LibraryActionResult<List<LibraryPlaylist>>> loadPlaylists() async {
    final cached = _playlists;
    if (cached != null && _fresh(cached.fetchedAt)) {
      return LibraryActionResult.success(cached.items);
    }
    final pending = _playlistRequest;
    if (pending != null) return pending;
    final epoch = _playlistEpoch;
    final request = _playlistRequest = _fetchPlaylists();
    try {
      final result = await request;
      final items = result.value;
      if (items != null && epoch == _playlistEpoch) {
        _playlists = (items: items, fetchedAt: _clock());
      }
      return result;
    } finally {
      if (identical(_playlistRequest, request)) _playlistRequest = null;
    }
  }

  Future<LibraryActionResult<List<LibraryPlaylist>>> _fetchPlaylists() async {
    final response = await _send(
      'GET',
      <String>['Items'],
      <String, String>{
        'userId': userId,
        'includeItemTypes': 'Playlist',
        'recursive': 'true',
        'sortBy': 'SortName',
        'sortOrder': 'Ascending',
        'enableImages': 'false',
        'enableUserData': 'false',
        'fields': '',
        'enableTotalRecordCount': 'false',
      },
    );
    return _decode(response, (json) {
      final items = json is Map ? json['Items'] : null;
      if (items is! List) {
        return null;
      }
      return List<LibraryPlaylist>.unmodifiable(
        items
            .whereType<Map>()
            .where((item) => item['MediaType'] != 'Audio')
            .map(
              (item) => switch ((item['Id'], item['Name'])) {
                (final String id, final String name)
                    when id.isNotEmpty && name.isNotEmpty =>
                  LibraryPlaylist(id: id, name: name),
                _ => null,
              },
            )
            .whereType<LibraryPlaylist>(),
      );
    });
  }

  @override
  Future<LibraryActionResult<bool>> addToPlaylist({
    required String playlistId,
    required String itemId,
  }) async {
    // Serialize writes to a playlist so concurrent additions share the latest
    // membership and cannot both add the same title.
    final previous = _playlistWrites[playlistId];
    final done = Completer<void>();
    _playlistWrites[playlistId] = done.future;
    try {
      await previous;
      return await _addToPlaylist(playlistId: playlistId, itemId: itemId);
    } finally {
      done.complete();
      if (identical(_playlistWrites[playlistId], done.future)) {
        _playlistWrites.remove(playlistId);
      }
    }
  }

  Future<LibraryActionResult<bool>> _addToPlaylist({
    required String playlistId,
    required String itemId,
  }) async {
    final members = await _loadMembers(playlistId);
    final ids = members.value;
    if (ids == null) {
      return LibraryActionResult<bool>.failure(
        members.failure ?? LibraryActionFailure.incompatible,
      );
    }
    if (ids.contains(itemId)) {
      return const LibraryActionResult<bool>.success(false);
    }
    final added = await _send(
      'POST',
      <String>['Playlists', playlistId, 'Items'],
      <String, String>{'ids': itemId, 'userId': userId},
    );
    final result = _decode(added, (_) => true, allowEmpty: true);
    if (result.value == true) {
      ids.add(itemId);
    } else {
      // A failed response may still have committed on the server.
      _members.remove(playlistId);
    }
    return result;
  }

  Future<LibraryActionResult<Set<String>>> _loadMembers(
    String playlistId,
  ) async {
    final cached = _members[playlistId];
    if (cached != null && _fresh(cached.fetchedAt)) {
      return LibraryActionResult.success(cached.ids);
    }
    final result = await _fetchMembers(playlistId);
    if (result.value case final ids?) {
      _members[playlistId] = (ids: ids, fetchedAt: _clock());
    }
    return result;
  }

  Future<LibraryActionResult<Set<String>>> _fetchMembers(
    String playlistId,
  ) async {
    final ids = <String>{};
    var start = 0;
    String? previousFingerprint;
    while (true) {
      final response = await _send(
        'GET',
        <String>['Playlists', playlistId, 'Items'],
        <String, String>{
          'userId': userId,
          'enableImages': 'false',
          'enableUserData': 'false',
          'fields': '',
          'startIndex': '$start',
          'limit': '$_membershipPageSize',
        },
      );
      final decoded = _decode(response, (json) => json is Map ? json : null);
      final json = decoded.value;
      if (json == null) {
        return LibraryActionResult.failure(
          decoded.failure ?? LibraryActionFailure.incompatible,
        );
      }
      final items = json['Items'];
      if (items is! List) {
        return const LibraryActionResult.failure(
          LibraryActionFailure.incompatible,
        );
      }
      final pageIds = items
          .whereType<Map>()
          .map((item) => item['Id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      if (pageIds.length != items.length) {
        return const LibraryActionResult.failure(
          LibraryActionFailure.incompatible,
        );
      }
      final fingerprint = pageIds.join('|');
      if (items.isNotEmpty && fingerprint == previousFingerprint) {
        return const LibraryActionResult.failure(
          LibraryActionFailure.incompatible,
        );
      }
      previousFingerprint = fingerprint;
      ids.addAll(pageIds);
      start += items.length;
      final total = json['TotalRecordCount'];
      if (total is int ? start >= total : items.length < _membershipPageSize) {
        return LibraryActionResult.success(ids);
      }
      if (items.isEmpty) {
        return const LibraryActionResult.failure(
          LibraryActionFailure.incompatible,
        );
      }
    }
  }

  @override
  Future<LibraryActionResult<LibraryPlaylist>> createPlaylist({
    required String name,
    required String itemId,
  }) async {
    final trimmed = name.trim();
    final response = await _send(
      'POST',
      <String>['Playlists'],
      const <String, String>{},
      body: <String, Object?>{
        'Name': trimmed,
        'Ids': <String>[itemId],
        'UserId': userId,
        'MediaType': 'Video',
      },
    );
    final result = _decode(response, (json) {
      final id = json is Map ? json['Id'] : null;
      return id is String && id.isNotEmpty
          ? LibraryPlaylist(id: id, name: trimmed)
          : null;
    });
    if (result.value case final playlist?) {
      _playlistEpoch++;
      _playlistRequest = null;
      _playlists = null;
      _members[playlist.id] = (ids: <String>{itemId}, fetchedAt: _clock());
    }
    return result;
  }

  @override
  Future<LibraryActionResult<List<String>>> loadTags(String itemId) async {
    final response = await _send(
      'GET',
      <String>['Items'],
      <String, String>{
        'userId': userId,
        'ids': itemId,
        'fields': 'Tags',
        'enableImages': 'false',
        'enableUserData': 'false',
        'enableTotalRecordCount': 'false',
        'limit': '1',
      },
    );
    return _decode(response, (json) {
      final items = json is Map ? json['Items'] : null;
      final item = items is List ? items.whereType<Map>().firstOrNull : null;
      return item == null
          ? null
          : _tagsOf(
              item.map<String, Object?>(
                (key, value) => MapEntry('$key', value),
              ),
            );
    });
  }

  @override
  Future<LibraryActionResult<List<String>>> setTags({
    required String itemId,
    required List<String> tags,
  }) async {
    // Always edit a fresh copy so changes made elsewhere are not overwritten.
    final item = await _loadItem(itemId);
    final json = item.value;
    if (json == null) {
      return LibraryActionResult<List<String>>.failure(
        item.failure ?? LibraryActionFailure.incompatible,
      );
    }
    final normalized = _normalizeTags(tags);
    final updated = <String, Object?>{...json, 'Tags': normalized};
    final response = await _send(
      'POST',
      <String>['Items', itemId],
      const <String, String>{},
      body: updated,
    );
    return _decode(response, (_) => normalized, allowEmpty: true);
  }

  Future<LibraryActionResult<Map<String, Object?>>> _loadItem(
    String itemId,
  ) async {
    final response = await _send(
      'GET',
      <String>['Items', itemId],
      {'userId': userId},
    );
    return _decode(
      response,
      (json) => json is Map
          ? json.map<String, Object?>((key, value) => MapEntry('$key', value))
          : null,
    );
  }

  static List<String> _tagsOf(Map<String, Object?> json) {
    final tags = json['Tags'];
    return tags is List
        ? _normalizeTags(tags.whereType<String>())
        : const <String>[];
  }

  static List<String> _normalizeTags(Iterable<String> tags) {
    final seen = <String>{};
    return List<String>.unmodifiable(
      tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty && seen.add(tag.toLowerCase())),
    );
  }

  Future<_LibraryResponse> _send(
    String method,
    List<String> segments,
    Map<String, String> query, {
    Object? body,
  }) async {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null ||
        baseUrl.host.isEmpty ||
        segments.any((segment) => segment.trim().isEmpty)) {
      return const _LibraryResponse.failure(LibraryActionFailure.incompatible);
    }
    final uri = baseUrl.replace(
      pathSegments: <String>[
        ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        ...segments,
      ],
      queryParameters: query.isEmpty ? null : query,
    );
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Authorization'] = MediaBrowserAuthorization.value(
        deviceId: deviceId,
        token: accessToken,
      );
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    try {
      return _LibraryResponse(
        await http.Response.fromStream(
          await client.send(request).timeout(timeout),
        ),
      );
    } on HandshakeException {
      return const _LibraryResponse.failure(LibraryActionFailure.unreachable);
    } on SocketException {
      return const _LibraryResponse.failure(LibraryActionFailure.unreachable);
    } on TimeoutException {
      return const _LibraryResponse.failure(LibraryActionFailure.unreachable);
    } on http.ClientException {
      return const _LibraryResponse.failure(LibraryActionFailure.unreachable);
    }
  }

  LibraryActionResult<T> _decode<T>(
    _LibraryResponse result,
    T? Function(Object? json) parse, {
    bool allowEmpty = false,
  }) {
    final response = result.response;
    if (response == null) {
      return LibraryActionResult<T>.failure(
        result.failure ?? LibraryActionFailure.unreachable,
      );
    }
    final status = response.statusCode;
    final failure = switch (status) {
      401 => LibraryActionFailure.expiredSession,
      403 => LibraryActionFailure.notAllowed,
      404 => LibraryActionFailure.notFound,
      >= 500 => LibraryActionFailure.server,
      < 200 || >= 300 => LibraryActionFailure.incompatible,
      _ => null,
    };
    if (failure != null) {
      return LibraryActionResult<T>.failure(failure);
    }
    Object? json;
    if (response.body.trim().isNotEmpty) {
      try {
        json = jsonDecode(response.body);
      } on FormatException {
        if (!allowEmpty) {
          return const LibraryActionResult.failure(
            LibraryActionFailure.incompatible,
          );
        }
      }
    } else if (!allowEmpty) {
      return const LibraryActionResult.failure(
        LibraryActionFailure.incompatible,
      );
    }
    final value = parse(json);
    return value == null
        ? const LibraryActionResult.failure(LibraryActionFailure.incompatible)
        : LibraryActionResult<T>.success(value);
  }
}

final class _LibraryResponse {
  const _LibraryResponse(http.Response this.response) : failure = null;

  const _LibraryResponse.failure(LibraryActionFailure this.failure)
    : response = null;

  final http.Response? response;
  final LibraryActionFailure? failure;
}
