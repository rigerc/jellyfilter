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
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../shared/discovery_robot.dart';
import '../shared/fake_discovery_store.dart';
import '../shared/recording_http_client.dart';

void main() {
  group('exhausted shuffle', exhaustedShuffleTests);
  group('optimistic favorites', optimisticFavoriteTests);
  group('favorite freshness', favoriteFreshnessTests);

  testWidgets(
    'should use suggestions initially and a random Jellyfin batch in shuffle',
    (tester) async {
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
        isTrue,
      );
    },
  );

  testWidgets('should refill an exhausted random batch with exclusions', (
    tester,
  ) async {
    var randomRequests = 0;
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
      if (request.url.path == '/Items') {
        randomRequests++;
        final id = randomRequests == 1 ? 'rejected' : 'fresh';
        return _jsonResponse({
          'Items': <Map<String, Object?>>[_movie(id)],
          'StartIndex': 0,
          'TotalRecordCount': 1,
        });
      }
      return http.Response('', 404);
    });
    final store = ImmediateDiscoveryStore()
      ..snapshot = const DiscoverySnapshot(
        mode: DiscoveryMode.shuffle,
        rejectedIds: <String>{'rejected'},
      );
    final robot = DiscoveryRobot(tester);

    await tester.pumpWidget(_app(client, discoveryStore: store));
    await tester.pumpAndSettle();
    await robot.reveal();
    await tester.pumpAndSettle();

    final randomCalls = client.requests
        .where((request) => request.url.path == '/Items')
        .toList(growable: false);
    expect(randomCalls, hasLength(2));
    expect(
      randomCalls.last.url.queryParameters['excludeItemIds'],
      contains('rejected'),
    );

    await robot.reveal();
    await tester.pumpAndSettle();
    robot.expectCandidateVisible('Fresh');
  });

  testWidgets('should restore a bounded local shortlist in shuffle', (
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
      if (request.url.path == '/Items') {
        return _jsonResponse({
          'Items': <Map<String, Object?>>[_movie('liked')],
          'StartIndex': 0,
          'TotalRecordCount': 1,
        });
      }
      return http.Response('', 404);
    });
    final store = ImmediateDiscoveryStore()
      ..snapshot = const DiscoverySnapshot(
        mode: DiscoveryMode.shuffle,
        likedIds: <String>{'liked'},
      );
    final robot = DiscoveryRobot(tester);

    await tester.pumpWidget(_app(client, discoveryStore: store));
    await tester.pumpAndSettle();

    final request = client.requests.singleWhere(
      (request) => request.url.path == '/Items',
    );
    expect(request.url.queryParameters['ids'], 'liked');
    expect(request.url.queryParameters, isNot(contains('excludeItemIds')));

    await robot.reveal();
    await tester.pumpAndSettle();
    robot.expectCandidateVisible('Liked');
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
      if (path == '/Items') {
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
    'should open Shuffle after every liked title was shown recently',
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
      DiscoveryRobot(tester).expectCandidateVisible('Liked');
      final shortlistRequest = client.requests.firstWhere(
        (request) => request.url.queryParameters['ids'] != null,
      );
      expect(shortlistRequest.url.queryParameters['excludeItemIds'], isNull);
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
        .where(
          (request) =>
              request.url.path == '/Items' &&
              request.url.queryParameters['sortBy'] == 'Random',
        )
        .toList();
    expect(batches, hasLength(2));
    expect(batches.last.url.queryParameters['excludeItemIds'], 'rejected');
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
