import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/features/recommendations/data/jellyfin_taste_repository.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/failures/taste_failure.dart';

import '../../../shared/recording_http_client.dart';

void main() {
  JellyfinTasteRepository repository(RecordingHttpClient client) =>
      JellyfinTasteRepository(
        client: client,
        serverUrl: 'https://example.test/jellyfin',
        accessToken: 'token',
        deviceId: 'device',
        userId: 'user-id',
      );

  Map<String, Object?> movie(String id, {Map<String, Object?>? extra}) =>
      <String, Object?>{
        'Id': id,
        'Name': 'Movie $id',
        'Type': 'Movie',
        'Genres': <Object?>['Drama', 7, ' '],
        'Tags': <Object?>['slow burn'],
        'Studios': <Object?>[
          <String, Object?>{'Name': 'A24'},
        ],
        'ProductionYear': 2015,
        'CommunityRating': 7.5,
        ...?extra,
      };

  http.Response json(Object? body) => http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );

  test('should read each kind of interaction without images', () async {
    final client = RecordingHttpClient((request) async {
      final filter = request.url.queryParameters['filters'];
      final items = <Object?>[
        if (filter == 'IsPlayed')
          movie(
            'played',
            extra: <String, Object?>{
              'UserData': <String, Object?>{
                'Played': true,
                'PlayCount': 2,
                'LastPlayedDate': '2026-11-01T10:00:00Z',
                'Rating': 8,
              },
            },
          ),
        if (filter == 'IsFavoriteOrLikes') ...<Object?>[
          movie('played'),
          movie(
            'liked',
            extra: <String, Object?>{
              'UserData': <String, Object?>{'Likes': true},
            },
          ),
        ],
        if (filter == 'Dislikes') <String, Object?>{'Id': 'series'},
      ];
      return json(<String, Object?>{
        'Items': items,
        'TotalRecordCount': items.length,
      });
    });

    final history = await repository(client).loadHistory();

    expect(client.requests.map((r) => r.url.queryParameters['filters']), [
      'IsPlayed',
      'IsFavoriteOrLikes',
      'Dislikes',
    ]);
    final query = client.requests.first.url.queryParameters;
    expect(client.requests.first.url.path, '/jellyfin/Items');
    expect(query['enableImages'], 'false');
    expect(query['fields'], 'Genres,Tags,Studios');
    expect(query['sortBy'], 'DatePlayed');
    expect(client.requests.first.headers['Authorization'], contains('token'));
    expect(history.map((item) => item.id), <String>['played', 'liked']);
    final played = history.first;
    expect(played.genres, <String>['Drama']);
    expect(played.studios, <String>['A24']);
    expect(played.tags, <String>['slow burn']);
    expect(played.year, 2015);
    expect(played.played, isTrue);
    expect(played.playCount, 2);
    expect(played.rating, 8);
    expect(played.lastPlayed, DateTime.utc(2026, 11, 1, 10));
    expect(history.last.likes, isTrue);
  });

  test('should page through a long history', () async {
    final client = RecordingHttpClient((request) async {
      final query = request.url.queryParameters;
      final start = int.parse(query['startIndex'] ?? '0');
      final played = query['filters'] == 'IsPlayed';
      return json(<String, Object?>{
        'Items': played
            ? <Object?>[
                for (var i = start; i < start + 200 && i < 250; i++)
                  movie('m$i'),
              ]
            : <Object?>[],
        'TotalRecordCount': played ? 250 : 0,
      });
    });

    final history = await repository(client).loadHistory();

    expect(history, hasLength(250));
    expect(
      client.requests
          .where((r) => r.url.queryParameters['filters'] == 'IsPlayed')
          .map((r) => r.url.queryParameters['startIndex']),
      <String>['0', '200'],
    );
  });

  test('should read people in billing order for named movies', () async {
    final client = RecordingHttpClient(
      (request) async => json(<String, Object?>{
        'Items': <Object?>[
          movie(
            'a',
            extra: <String, Object?>{
              'People': <Object?>[
                <String, Object?>{'Id': 'p1', 'Name': 'Lead', 'Type': 'Actor'},
                <String, Object?>{
                  'Id': 'p2',
                  'Name': 'Writer',
                  'Type': 'Writer',
                },
                <String, Object?>{'Name': 'No id', 'Type': 'Actor'},
                <String, Object?>{
                  'Id': 'p3',
                  'Name': 'Boss',
                  'Type': 'Director',
                },
              ],
            },
          ),
          movie('not-requested'),
        ],
      }),
    );

    final items = await repository(
      client,
    ).loadItems(<String>{'a', ' '}, withPeople: true);

    final query = client.requests.single.url.queryParameters;
    expect(query['ids'], 'a');
    expect(query['fields'], 'Genres,Tags,Studios,People');
    expect(items.single.people, const <TastePerson>[
      TastePerson(id: 'p1', name: 'Lead', role: TasteRole.actor),
      TastePerson(id: 'p3', name: 'Boss', role: TasteRole.director),
    ]);
  });

  test('should batch long id lists', () async {
    final client = RecordingHttpClient(
      (request) async => json(<String, Object?>{'Items': <Object?>[]}),
    );

    await repository(
      client,
    ).loadItems(<String>{for (var i = 0; i < 120; i++) 'id$i'});

    expect(
      client.requests.map(
        (r) => r.url.queryParameters['ids']?.split(',').length,
      ),
      <int>[50, 50, 20],
    );
  });

  test('should find a person’s movies with a lean request', () async {
    final client = RecordingHttpClient(
      (request) async => json(<String, Object?>{
        'Items': <Object?>[
          <String, Object?>{'Id': 'm1', 'Type': 'Movie'},
          <String, Object?>{'Id': 'e1', 'Type': 'Episode'},
        ],
      }),
    );

    final ids = await repository(
      client,
    ).loadTitleIdsWithPerson('p1', TasteRole.director);

    final query = client.requests.single.url.queryParameters;
    expect(query['personIds'], 'p1');
    expect(query['personTypes'], 'Director');
    expect(query['fields'], '');
    expect(query['enableUserData'], 'false');
    expect(ids, <String>{'m1'});
  });

  test('should type failures', () async {
    Future<TasteFailureReason?> reasonFor(
      Future<http.Response> Function() respond,
    ) async {
      try {
        await repository(
          RecordingHttpClient((_) => respond()),
        ).loadTitleIdsWithPerson('p1', TasteRole.actor);
      } on TasteFailure catch (failure) {
        return failure.reason;
      }
      return null;
    }

    expect(
      await reasonFor(() async => http.Response('', 401)),
      TasteFailureReason.unauthorized,
    );
    expect(
      await reasonFor(() async => http.Response('', 503)),
      TasteFailureReason.server,
    );
    expect(
      await reasonFor(() async => http.Response('not json', 200)),
      TasteFailureReason.incompatible,
    );
    expect(
      await reasonFor(() async => throw const SocketException('offline')),
      TasteFailureReason.unreachable,
    );
  });
}
