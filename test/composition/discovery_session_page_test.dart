import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/composition/discovery_session_page.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_filter.dart';
import 'package:jellyfilter/features/connection/domain/entities/stored_session.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/discovery_store.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../shared/discovery_robot.dart';
import '../shared/fake_discovery_store.dart';
import '../shared/recording_http_client.dart';

void main() {
  testWidgets(
    'should retain the same filtered catalog and count across modes',
    (tester) async {
      final client = _narrowingClient(<String>['liked', 'fresh', 'rejected']);
      final store = ImmediateDiscoveryStore()
        ..snapshot = const DiscoverySnapshot(
          filter: CatalogFilter(genres: {'Drama'}, sort: CatalogSort.title),
          likedIds: {'liked'},
          rejectedIds: {'rejected'},
          recentPickIds: ['liked'],
        );
      await tester.pumpWidget(_app(client, discoveryStore: store));
      await tester.pumpAndSettle();
      final cubit = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .cubit;
      for (final mode in [
        DiscoveryMode.shuffle,
        DiscoveryMode.swipe,
        DiscoveryMode.grid,
        DiscoveryMode.shuffle,
      ]) {
        await cubit.setMode(mode);
        await tester.pumpAndSettle();
        expect(find.text('3 titles'), findsOneWidget);
        expect(cubit.state.filteredCandidates.map((c) => c.id), [
          'liked',
          'fresh',
          'rejected',
        ]);
      }
      final batches = client.requests
          .where(
            (r) =>
                r.url.path == '/Items' &&
                r.url.queryParameters['isFavorite'] != 'true',
          )
          .toList();
      expect(batches, hasLength(1));
      expect(batches.single.url.queryParameters['sortBy'], 'SortName');
      expect(batches.single.url.queryParameters['excludeItemIds'], isNull);
      expect(batches.single.url.queryParameters['ids'], isNull);
    },
  );

  testWidgets('should finish a filter reload while switching modes', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var loads = 0;
    final client = RecordingHttpClient((request) async {
      final path = request.url.path;
      if (path == '/UserViews') {
        return _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0});
      }
      if (path == '/Items/Filters' || path == '/Items/Filters2') {
        return _jsonResponse(<String, Object?>{});
      }
      if (path == '/Items/Suggestions') {
        return _jsonResponse({
          'Items': [_movie('suggested')],
          'TotalRecordCount': 1,
        });
      }
      if (path == '/Items') {
        if (request.url.queryParameters['isFavorite'] == 'true') {
          return _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0});
        }
        loads++;
        return pending.future;
      }
      return http.Response('', 404);
    });
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    final cubit = tester
        .widget<DiscoveryPage>(find.byType(DiscoveryPage))
        .cubit;
    await cubit.updateFilter(const CatalogFilter(genres: {'Drama'}));
    for (final mode in [
      DiscoveryMode.shuffle,
      DiscoveryMode.grid,
      DiscoveryMode.shuffle,
    ]) {
      await cubit.setMode(mode);
      await tester.pump();
    }
    pending.complete(
      _jsonResponse({
        'Items': [_movie('fresh')],
        'TotalRecordCount': 1,
      }),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);
    expect(cubit.state.candidates.single.id, 'fresh');
    expect(find.text('1 title'), findsOneWidget);
  });

  group('exhausted shuffle', exhaustedShuffleTests);
  group('optimistic favorites', optimisticFavoriteTests);
  group('favorite freshness', favoriteFreshnessTests);

  testWidgets('should keep suggestions when switching to Shuffle', (
    tester,
  ) async {
    final client = RecordingHttpClient((request) async {
      if (request.url.path == '/UserViews') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[],
          'TotalRecordCount': 0,
        });
      }
      if (request.url.path == '/Items/Filters' ||
          request.url.path == '/Items/Filters2') {
        return _jsonResponse(<String, Object?>{});
      }
      if (request.url.path == '/Items/Suggestions') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[_movie('suggested')],
          'StartIndex': 0,
          'TotalRecordCount': 1,
        });
      }
      if (request.url.path == '/Items') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[_movie('random')],
          'StartIndex': 0,
          'TotalRecordCount': 1,
        });
      }
      return http.Response('', 404);
    });
    final robot = DiscoveryRobot(tester);

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    robot.expectCandidateVisible('Suggested');
    expect(
      client.requests.map((request) => request.url.path),
      contains('/Items/Suggestions'),
    );

    await robot.openShuffle();
    await tester.pumpAndSettle();

    expect(
      client.requests.any(
        (request) =>
            request.url.path == '/Items' &&
            request.url.queryParameters['sortBy'] == 'Random',
      ),
      isFalse,
    );
  });

  testWidgets(
    'should append the next shared page when Shuffle has no eligible titles',
    (tester) async {
      final starts = <String>[];
      final client = RecordingHttpClient((request) async {
        final path = request.url.path;
        if (path == '/UserViews') {
          return _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0});
        }
        if (path == '/Items/Filters' || path == '/Items/Filters2') {
          return _jsonResponse(<String, Object?>{});
        }
        if (path == '/Items/Suggestions') {
          final start = request.url.queryParameters['startIndex'] ?? '0';
          starts.add(start);
          return _jsonResponse({
            'Items': [_movie(start == '0' ? 'rejected' : 'fresh')],
            'StartIndex': int.parse(start),
            'TotalRecordCount': 2,
          });
        }
        return http.Response('', 404);
      });
      final store = ImmediateDiscoveryStore()
        ..snapshot = const DiscoverySnapshot(
          mode: DiscoveryMode.shuffle,
          rejectedIds: {'rejected'},
        );
      await tester.pumpWidget(_app(client, discoveryStore: store));
      await tester.pumpAndSettle();
      expect(starts, ['0', '1']);
      expect(find.text('2 titles'), findsOneWidget);
      await DiscoveryRobot(tester).reveal();
      await tester.pumpAndSettle();
      DiscoveryRobot(tester).expectCandidateVisible('Fresh');
    },
  );

  testWidgets('should shuffle all filter matches despite two saved likes', (
    tester,
  ) async {
    final client = _narrowingClient(<String>['liked1', 'liked2', 'fresh']);
    final store = ImmediateDiscoveryStore()
      ..snapshot = const DiscoverySnapshot(
        mode: DiscoveryMode.shuffle,
        filter: CatalogFilter(
          genres: <String>{'Drama'},
          watched: false,
          maximumRuntimeMinutes: 90,
        ),
        likedIds: <String>{'liked1', 'liked2'},
      );

    await tester.pumpWidget(_app(client, discoveryStore: store));
    await tester.pumpAndSettle();

    final request = client.requests.singleWhere(
      (request) => request.url.path == '/Items',
    );
    expect(request.url.queryParameters, isNot(contains('ids')));
    expect(request.url.queryParameters['genres'], 'Drama');
    expect(request.url.queryParameters['isPlayed'], 'false');
    expect(request.url.queryParameters['sortBy'], 'CommunityRating');
    final cubit = tester
        .widget<DiscoveryPage>(find.byType(DiscoveryPage))
        .cubit;
    expect(
      cubit.state.eligibleCandidates.map((candidate) => candidate.id),
      <String>['liked1', 'liked2', 'fresh'],
    );
    expect(cubit.state.favoriteBias, 0);
    expect(cubit.state.likedIds, <String>{'liked1', 'liked2'});
  });

  testWidgets('should show no matches when an accessible filter returns none', (
    tester,
  ) async {
    final client = RecordingHttpClient((request) async {
      if (request.url.path == '/UserViews') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[
            <String, Object?>{
              'Id': 'movies-id',
              'Name': 'Movies',
              'CollectionType': 'movies',
            },
          ],
          'TotalRecordCount': 1,
        });
      }
      if (request.url.path == '/Items/Filters' ||
          request.url.path == '/Items/Filters2') {
        return _jsonResponse(<String, Object?>{});
      }
      if (request.url.path == '/Items') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[],
          'StartIndex': 0,
          'TotalRecordCount': 0,
        });
      }
      return http.Response('', 404);
    });
    final store = ImmediateDiscoveryStore()
      ..snapshot = const DiscoverySnapshot(
        filter: CatalogFilter(
          libraryId: 'movies-id',
          genres: <String>{'Documentary'},
        ),
      );
    final robot = DiscoveryRobot(tester);

    await tester.pumpWidget(_app(client, discoveryStore: store));
    await tester.pumpAndSettle();

    robot.expectNoMatchesVisible();
  });
}

