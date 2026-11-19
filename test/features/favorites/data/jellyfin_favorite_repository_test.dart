import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/features/favorites/data/jellyfin_favorite_repository.dart';
import 'package:jellyfilter/features/favorites/domain/failures/favorite_failure.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';

import '../../../shared/recording_http_client.dart';

void main() {
  group('library actions', libraryActionTests);

  group('JellyfinFavoriteRepository', () {
    test('should mark only the requested item as favorite', () async {
      final client = RecordingHttpClient(
        (request) async => _userData(isFavorite: true),
      );
      final repository = _repository(
        client,
        serverUrl: 'https://host/jellyfin/',
      );

      final result = await repository.setFavorite(
        itemId: 'movie id',
        isFavorite: true,
      );
      final request = client.requests.single;

      expect(result, isA<FavoriteUpdated>());
      expect((result as FavoriteUpdated).isFavorite, isTrue);
      expect(request.method, 'POST');
      expect(request.url.path, '/jellyfin/UserFavoriteItems/movie%20id');
      expect(request.url.queryParameters, <String, String>{
        'userId': 'user-id',
      });
      expect(request.followRedirects, isFalse);
      expect(request.headers['authorization'], contains('Token="token"'));
      expect(request.url.toString(), isNot(contains('UserPlayedItems')));
    });

    test('should unmark only the requested item as favorite', () async {
      final client = RecordingHttpClient(
        (request) async => _userData(isFavorite: false),
      );
      final repository = _repository(client);

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: false,
      );
      final request = client.requests.single;

      expect(result, isA<FavoriteUpdated>());
      expect((result as FavoriteUpdated).isFavorite, isFalse);
      expect(request.method, 'DELETE');
      expect(request.url.path, '/UserFavoriteItems/movie-id');
      expect(request.url.toString(), isNot(contains('UserPlayedItems')));
    });

    test('should reject an empty item id without sending a request', () async {
      final client = RecordingHttpClient(
        (request) async => _userData(isFavorite: true),
      );
      final repository = _repository(client);

      final result = await repository.setFavorite(
        itemId: '   ',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<InvalidFavoriteRequestFailure>(),
      );
      expect(client.requests, isEmpty);
    });

    for (final scenario in <({int status, FavoriteFailure expected})>[
      (status: 401, expected: const ExpiredFavoriteSessionFailure()),
      (status: 403, expected: const UnauthorizedFavoriteFailure()),
      (status: 404, expected: const FavoriteItemNotFoundFailure()),
      (status: 503, expected: const FavoriteServerFailure()),
      (status: 302, expected: const UnsafeFavoriteRedirectFailure()),
      (status: 418, expected: const IncompatibleFavoriteResponseFailure()),
    ]) {
      test('should map HTTP ${scenario.status} to a typed failure', () async {
        final repository = _repository(
          RecordingHttpClient(
            (request) async => http.Response('', scenario.status),
          ),
        );

        final result = await repository.setFavorite(
          itemId: 'movie-id',
          isFavorite: true,
        );

        expect(
          (result as FavoriteUpdateFailed).failure.runtimeType,
          scenario.expected.runtimeType,
        );
      });
    }

    test('should reject malformed success data', () async {
      final repository = _repository(
        RecordingHttpClient(
          (request) async => http.Response(
            jsonEncode(<String, Object?>{'IsFavorite': 'yes'}),
            200,
          ),
        ),
      );

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<IncompatibleFavoriteResponseFailure>(),
      );
    });

    test(
      'should reject a success value that contradicts the request',
      () async {
        final repository = _repository(
          RecordingHttpClient((request) async => _userData(isFavorite: false)),
        );

        final result = await repository.setFavorite(
          itemId: 'movie-id',
          isFavorite: true,
        );

        expect(
          (result as FavoriteUpdateFailed).failure,
          isA<IncompatibleFavoriteResponseFailure>(),
        );
      },
    );

    test('should classify invalid TLS without bypassing it', () async {
      final repository = _repository(
        RecordingHttpClient(
          (request) async => throw const HandshakeException('untrusted'),
        ),
      );

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<InvalidCertificateFavoriteFailure>(),
      );
    });

    test('should classify socket failures as unreachable', () async {
      final repository = _repository(
        RecordingHttpClient(
          (request) async => throw const SocketException('offline'),
        ),
      );

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<UnreachableFavoriteFailure>(),
      );
    });

    test('should classify timeouts as unreachable', () async {
      final repository = _repository(
        RecordingHttpClient((request) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 1),
      );

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<UnreachableFavoriteFailure>(),
      );
    });

    test('should reject an invalid server URL without a request', () async {
      final client = RecordingHttpClient(
        (request) async => _userData(isFavorite: true),
      );
      final repository = _repository(client, serverUrl: 'not a url');

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<InvalidFavoriteConfigurationFailure>(),
      );
      expect(client.requests, isEmpty);
    });

    test('should reject server URLs containing credentials', () async {
      final client = RecordingHttpClient(
        (request) async => _userData(isFavorite: true),
      );
      final repository = _repository(
        client,
        serverUrl: 'https://name:password@host',
      );

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<InvalidFavoriteConfigurationFailure>(),
      );
      expect(client.requests, isEmpty);
    });

    test('should reject missing authentication configuration', () async {
      final client = RecordingHttpClient(
        (request) async => _userData(isFavorite: true),
      );
      final repository = _repository(client, accessToken: '');

      final result = await repository.setFavorite(
        itemId: 'movie-id',
        isFavorite: true,
      );

      expect(
        (result as FavoriteUpdateFailed).failure,
        isA<InvalidFavoriteConfigurationFailure>(),
      );
      expect(client.requests, isEmpty);
    });
  });
}

