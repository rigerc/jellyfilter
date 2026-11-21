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
import 'package:jellyfilter/features/discovery/domain/entities/shuffle_duration.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/discovery_store.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/repositories/taste_repository.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../shared/discovery_robot.dart';
import '../shared/fake_discovery_store.dart';
import '../shared/fake_taste_repository.dart';
import '../shared/recording_http_client.dart';

void main() {
  for (final mode in DiscoveryMode.values) {
    testWidgets(
      'should fill the whole catalog in ${mode.name} without interaction',
      (tester) async {
        final remaining = Completer<void>();
        final starts = <int>[];
        final client = RecordingHttpClient((request) async {
          final path = request.url.path;
          if (path == '/UserViews') {
            return _jsonResponse({'Items': <Object?>[]});
          }
          if (path == '/Items/Filters' || path == '/Items/Filters2') {
            return _jsonResponse(<String, Object?>{});
          }
          if (path == '/Items') {
            final query = request.url.queryParameters;
            final start = int.parse(query['startIndex']!);
            expect(query['limit'], '50');
            starts.add(start);
            if (start == 50) await remaining.future;
            final end = (start + 50).clamp(0, 125);
            return _jsonResponse({
              'Items': [for (var i = start; i < end; i++) _movie('movie-$i')],
              'StartIndex': start,
              'TotalRecordCount': 125,
            });
          }
          return http.Response('', 404);
        });
        final store = ImmediateDiscoveryStore()
          ..snapshot = DiscoverySnapshot(mode: mode);
        await tester.pumpWidget(_app(client, discoveryStore: store));
        await tester.pump();
        final cubit = tester
            .widget<DiscoveryPage>(find.byType(DiscoveryPage))
            .cubit;
        // The first page is interactive even while the next page is pending.
        expect(cubit.state.candidates, hasLength(50));
        expect(starts, [0, 50]);
        remaining.complete();
        await tester.pumpAndSettle();
        expect(starts, [0, 50, 100]);
        expect(cubit.state.candidates, hasLength(125));
        expect(cubit.state.candidates.last.id, 'movie-124');
        expect(find.text('125 titles'), findsOneWidget);
      },
    );
  }

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
      if (path == '/Items' &&
          request.url.queryParameters['genres'] == null &&
          request.url.queryParameters['isFavorite'] != 'true') {
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

  testWidgets(
    'should organize a loaded title without fetching its tags again',
    (tester) async {
      final client = RecordingHttpClient((request) async {
        final path = request.url.path;
        if (path == '/UserViews') return _jsonResponse({'Items': <Object?>[]});
        if (path == '/Items/Filters' || path == '/Items/Filters2') {
          return _jsonResponse(<String, Object?>{});
        }
        if (path == '/Items' &&
            request.url.queryParameters['includeItemTypes'] == 'Playlist') {
          return _jsonResponse({'Items': <Object?>[]});
        }
        if (path == '/Items') {
          return _jsonResponse({
            'Items': [
              {
                ..._movie('suggested'),
                'Tags': ['cozy'],
              },
            ],
            'TotalRecordCount': 1,
          });
        }
        return http.Response('', 404);
      });
      await tester.pumpWidget(_app(client));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('suggested')));
      await tester.pumpAndSettle();
      final before = client.requests.length;
      await tester.ensureVisible(
        find.byKey(WidgetKeys.discoveryOrganizeButton),
      );
      await tester.tap(find.byKey(WidgetKeys.discoveryOrganizeButton));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.discoveryOrganizer), findsOneWidget);
      final extra = client.requests.skip(before).toList();
      expect(extra, hasLength(1));
      expect(extra.single.url.queryParameters['includeItemTypes'], 'Playlist');
      await tester.tap(find.byKey(WidgetKeys.discoveryOrganizerTab(1)));
      await tester.pumpAndSettle();
      expect(find.text('cozy'), findsOneWidget);
    },
  );

  group('exhausted shuffle', exhaustedShuffleTests);
  group('optimistic favorites', optimisticFavoriteTests);
  group('favorite freshness', favoriteFreshnessTests);
  group('shortlist', shortlistTests);

  testWidgets('should keep the default catalog when switching to Shuffle', (
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
          'Items': <Map<String, Object?>>[_movie('suggested')],
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
      contains('/Items'),
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
        if (path == '/Items') {
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
    expect(request.url.queryParameters['sortBy'], 'CommunityRating,SortName');
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
      if (path == '/Items' &&
          request.url.queryParameters['isFavorite'] != 'true') {
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
  if (path == '/Items') {
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
        (request) => request.url.path == '/Items',
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
        .where((request) => request.url.path == '/Items')
        .toList();
    expect(batches, hasLength(1));
    expect(batches.single.url.queryParameters['excludeItemIds'], isNull);
    await DiscoveryRobot(tester).reveal();
    await tester.pumpAndSettle();
    DiscoveryRobot(tester).expectCandidateVisible('Fresh');
  });
}

void shortlistTests() {
  testWidgets(
    'pulls a movie down to shortlist it and leaves swipe decisions available',
    (tester) async {
      final store = _MemoryShortlistStore();
      final discovery = ImmediateDiscoveryStore()
        ..snapshot = const DiscoverySnapshot(mode: DiscoveryMode.swipe);
      await tester.pumpWidget(
        _app(
          _shortlistClient(),
          shortlistStore: store,
          discoveryStore: discovery,
        ),
      );
      await tester.pumpAndSettle();
      final card = find
          .byKey(WidgetKeys.discoveryCandidate('fresh'))
          .hitTestable();

      await tester.drag(card, const Offset(0, 48));
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);

      await tester.drag(card, const Offset(0, -170));
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);

      final pull = await tester.startGesture(tester.getCenter(card));
      await pull.moveBy(const Offset(0, 44));
      await pull.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(find.text('Pull down to shortlist'), findsOneWidget);
      await pull.moveBy(const Offset(28, 116));
      await tester.pump();
      expect(find.text('Release to shortlist'), findsOneWidget);
      expect(store.entries, isEmpty);
      await pull.up();
      await tester.pumpAndSettle();
      expect(store.entries, [(id: 'fresh', title: 'Fresh')]);
      expect(find.text('Added Fresh to your shortlist'), findsOneWidget);
      expect(find.text('Shortlist · 1 movie'), findsOneWidget);
      expect(card, findsOneWidget);
      expect(discovery.snapshot?.likedIds, isEmpty);
      expect(discovery.snapshot?.rejectedIds, isEmpty);

      await tester.drag(card, const Offset(0, 175));
      await tester.pumpAndSettle();
      expect(store.entries, [(id: 'fresh', title: 'Fresh')]);
      await tester.fling(card, const Offset(-90, 0), 2000);
      await tester.pumpAndSettle();
      expect(card, findsNothing);
      expect(discovery.snapshot?.rejectedIds, {'fresh'});
      expect(store.entries, [(id: 'fresh', title: 'Fresh')]);
    },
  );

  testWidgets('shows the shortlist above navigation and opens it in any mode', (
    tester,
  ) async {
    final store = _MemoryShortlistStore();
    var lookups = 0;
    final client = _shortlistClient(
      lookup: (ids) {
        lookups++;
        return lookups == 1
            ? http.Response('', 500)
            : _catalogItems(ids.split(','));
      },
    );
    final strip = find.byKey(WidgetKeys.discoveryViewShortlist);
    final navigation = find.byKey(WidgetKeys.discoveryModeNavigation);
    final sheet = find.byKey(WidgetKeys.discoveryShortlistSheet);
    final close = find.byKey(WidgetKeys.discoveryShortlistClose);
    final robot = DiscoveryRobot(tester);

    await tester.pumpWidget(_app(client, shortlistStore: store));
    await tester.pumpAndSettle();
    expect(strip, findsNothing);
    await tester.tap(
      find.byKey(WidgetKeys.discoveryShortlistBookmark('fresh')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shortlist · 1 movie'), findsOneWidget);
    await tester.tap(
      find.byKey(WidgetKeys.discoveryShortlistBookmark('suggested')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shortlist · 2 movies'), findsOneWidget);
    expect(find.text('Suggested, Fresh'), findsOneWidget);
    expect(
      tester.getBottomLeft(strip).dy,
      lessThan(tester.getTopLeft(navigation).dy),
    );

    await tester.tap(strip);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    expect(lookups, 1);
    expect(
      find.descendant(of: sheet, matching: find.text('Fresh')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(WidgetKeys.discoveryShortlistSheetRetry));
    await tester.pumpAndSettle();
    expect(lookups, 2);
    expect(find.byKey(WidgetKeys.discoveryShortlistSheetRetry), findsNothing);
    await tester.tap(close);
    await tester.pumpAndSettle();
    robot.expectGridVisible();

    await robot.openSwipe();
    await tester.tap(strip);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    robot.expectSwipeVisible();

    await robot.openShuffle();
    await tester.tap(strip);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.discoveryFavoriteBias), findsOneWidget);
    expect(strip, findsOneWidget);
  });

  group('For you', () {
    FakeTasteRepository taste() => FakeTasteRepository(
      history: <TasteItem>[
        TasteItem(id: 'seen', name: 'Seen', played: true, playCount: 1),
      ],
      items: <String, TasteItem>{
        'seen': TasteItem(
          id: 'seen',
          name: 'Seen',
          people: const <TastePerson>[
            TastePerson(
              id: 'd1',
              name: 'Agnès Varda',
              role: TasteRole.director,
            ),
          ],
        ),
      },
      personMovies: <String, Set<String>>{
        'd1': <String>{'liked'},
      },
    );

    testWidgets('should learn only once asked, then rank and explain picks', (
      tester,
    ) async {
      final repository = taste();
      await tester.pumpWidget(
        _app(
          _narrowingClient(<String>['fresh', 'suggested', 'liked']),
          tasteRepository: repository,
        ),
      );
      await tester.pumpAndSettle();
      final cubit = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .cubit;
      expect(repository.historyLoads, 0);

      await cubit.updateFilter(const CatalogFilter(sort: CatalogSort.forYou));
      await tester.pumpAndSettle();

      expect(repository.historyLoads, 1);
      expect(cubit.state.filteredCandidates.first.id, 'liked');
      await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('liked')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(WidgetKeys.discoveryRecommendationReason),
        findsOneWidget,
      );
      expect(find.text('Picked for you: Agnès Varda'), findsOneWidget);
    });

    testWidgets('should spin For you from the Shuffle source choice', (
      tester,
    ) async {
      final repository = taste();
      await tester.pumpWidget(
        _app(
          _narrowingClient(<String>['fresh', 'suggested', 'liked']),
          tasteRepository: repository,
          discoveryStore: ImmediateDiscoveryStore()
            ..snapshot = const DiscoverySnapshot(mode: DiscoveryMode.shuffle),
        ),
      );
      await tester.pumpAndSettle();
      final cubit = tester
          .widget<DiscoveryPage>(find.byType(DiscoveryPage))
          .cubit;
      expect(find.byKey(WidgetKeys.discoveryFavoriteBias), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.discoveryShuffleForYouSource));
      await tester.pumpAndSettle();

      expect(cubit.state.shuffleForYou, isTrue);
      expect(repository.historyLoads, 1);
      expect(cubit.state.affinity.rankedIds.first, 'liked');
      expect(find.byKey(WidgetKeys.discoveryFavoriteBias), findsNothing);

      await tester.tap(find.byKey(WidgetKeys.discoveryShuffleFilteredSource));
      await tester.pumpAndSettle();
      expect(cubit.state.shuffleForYou, isFalse);
    });
  });

  testWidgets(
    'spins only shortlisted movies without repeating on a compact screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final store = _MemoryShortlistStore([
        (id: 'fresh', title: 'Fresh'),
        (id: 'liked', title: 'Liked'),
      ]);
      final discovery = ImmediateDiscoveryStore()
        ..snapshot = const DiscoverySnapshot(
          filter: CatalogFilter(searchTerm: 'Suggested'),
          mode: DiscoveryMode.shuffle,
        );
      await tester.pumpWidget(
        _app(
          _shortlistClient(),
          shortlistStore: store,
          discoveryStore: discovery,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.discoveryShuffleShortlistSource));
      await tester.pumpAndSettle();
      expect(
        find.text('Drag here to pick from your shortlist.'),
        findsOneWidget,
      );

      final reel = find.byKey(WidgetKeys.discoveryShuffleReel);
      await tester.ensureVisible(reel);
      await tester.drag(reel, const Offset(100, 0));
      await tester.pump();
      final reelPosters = tester
          .widgetList<DiscoveryPoster>(find.byType(DiscoveryPoster))
          .map((poster) => poster.candidate.id);
      expect(reelPosters, isNotEmpty);
      expect(reelPosters, everyElement(isIn(['fresh', 'liked'])));
      await tester.pumpAndSettle();

      final fresh = find.byKey(WidgetKeys.discoveryShuffleCandidate('fresh'));
      final liked = find.byKey(WidgetKeys.discoveryShuffleCandidate('liked'));
      final firstWasFresh = fresh.evaluate().isNotEmpty;
      expect(firstWasFresh ? fresh : liked, findsOneWidget);
      final spin = find.byKey(WidgetKeys.discoveryRevealButton);
      await tester.ensureVisible(spin);
      await tester.tap(spin);
      await tester.pumpAndSettle();
      expect(firstWasFresh ? liked : fresh, findsOneWidget);
      expect(firstWasFresh ? fresh : liked, findsNothing);
    },
  );

  testWidgets(
    'bookmarks a movie from Grid and Details and restores it on restart',
    (tester) async {
      final store = _MemoryShortlistStore();
      final client = _shortlistClient();
      final bookmark = find.byKey(
        WidgetKeys.discoveryShortlistBookmark('fresh'),
      );

      await tester.pumpWidget(_app(client, shortlistStore: store));
      await tester.pumpAndSettle();
      await tester.tap(bookmark);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(bookmark).isSelected, isTrue);
      expect(store.entries, [(id: 'fresh', title: 'Fresh')]);

      await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('fresh')));
      await tester.pumpAndSettle();
      final detailBookmark = bookmark.hitTestable();
      expect(tester.widget<IconButton>(detailBookmark).isSelected, isTrue);
      await tester.tap(detailBookmark);
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
      await tester.tap(detailBookmark);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(client, shortlistStore: store));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(bookmark).isSelected, isTrue);
    },
  );

  testWidgets(
    'shuffles a movie outside the filters and restores the filtered pool',
    (tester) async {
      final store = _MemoryShortlistStore([(id: 'fresh', title: 'Fresh')]);
      final discovery = ImmediateDiscoveryStore()
        ..snapshot = const DiscoverySnapshot(
          filter: CatalogFilter(searchTerm: 'Suggested'),
          mode: DiscoveryMode.shuffle,
          rejectedIds: {'fresh'},
          favoriteBias: 1,
          shuffleDuration: ShuffleDuration.instant,
        );
      final client = _shortlistClient();

      await tester.pumpWidget(
        _app(client, shortlistStore: store, discoveryStore: discovery),
      );
      await tester.pumpAndSettle();
      final robot = DiscoveryRobot(tester);
      await robot.reveal();
      expect(
        find.byKey(WidgetKeys.discoveryShuffleCandidate('suggested')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(WidgetKeys.discoveryShuffleShortlistSource));
      await tester.pumpAndSettle();
      expect(
        find.byKey(WidgetKeys.discoveryShuffleCandidate('suggested')),
        findsNothing,
      );
      expect(find.text('Reveal movie'), findsOneWidget);
      await robot.reveal();
      expect(
        find.byKey(WidgetKeys.discoveryShuffleCandidate('fresh')),
        findsOneWidget,
      );
      expect(store.entries, [(id: 'fresh', title: 'Fresh')]);
      final lookup = client.requests.singleWhere(
        (request) => request.url.queryParameters['ids'] == 'fresh',
      );
      expect(lookup.url.queryParameters, isNot(contains('searchTerm')));

      await tester.tap(find.byKey(WidgetKeys.discoveryShuffleFilteredSource));
      await tester.pumpAndSettle();
      expect(
        find.byKey(WidgetKeys.discoveryShuffleCandidate('fresh')),
        findsNothing,
      );
      expect(discovery.snapshot?.filter.searchTerm, 'Suggested');
      await robot.reveal();
      expect(
        find.byKey(WidgetKeys.discoveryShuffleCandidate('suggested')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'retries lookup, manages an unavailable entry, and links an empty list to Grid',
    (tester) async {
      final store = _MemoryShortlistStore([
        (id: 'missing', title: 'Missing Movie'),
      ]);
      final discovery = ImmediateDiscoveryStore()
        ..snapshot = const DiscoverySnapshot(mode: DiscoveryMode.shuffle);
      var lookups = 0;
      final client = _shortlistClient(
        lookup: (_) {
          lookups++;
          return lookups == 1 ? http.Response('', 500) : _catalogItems([]);
        },
      );

      await tester.pumpWidget(
        _app(client, shortlistStore: store, discoveryStore: discovery),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.discoveryShuffleShortlistSource));
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t load your shortlist.'), findsOneWidget);
      await tester.tap(find.byKey(WidgetKeys.discoveryShortlistRetry));
      await tester.pumpAndSettle();
      expect(
        find.text('None of your saved movies are available.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(WidgetKeys.discoveryRevealButton))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(WidgetKeys.discoveryViewShortlist));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(WidgetKeys.discoveryShortlistSheet),
          matching: find.text('Missing Movie'),
        ),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(WidgetKeys.discoveryShortlistSheet)).height,
        lessThan(300),
      );
      final remove = find.byKey(WidgetKeys.discoveryShortlistRemove('missing'));
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
      await tester.tap(find.byKey(WidgetKeys.discoveryShortlistUndo));
      await tester.pumpAndSettle();
      expect(store.entries, [(id: 'missing', title: 'Missing Movie')]);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.discoveryShortlistClose));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.discoveryViewShortlist), findsNothing);
      expect(
        find.text('Bookmark movies to shuffle them here.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(WidgetKeys.discoveryShortlistBrowse));
      await tester.pumpAndSettle();
      DiscoveryRobot(tester).expectGridVisible();
    },
  );
}

