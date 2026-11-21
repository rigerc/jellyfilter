import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/features/catalog/data/jellyfin_catalog_repository.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_filter.dart';
import 'package:jellyfilter/features/catalog/domain/failures/catalog_failure.dart';

import '../../../shared/recording_http_client.dart';

void main() {
  JellyfinCatalogRepository repository(
    RecordingHttpClient client, {
    CatalogMediaType mediaType = CatalogMediaType.series,
  }) => JellyfinCatalogRepository(
    client: client,
    serverUrl: 'https://example.test',
    accessToken: 'token',
    deviceId: 'device',
    userId: 'user-id',
    mediaType: mediaType,
  );

  test('should ask Jellyfin for series with their season counts', () async {
    final client = RecordingHttpClient(
      (request) async => _json({
        'Items': [_series()],
        'StartIndex': 0,
        'TotalRecordCount': 1,
      }),
    );

    final page = await repository(
      client,
    ).loadPage(filter: const CatalogFilter(sort: CatalogSort.newEpisodes));

    final query = client.requests.single.url.queryParameters;
    expect(query['includeItemTypes'], 'Series');
    // A series is a folder, so asking for non-folders would hide them all.
    expect(query.containsKey('filters'), isFalse);
    expect(query['fields'], contains('ChildCount'));
    expect(query['fields'], contains('RecursiveItemCount'));
    expect(query['fields'], contains('DateLastMediaAdded'));
    expect(query['sortBy'], 'DateLastContentAdded,SortName');
    expect(query['sortOrder'], 'Descending,Ascending');
    final show = page.candidates.single;
    expect(show.mediaType, CatalogMediaType.series);
    expect(show.series?.seasonCount, 3);
    expect(show.series?.episodeCount, 26);
    expect(show.series?.unplayedEpisodeCount, 10);
    expect(show.series?.playedEpisodeCount, 16);
    expect(show.series?.isInProgress, isTrue);
    expect(show.series?.endYear, isNull);
    expect(show.series?.lastEpisodeAdded, DateTime.utc(2026, 11, 1));
  });

  test('should keep movies out of a series page and vice versa', () async {
    final client = RecordingHttpClient(
      (request) async => _json({
        'Items': [_series(), _movie()],
        'StartIndex': 0,
        'TotalRecordCount': 2,
      }),
    );

    final shows = await repository(client).loadPage();
    final movies = await repository(
      client,
      mediaType: CatalogMediaType.movie,
    ).loadPage();

    expect(shows.candidates.map((item) => item.id), ['series-1']);
    expect(movies.candidates.map((item) => item.id), ['movie-1']);
    expect(movies.candidates.single.series, isNull);
  });

  test('should read the end year only for ended series', () async {
    final client = RecordingHttpClient(
      (request) async => _json({
        'Items': [
          _series(
            id: 'ended',
            extra: {'Status': 'Ended', 'EndDate': '2018-05-01T00:00:00Z'},
          ),
          _series(
            id: 'running',
            extra: {'Status': 'Continuing', 'EndDate': '2018-05-01T00:00:00Z'},
          ),
        ],
        'StartIndex': 0,
        'TotalRecordCount': 2,
      }),
    );

    final page = await repository(client).loadPage();

    expect(page.candidates.first.series?.endYear, 2018);
    expect(page.candidates.last.series?.endYear, isNull);
  });

  test('should drop malformed series counts instead of guessing', () async {
    final client = RecordingHttpClient(
      (request) async => _json({
        'Items': [
          _series(
            extra: {
              'ChildCount': '3',
              'RecursiveItemCount': -1,
              'UserData': {
                'Played': false,
                'IsFavorite': false,
                'UnplayedItemCount': 2.5,
              },
            },
          ),
        ],
        'StartIndex': 0,
        'TotalRecordCount': 1,
      }),
    );

    final show = (await repository(client).loadPage()).candidates.single;

    expect(show.series?.seasonCount, isNull);
    expect(show.series?.episodeCount, isNull);
    expect(show.series?.unplayedEpisodeCount, isNull);
    expect(show.series?.progress, isNull);
    expect(show.series?.isInProgress, isFalse);
  });

  test('should offer only TV libraries for shows', () async {
    final client = RecordingHttpClient((request) async => _json(_views));

    final libraries = (await repository(client).loadLibraries()).value;

    expect(libraries?.map((library) => library.id), ['tv']);
  });

  test('should report which kinds of title the libraries hold', () async {
    final client = RecordingHttpClient((request) async => _json(_views));

    final kinds = await repository(client).loadAvailableMediaTypes();

    expect(kinds, {CatalogMediaType.movie, CatalogMediaType.series});
    expect(client.requests.single.url.path, '/UserViews');
  });

  test('should not guess library kinds when the server fails', () async {
    final client = RecordingHttpClient(
      (request) async => http.Response('', 500),
    );

    expect(await repository(client).loadAvailableMediaTypes(), isNull);
  });

  test('should read favorite series without the non-folder filter', () async {
    final client = RecordingHttpClient(
      (request) async => _json({
        'Items': [
          {'Id': 'series-1'},
        ],
        'TotalRecordCount': 1,
      }),
    );

    final ids = await repository(client).loadFavoriteIds();

    final query = client.requests.single.url.queryParameters;
    expect(ids.value, {'series-1'});
    expect(query['includeItemTypes'], 'Series');
    expect(query.containsKey('filters'), isFalse);
  });

  test('should load seasons with progress and the next episode', () async {
    final client = RecordingHttpClient((request) async {
      if (request.url.path == '/Shows/series-1/Seasons') {
        return _json({
          'Items': [
            {
              'Id': 'season-1',
              'Name': 'Season 1',
              'Type': 'Season',
              'IndexNumber': 1,
              'RecursiveItemCount': 10,
              'UserData': {'UnplayedItemCount': 0},
            },
            {
              'Id': 'season-2',
              'Name': 'Season 2',
              'Type': 'Season',
              'IndexNumber': 2,
              'ChildCount': 8,
              'UserData': {'UnplayedItemCount': 4},
            },
            {'Id': 'broken', 'Type': 'Season'},
          ],
        });
      }
      if (request.url.path == '/Shows/NextUp') {
        expect(request.url.queryParameters['seriesId'], 'series-1');
        return _json({
          'Items': [
            {
              'Id': 'episode-5',
              'Name': 'The Long Tide',
              'Type': 'Episode',
              'ParentIndexNumber': 2,
              'IndexNumber': 5,
              'RunTimeTicks': 28800000000,
            },
          ],
        });
      }
      return http.Response('', 404);
    });

    final progress = (await repository(
      client,
    ).loadSeriesProgress('series-1')).value;

    expect(progress?.seasons.map((season) => season.id), [
      'season-1',
      'season-2',
    ]);
    expect(progress?.seasons.first.playedEpisodeCount, 10);
    expect(progress?.seasons.last.episodeCount, 8);
    expect(progress?.seasons.last.playedEpisodeCount, 4);
    final nextUp = progress?.nextUp;
    expect(nextUp?.name, 'The Long Tide');
    expect(nextUp?.seasonNumber, 2);
    expect(nextUp?.episodeNumber, 5);
    expect(nextUp?.runtimeMinutes, 48);
  });

  test('should keep seasons when next up fails', () async {
    final client = RecordingHttpClient((request) async {
      if (request.url.path.endsWith('/Seasons')) {
        return _json({
          'Items': [
            {'Id': 'season-1', 'Name': 'Season 1', 'Type': 'Season'},
          ],
        });
      }
      return http.Response('', 500);
    });

    final progress = (await repository(
      client,
    ).loadSeriesProgress('series-1')).value;

    expect(progress?.seasons, hasLength(1));
    expect(progress?.nextUp, isNull);
  });

  test('should fail series progress when seasons cannot load', () async {
    final client = RecordingHttpClient(
      (request) async => http.Response('', 401),
    );

    final result = await repository(client).loadSeriesProgress('series-1');

    expect(result.value, isNull);
    expect(result.failure, isA<ExpiredCatalogFailure>());
  });
}

