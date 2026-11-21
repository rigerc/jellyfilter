import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/composition/discovery_session_page.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/connection/domain/entities/stored_session.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../shared/fake_discovery_store.dart';
import '../shared/recording_http_client.dart';

void main() {
  testWidgets('should hide the switch when the server only has movies', (
    tester,
  ) async {
    final client = _server(libraries: <String>['movies']);

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.discoveryMediaTypeToggle), findsNothing);
    expect(find.text('Jellyfilter'), findsOneWidget);
    expect(find.text('Candy Movie'), findsOneWidget);
  });

  testWidgets('should switch to shows, keep the tab, and keep filters apart', (
    tester,
  ) async {
    final client = _server(libraries: <String>['movies', 'tvshows']);
    final store = ImmediateDiscoveryStore()
      ..snapshot = const DiscoverySnapshot(
        mode: DiscoveryMode.swipe,
        filter: CatalogFilter(genres: <String>{'drama'}),
      );

    await tester.pumpWidget(_app(client, store: store));
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.discoveryMediaTypeToggle), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);

    await tester.tap(find.byKey(WidgetKeys.discoveryMediaTypeToggle));
    await tester.pumpAndSettle();

    final cubit = tester
        .widget<DiscoveryPage>(find.byType(DiscoveryPage))
        .cubit;
    expect(cubit.mediaType, CatalogMediaType.series);
    expect(cubit.state.mode, DiscoveryMode.swipe);
    expect(cubit.state.filter.genres, isEmpty);
    expect(cubit.state.candidates.map((item) => item.id), ['series-1']);
    expect(find.text('Shows'), findsOneWidget);
    expect(store.mediaType, CatalogMediaType.series);
    expect(store.snapshot?.filter.genres, <String>{'drama'});
    expect(store.others.keys.single, endsWith('|series'));

    await tester.tap(find.byKey(WidgetKeys.discoveryMediaTypeToggle));
    await tester.pumpAndSettle();

    final movies = tester
        .widget<DiscoveryPage>(find.byType(DiscoveryPage))
        .cubit;
    expect(movies.mediaType, CatalogMediaType.movie);
    expect(movies.state.filter.genres, <String>{'drama'});
    expect(store.mediaType, CatalogMediaType.movie);
    // Each catalog loads once; switching back reuses what is loaded.
    expect(_itemRequests(client, 'Movie'), 1);
    expect(_itemRequests(client, 'Series'), 1);
  });

  testWidgets('should reopen on shows without loading movies', (tester) async {
    final client = _server(libraries: <String>['movies', 'tvshows']);
    final store = ImmediateDiscoveryStore()
      ..mediaType = CatalogMediaType.series;

    await tester.pumpWidget(_app(client, store: store));
    await tester.pumpAndSettle();

    final cubit = tester
        .widget<DiscoveryPage>(find.byType(DiscoveryPage))
        .cubit;
    expect(cubit.mediaType, CatalogMediaType.series);
    expect(find.text('Shows'), findsOneWidget);
    expect(_itemRequests(client, 'Movie'), 0);
  });

  testWidgets('should open on shows when the server only has TV', (
    tester,
  ) async {
    final client = _server(libraries: <String>['tvshows']);
    final store = ImmediateDiscoveryStore();

    await tester.pumpWidget(_app(client, store: store));
    await tester.pumpAndSettle();

    final cubit = tester
        .widget<DiscoveryPage>(find.byType(DiscoveryPage))
        .cubit;
    expect(cubit.mediaType, CatalogMediaType.series);
    expect(find.byKey(WidgetKeys.discoveryMediaTypeToggle), findsNothing);
    expect(store.mediaType, CatalogMediaType.series);
  });

  testWidgets('should switch without animating when motion is reduced', (
    tester,
  ) async {
    final client = _server(libraries: <String>['movies', 'tvshows']);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(client),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryMediaTypeToggle));
    await tester.pump();
    await tester.pump();

    // The movie page leaves at once instead of fading out.
    expect(find.byType(DiscoveryPage), findsOneWidget);
    await tester.pumpAndSettle();
  });
}

int _itemRequests(RecordingHttpClient client, String type) => client.requests
    .where(
      (request) =>
          request.url.path == '/Items' &&
          request.url.queryParameters['includeItemTypes'] == type &&
          request.url.queryParameters['isFavorite'] != 'true',
    )
    .length;

RecordingHttpClient _server({
  required List<String> libraries,
}) => RecordingHttpClient((request) async {
  final path = request.url.path;
  if (path == '/UserViews') {
    return _json(<String, Object?>{
      'Items': <Object?>[
        for (final type in libraries)
          <String, Object?>{'Id': type, 'Name': type, 'CollectionType': type},
      ],
    });
  }
  if (path == '/Items/Filters' || path == '/Items/Filters2') {
    return _json(<String, Object?>{});
  }
  if (path == '/Items') {
    final series = request.url.queryParameters['includeItemTypes'] == 'Series';
    return _json(<String, Object?>{
      'Items': <Object?>[series ? _series : _movie],
      'StartIndex': 0,
      'TotalRecordCount': 1,
    });
  }
  return http.Response('', 404);
});

const _movie = <String, Object?>{
  'Id': 'movie-1',
  'Name': 'Candy Movie',
  'Type': 'Movie',
  'ProductionYear': 2024,
  'Genres': <String>['Drama'],
  'UserData': <String, Object?>{'Played': false, 'IsFavorite': false},
};

const _series = <String, Object?>{
  'Id': 'series-1',
  'Name': 'Harbor Lights',
  'Type': 'Series',
  'ProductionYear': 2019,
  'Status': 'Continuing',
  'ChildCount': 3,
  'RecursiveItemCount': 26,
  'UserData': <String, Object?>{
    'Played': false,
    'IsFavorite': false,
    'UnplayedItemCount': 10,
  },
};

final class _MemoryShortlistStore implements ShortlistStore {
  List<ShortlistEntry> entries = <ShortlistEntry>[];

  @override
  Future<List<ShortlistEntry>> read() async => entries;

  @override
  Future<void> write(List<ShortlistEntry> value) async => entries = value;
}

Widget _app(http.Client client, {ImmediateDiscoveryStore? store}) =>
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
        discoveryStore: store ?? ImmediateDiscoveryStore(),
        shortlistStore: _MemoryShortlistStore(),
        seriesShortlistStore: _MemoryShortlistStore(),
      ),
    );

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: <String, String>{'content-type': 'application/json'},
);