RecordingHttpClient _shortlistClient({
  http.Response Function(String)? lookup,
}) => RecordingHttpClient((request) async {
  final query = request.url.queryParameters;
  final ids = query['ids'];
  return switch (request.url.path) {
    '/UserViews' => _jsonResponse({'Items': <Object?>[]}),
    '/Items/Filters' || '/Items/Filters2' => _jsonResponse(<String, Object?>{}),
    '/Items/fresh' => _jsonResponse(_movie('fresh')),
    '/Items' when ids != null =>
      lookup?.call(ids) ?? _catalogItems(ids.split(',')),
    '/Items' when query['searchTerm'] != null => _catalogItems(['suggested']),
    '/Items' => _catalogItems(['fresh', 'suggested']),
    _ => http.Response('', 404),
  };
});

http.Response _catalogItems(List<String> ids) => _jsonResponse({
  'Items': ids.map(_movie).toList(),
  'StartIndex': 0,
  'TotalRecordCount': ids.length,
});

final class _MemoryShortlistStore implements ShortlistStore {
  _MemoryShortlistStore([this.entries = const <ShortlistEntry>[]]);

  List<ShortlistEntry> entries;

  @override
  Future<List<ShortlistEntry>> read() async => entries;

  @override
  Future<void> write(List<ShortlistEntry> entries) async {
    this.entries = entries;
  }
}

Widget _app(
  http.Client client, {
  DiscoveryStore? discoveryStore,
  ShortlistStore? shortlistStore,
  TasteRepository? tasteRepository,
}) => MaterialApp(
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
    shortlistStore: shortlistStore ?? _MemoryShortlistStore(),
    tasteRepository: tasteRepository,
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