const _views = <String, Object?>{
  'Items': [
    {'Id': 'films', 'Name': 'Films', 'CollectionType': 'movies'},
    {'Id': 'tv', 'Name': 'TV', 'CollectionType': 'tvshows'},
    {'Id': 'music', 'Name': 'Music', 'CollectionType': 'music'},
  ],
};

Map<String, Object?> _series({
  String id = 'series-1',
  Map<String, Object?> extra = const <String, Object?>{},
}) => <String, Object?>{
  'Id': id,
  'Name': 'Harbor Lights',
  'Type': 'Series',
  'ProductionYear': 2019,
  'Status': 'Continuing',
  'ChildCount': 3,
  'RecursiveItemCount': 26,
  'DateLastMediaAdded': '2026-11-01T00:00:00Z',
  'ImageTags': <String, String>{'Primary': 'primary'},
  'BackdropImageTags': <String>['backdrop'],
  'UserData': <String, Object?>{
    'Played': false,
    'IsFavorite': false,
    'UnplayedItemCount': 10,
  },
  ...extra,
};

Map<String, Object?> _movie() => <String, Object?>{
  'Id': 'movie-1',
  'Name': 'Candy Movie',
  'Type': 'Movie',
  'ProductionYear': 2024,
  'ImageTags': <String, String>{'Primary': 'primary'},
  'BackdropImageTags': <String>['backdrop'],
  'UserData': <String, Object?>{'Played': false, 'IsFavorite': false},
};

http.Response _json(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: <String, String>{'content-type': 'application/json'},
);