void favoriteFreshnessTests() {
  testWidgets('should pick up favorites changed elsewhere when resumed', (
    tester,
  ) async {
    var serverFavorites = <String>[];
    final client = RecordingHttpClient((request) async {
      final path = request.url.path;
      if (path == '/UserViews') {
        return _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0});
      }
      if (path == '/Items/Filters' || path == '/Items/Filters2') {
        return _jsonResponse(<String, Object?>{});
      }
      if (path == '/Items/Suggestions') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[_movie('suggested')],
          'StartIndex': 0,
          'TotalRecordCount': 1,
        });
      }
      if (path == '/Items' &&
          request.url.queryParameters['isFavorite'] == 'true') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[
            for (final id in serverFavorites) <String, Object?>{'Id': id},
          ],
          'TotalRecordCount': serverFavorites.length,
        });
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    final heart = find.descendant(
      of: find.byKey(WidgetKeys.discoveryFavorite('suggested')),
      matching: find.byIcon(Icons.favorite_rounded),
    );
    expect(heart, findsNothing);

    // The movie is favorited in another Jellyfin app while we are away.
    serverFavorites = <String>['suggested'];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(heart, findsOneWidget);
    expect(
      client.requests.where(
        (request) => request.url.queryParameters['isFavorite'] == 'true',
      ),
      hasLength(1),
    );
  });
}