JellyfinFavoriteRepository _repository(
  http.Client client, {
  String serverUrl = 'https://host',
  String accessToken = 'token',
  Duration timeout = const Duration(seconds: 1),
}) => JellyfinFavoriteRepository(
  client: client,
  serverUrl: serverUrl,
  accessToken: accessToken,
  deviceId: 'device-id',
  userId: 'user-id',
  timeout: timeout,
);

http.Response _userData({required bool isFavorite}) => http.Response(
  jsonEncode(<String, Object?>{
    'ItemId': 'movie-id',
    'IsFavorite': isFavorite,
    'Played': true,
  }),
  200,
  headers: <String, String>{'content-type': 'application/json'},
);

JellyfinLibraryActionsRepository _actions(RecordingHttpClient client) =>
    JellyfinLibraryActionsRepository(
      client: client,
      serverUrl: 'https://example.test/jellyfin',
      accessToken: 'token',
      deviceId: 'device',
      userId: 'user-id',
    );

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: <String, String>{'content-type': 'application/json'},
);

void libraryActionTests() {
  test('should list video playlists and skip music ones', () async {
    final client = RecordingHttpClient(
      (request) async => _json(<String, Object?>{
        'Items': <Object?>[
          <String, Object?>{
            'Id': 'p1',
            'Name': 'Movie night',
            'MediaType': 'Video',
          },
          <String, Object?>{
            'Id': 'p2',
            'Name': 'Road trip',
            'MediaType': 'Audio',
          },
          <String, Object?>{'Id': 'p3', 'Name': 'Untyped'},
        ],
      }),
    );

    final result = await _actions(client).loadPlaylists();

    expect(result.value, const <LibraryPlaylist>[
      LibraryPlaylist(id: 'p1', name: 'Movie night'),
      LibraryPlaylist(id: 'p3', name: 'Untyped'),
    ]);
    final query = client.requests.single.url.queryParameters;
    expect(client.requests.single.url.path, '/jellyfin/Items');
    expect(query['includeItemTypes'], 'Playlist');
    expect(query['userId'], 'user-id');
  });

  test('should add a title once and report when it is already there', () async {
    var members = <String>['other'];
    final client = RecordingHttpClient((request) async {
      if (request.method == 'GET') {
        return _json(<String, Object?>{
          'Items': <Object?>[
            for (final id in members) <String, Object?>{'Id': id},
          ],
        });
      }
      members = <String>[...members, request.url.queryParameters['ids']!];
      return http.Response('', 204);
    });
    final actions = _actions(client);

    final first = await actions.addToPlaylist(
      playlistId: 'p1',
      itemId: 'movie',
    );
    final second = await actions.addToPlaylist(
      playlistId: 'p1',
      itemId: 'movie',
    );

    expect(first.value, isTrue);
    expect(second.value, isFalse);
    final posts = client.requests.where((request) => request.method == 'POST');
    expect(posts, hasLength(1));
    expect(posts.single.url.path, '/jellyfin/Playlists/p1/Items');
    expect(posts.single.url.queryParameters['ids'], 'movie');
  });

  test('should create a video playlist that starts with the title', () async {
    final client = RecordingHttpClient(
      (request) async => _json(<String, Object?>{'Id': 'new-id'}),
    );

    final result = await _actions(
      client,
    ).createPlaylist(name: '  Cozy picks ', itemId: 'movie');

    expect(
      result.value,
      const LibraryPlaylist(id: 'new-id', name: 'Cozy picks'),
    );
    expect(client.requests.single.url.path, '/jellyfin/Playlists');
    expect(jsonDecode(client.bodies.single!), <String, Object?>{
      'Name': 'Cozy picks',
      'Ids': <String>['movie'],
      'UserId': 'user-id',
      'MediaType': 'Video',
    });
  });

  test('should change only the tags when saving an item back', () async {
    final item = <String, Object?>{
      'Id': 'movie',
      'Name': 'Harbor Lights',
      'Overview': 'Keep me.',
      'ProviderIds': <String, Object?>{'Tmdb': '42'},
      'LockedFields': <String>['Overview'],
      'Tags': <String>['old'],
    };
    final client = RecordingHttpClient((request) async {
      return request.method == 'GET' ? _json(item) : http.Response('', 204);
    });

    final result = await _actions(
      client,
    ).setTags(itemId: 'movie', tags: <String>[' cozy ', 'Cozy', 'rainy day']);

    expect(result.value, <String>['cozy', 'rainy day']);
    final post = client.requests.last;
    expect(post.method, 'POST');
    expect(post.url.path, '/jellyfin/Items/movie');
    expect(post.headers['Content-Type'], contains('application/json'));
    final sent = jsonDecode(client.bodies.last!) as Map<String, Object?>;
    expect(sent, <String, Object?>{
      ...item,
      'Tags': <String>['cozy', 'rainy day'],
    });
  });

  test('should report a non-admin tag edit as not allowed', () async {
    final client = RecordingHttpClient((request) async {
      return request.method == 'GET'
          ? _json(<String, Object?>{'Id': 'movie', 'Tags': <String>[]})
          : http.Response('', 403);
    });

    final result = await _actions(
      client,
    ).setTags(itemId: 'movie', tags: <String>['cozy']);

    expect(result.value, isNull);
    expect(result.failure, LibraryActionFailure.notAllowed);
  });
}
