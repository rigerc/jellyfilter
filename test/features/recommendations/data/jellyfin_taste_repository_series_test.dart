import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/recommendations/data/jellyfin_taste_repository.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';

import '../../../shared/recording_http_client.dart';

void main() {
  JellyfinTasteRepository repository(RecordingHttpClient client) =>
      JellyfinTasteRepository(
        client: client,
        serverUrl: 'https://example.test',
        accessToken: 'token',
        deviceId: 'device',
        userId: 'user-id',
        mediaType: CatalogMediaType.series,
      );

  Map<String, Object?> series(String id, {Map<String, Object?>? userData}) =>
      <String, Object?>{
        'Id': id,
        'Name': 'Show $id',
        'Type': 'Series',
        'Genres': <String>['Mystery'],
        'UserData': ?userData,
      };

  Map<String, Object?> episode(String seriesId, String playedAt) =>
      <String, Object?>{
        'Id': 'episode-$seriesId-$playedAt',
        'Type': 'Episode',
        'SeriesId': seriesId,
        'UserData': <String, Object?>{'LastPlayedDate': playedAt},
      };

  http.Response json(Object? body) => http.Response(
    jsonEncode(body),
    200,
    headers: <String, String>{'content-type': 'application/json'},
  );

  test('should learn from shows through their played episodes', () async {
    final client = RecordingHttpClient((request) async {
      final query = request.url.queryParameters;
      if (query['includeItemTypes'] == 'Episode') {
        final items = <Object?>[
          episode('harbor', '2026-11-02T00:00:00Z'),
          episode('harbor', '2026-11-05T00:00:00Z'),
          episode('harbor', '2026-11-03T00:00:00Z'),
          episode('diner', '2026-10-01T00:00:00Z'),
          <String, Object?>{'Id': 'stray', 'Type': 'Episode'},
        ];
        return json(<String, Object?>{
          'Items': items,
          'TotalRecordCount': items.length,
        });
      }
      if (query['ids'] != null) {
        return json(<String, Object?>{
          'Items': <Object?>[series('harbor'), series('diner')],
        });
      }
      if (query['filters'] == 'IsFavoriteOrLikes') {
        return json(<String, Object?>{
          'Items': <Object?>[
            series('loved', userData: <String, Object?>{'IsFavorite': true}),
          ],
          'TotalRecordCount': 1,
        });
      }
      return json(<String, Object?>{
        'Items': <Object?>[],
        'TotalRecordCount': 0,
      });
    });

    final history = await repository(client).loadHistory();

    final byId = <String, TasteItem>{for (final item in history) item.id: item};
    expect(byId.keys, unorderedEquals(<String>['harbor', 'diner', 'loved']));
    expect(byId['harbor']?.playCount, 3);
    expect(byId['harbor']?.lastPlayed, DateTime.utc(2026, 11, 5));
    // A started show is already known, so it is not recommended back.
    expect(byId['harbor']?.isSettled, isTrue);
    expect(byId['diner']?.playCount, 1);
    expect(byId['loved']?.favorite, isTrue);
    expect(byId['loved']?.isSettled, isFalse);
    final itemTypes = client.requests
        .map((request) => request.url.queryParameters['includeItemTypes'])
        .whereType<String>()
        .toSet();
    expect(itemTypes, <String>{'Episode', 'Series'});
    // Played series come from episodes, never from a played-series query.
    expect(
      client.requests.where(
        (request) =>
            request.url.queryParameters['includeItemTypes'] == 'Series' &&
            request.url.queryParameters['filters'] == 'IsPlayed',
      ),
      isEmpty,
    );
  });

  test('should look up series for a person', () async {
    final client = RecordingHttpClient(
      (request) async => json(<String, Object?>{
        'Items': <Object?>[
          series('harbor'),
          <String, Object?>{'Id': 'movie', 'Type': 'Movie'},
        ],
      }),
    );

    final ids = await repository(
      client,
    ).loadTitleIdsWithPerson('person-1', TasteRole.actor);

    expect(ids, <String>{'harbor'});
    expect(
      client.requests.single.url.queryParameters['includeItemTypes'],
      'Series',
    );
  });
}