/// Serves one suggested movie; favorite writes wait on [gate] and answer
/// with [favoriteStatus].
RecordingHttpClient _favoriteClient({
  required List<Completer<void>> gates,
  int Function()? favoriteStatus,
}) => RecordingHttpClient((request) async {
  final path = request.url.path;
  if (path == '/UserViews') {
    return _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0});
  }
  if (path == '/Items/Filters' || path == '/Items/Filters2') {
    return _jsonResponse(<String, Object?>{});
  }
  if (path == '/Items/Suggestions') {
    return _jsonResponse({
      'Items': <Map<String, Object?>>[_movie('suggested')],
      'StartIndex': 0,
      'TotalRecordCount': 1,
    });
  }
  if (path == '/UserFavoriteItems/suggested') {
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    final status = favoriteStatus?.call() ?? 200;
    return status == 200
        ? _jsonResponse({'IsFavorite': request.method == 'POST'})
        : http.Response('', status);
  }
  return http.Response('', 404);
});

void optimisticFavoriteTests() {
  Finder filledHeart() => find.descendant(
    of: find.byKey(WidgetKeys.discoveryFavorite('suggested')),
    matching: find.byIcon(Icons.favorite_rounded),
  );

  testWidgets('should fill the heart before Jellyfin answers', (tester) async {
    final gates = <Completer<void>>[];
    await tester.pumpWidget(_app(_favoriteClient(gates: gates)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.discoveryFavorite('suggested')));
    await tester.pumpAndSettle();
    expect(gates, hasLength(1));
    expect(filledHeart(), findsOneWidget);

    gates.single.complete();
    await tester.pumpAndSettle();
    expect(filledHeart(), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('should roll the heart back and explain a failed update', (
    tester,
  ) async {
    final gates = <Completer<void>>[];
    await tester.pumpWidget(
      _app(_favoriteClient(gates: gates, favoriteStatus: () => 500)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(WidgetKeys.discoveryFavorite('suggested')));
    await tester.pumpAndSettle();
    expect(filledHeart(), findsOneWidget);

    gates.single.complete();
    await tester.pumpAndSettle();
    expect(filledHeart(), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('should settle a rapid double tap without a false error', (
    tester,
  ) async {
    final gates = <Completer<void>>[];
    final client = _favoriteClient(gates: gates);
    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    final heart = find.byKey(WidgetKeys.discoveryFavorite('suggested'));

    await tester.tap(heart);
    await tester.pump();
    await tester.tap(heart);
    await tester.pumpAndSettle();

    final writes = client.requests
        .where((request) => request.url.path == '/UserFavoriteItems/suggested')
        .map((request) => request.method)
        .toList();
    expect(writes, <String>['POST', 'DELETE']);
    expect(filledHeart(), findsNothing);

    for (final gate in gates) {
      gate.complete();
    }
    await tester.pumpAndSettle();
    expect(filledHeart(), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}

/// A server that honours `ids` and `excludeItemIds` like Jellyfin does.
RecordingHttpClient _narrowingClient(List<String> library) =>
    RecordingHttpClient((request) async {
      final path = request.url.path;
      if (path == '/UserViews') {
        return _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0});
      }
      if (path == '/Items/Filters' || path == '/Items/Filters2') {
        return _jsonResponse(<String, Object?>{});
      }
      if (path == '/Items' || path == '/Items/Suggestions') {
        final query = request.url.queryParameters;
        if (query['isFavorite'] == 'true') {
          return _jsonResponse({'Items': <Object?>[], 'TotalRecordCount': 0});
        }
        final included = query['ids']?.split(',').toSet();
        final excluded = query['excludeItemIds']?.split(',').toSet() ?? {};
        final items = library
            .where((id) => included == null || included.contains(id))
            .where((id) => !excluded.contains(id))
            .map(_movie)
            .toList();
        return _jsonResponse({
          'Items': items,
          'StartIndex': 0,
          'TotalRecordCount': items.length,
        });
      }
      return http.Response('', 404);
    });

void exhaustedShuffleTests() {
  testWidgets(
    'should offer fresh matches when liked titles were shown recently',
    (tester) async {
      final client = _narrowingClient(<String>['liked', 'fresh']);
      final store = ImmediateDiscoveryStore()
        ..snapshot = const DiscoverySnapshot(
          mode: DiscoveryMode.shuffle,
          likedIds: <String>{'liked'},
          recentPickIds: <String>['liked'],
          currentRevealId: 'liked',
        );

      await tester.pumpWidget(_app(client, discoveryStore: store));
      await tester.pumpAndSettle();

      expect(find.text('Your library is unavailable'), findsNothing);
      final request = client.requests.singleWhere(
        (request) => request.url.path == '/Items/Suggestions',
      );
      expect(request.url.queryParameters['ids'], isNull);
      expect(request.url.queryParameters['excludeItemIds'], isNull);
      await DiscoveryRobot(tester).reveal();
      await tester.pumpAndSettle();
      DiscoveryRobot(tester).expectCandidateVisible('Fresh');
    },
  );

  testWidgets('should start a fresh cycle when every title was shown', (
    tester,
  ) async {
    final client = _narrowingClient(<String>['fresh']);
    final store = ImmediateDiscoveryStore()
      ..snapshot = const DiscoverySnapshot(
        mode: DiscoveryMode.shuffle,
        recentPickIds: <String>['fresh'],
        rejectedIds: <String>{'rejected'},
      );

    await tester.pumpWidget(_app(client, discoveryStore: store));
    await tester.pumpAndSettle();

    expect(find.text('Your library is unavailable'), findsNothing);
    final batches = client.requests
        .where((request) => request.url.path == '/Items/Suggestions')
        .toList();
    expect(batches, hasLength(1));
    expect(batches.single.url.queryParameters['excludeItemIds'], isNull);
    await DiscoveryRobot(tester).reveal();
    await tester.pumpAndSettle();
    DiscoveryRobot(tester).expectCandidateVisible('Fresh');
  });
}

Widget _app(http.Client client, {DiscoveryStore? discoveryStore}) =>
    MaterialApp(
      theme: buildCandyTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiscoverySessionPage(
        session: const StoredSession(
          serverUrl: 'https://example.test',
          accessToken: 'token',
          userId: 'user-id',
          username: 'alice',
          deviceId: 'device-id',
        ),
        client: client,
        discoveryStore: discoveryStore ?? ImmediateDiscoveryStore(),
      ),
    );

Map<String, Object?> _movie(String id) => <String, Object?>{
  'Id': id,
  'Name': switch (id) {
    'suggested' => 'Suggested',
    'fresh' => 'Fresh',
    'liked' => 'Liked',
    _ => 'Random',
  },
  'Type': 'Movie',
  'ProductionYear': 2024,
  'RunTimeTicks': 36000000000,
  'Genres': <String>['Drama'],
  'UserData': <String, Object?>{'Played': false, 'IsFavorite': false},
};

http.Response _jsonResponse(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: <String, String>{'content-type': 'application/json'},
);
