// Renders the website screenshots from the real app widgets with a sample
// library. Run through tool/website_screenshots.sh, not the test suite.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jellyfilter/composition/discovery_session_page.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/connection/domain/entities/stored_session.dart';
import 'package:jellyfilter/features/discovery/domain/entities/browse_layout.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../../test/shared/fake_discovery_store.dart';

const _posterDir = String.fromEnvironment('POSTER_DIR');
const _outDir = String.fromEnvironment('OUT_DIR');
const _fontDir = String.fromEnvironment('FONT_DIR');

/// Phone-sized canvas: 400 × 768 logical pixels at 2×.
const _logicalSize = Size(400, 768);
const _pixelRatio = 2.0;

typedef _Movie = ({
  String id,
  String name,
  int year,
  int minutes,
  List<String> genres,
  double community,
  int critic,
  bool favorite,
  bool played,
});

const _movies = <_Movie>[
  (
    id: 'general',
    name: 'The General',
    year: 1926,
    minutes: 78,
    genres: ['Action', 'Adventure', 'Comedy'],
    community: 8.1,
    critic: 89,
    favorite: false,
    played: false,
  ),
  (
    id: 'goldrush',
    name: 'The Gold Rush',
    year: 1925,
    minutes: 95,
    genres: ['Adventure', 'Comedy', 'Drama'],
    community: 8.1,
    critic: 100,
    favorite: true,
    played: true,
  ),
  (
    id: 'phantom',
    name: 'The Phantom of the Opera',
    year: 1925,
    minutes: 93,
    genres: ['Drama', 'Horror'],
    community: 7.5,
    critic: 90,
    favorite: false,
    played: false,
  ),
  (
    id: 'lostworld',
    name: 'The Lost World',
    year: 1925,
    minutes: 104,
    genres: ['Adventure', 'Fantasy', 'Science Fiction'],
    community: 6.9,
    critic: 83,
    favorite: false,
    played: false,
  ),
  (
    id: 'safetylast',
    name: 'Safety Last!',
    year: 1923,
    minutes: 74,
    genres: ['Comedy', 'Thriller'],
    community: 8.1,
    critic: 97,
    favorite: true,
    played: false,
  ),
  (
    id: 'sherlockjr',
    name: 'Sherlock Jr.',
    year: 1924,
    minutes: 45,
    genres: ['Action', 'Comedy', 'Romance'],
    community: 8.2,
    critic: 93,
    favorite: false,
    played: true,
  ),
];

typedef _Scene = ({String name, DiscoverySnapshot snapshot});

const _scenes = <_Scene>[
  (name: 'browse', snapshot: DiscoverySnapshot()),
  (
    name: 'browse-list',
    snapshot: DiscoverySnapshot(browseLayout: BrowseLayout.list),
  ),
  (name: 'swipe', snapshot: DiscoverySnapshot(mode: DiscoveryMode.swipe)),
  (
    name: 'shuffle',
    snapshot: DiscoverySnapshot(
      mode: DiscoveryMode.shuffle,
      currentRevealId: 'phantom',
    ),
  ),
];

void main() {
  setUpAll(_loadFonts);

  for (final scene in _scenes) {
    testWidgets('capture ${scene.name}', (tester) async {
      if (_posterDir.isEmpty || _outDir.isEmpty || _fontDir.isEmpty) {
        fail('Run through tool/website_screenshots.sh.');
      }
      HttpOverrides.global = _PosterHttpOverrides(Directory(_posterDir));
      tester.view.physicalSize = _logicalSize * _pixelRatio;
      tester.view.devicePixelRatio = _pixelRatio;
      addTearDown(tester.view.reset);

      final store = ImmediateDiscoveryStore()..snapshot = scene.snapshot;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildCandyDarkTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiscoverySessionPage(
            session: const StoredSession(
              serverUrl: 'https://jellyfin.example',
              accessToken: 'token',
              userId: 'user',
              username: 'sample',
              deviceId: 'device',
            ),
            client: MockClient(_catalog),
            discoveryStore: store,
            shortlistStore: _ShortlistStore(),
          ),
        ),
      );
      await _settleWithImages(tester);

      final bytes = await tester.runAsync(() async {
        final image = await captureImage(
          find.byType(MaterialApp).evaluate().single,
        );
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      });
      File('$_outDir/${scene.name}.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
    });
  }
}

/// Lets the catalog arrive, then gives real time to fetch and decode
/// posters, which fake test time never does.
Future<void> _settleWithImages(WidgetTester tester) async {
  for (var round = 0; round < 6; round++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  await tester.pumpAndSettle();
}

/// Text uses Roboto, as on Android when the brand fonts are not bundled.
Future<void> _loadFonts() async {
  Future<ByteData> font(String file) async =>
      ByteData.sublistView(await File('$_fontDir/$file').readAsBytes());
  const weights = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Black.ttf',
  ];
  for (final family in [
    'Roboto',
    CandyTypography.display,
    CandyTypography.body,
  ]) {
    final loader = FontLoader(family);
    for (final file in weights) {
      loader.addFont(font(file));
    }
    await loader.load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(font('MaterialIcons-Regular.otf'))).load();
}

Future<http.Response> _catalog(http.Request request) async {
  final path = request.url.path;
  final query = request.url.queryParameters;
  if (path == '/UserViews') {
    return _json({'Items': <Object?>[]});
  }
  if (path.startsWith('/Items/Filters')) {
    return _json(<String, Object?>{});
  }
  if (path == '/Items') {
    final favoritesOnly = query['isFavorite'] == 'true';
    final items = [
      for (final movie in _movies)
        if (!favoritesOnly || movie.favorite) _item(movie),
    ];
    return _json({
      'Items': items,
      'StartIndex': 0,
      'TotalRecordCount': items.length,
    });
  }
  return http.Response('', 404);
}

Map<String, Object?> _item(_Movie movie) => <String, Object?>{
  'Id': movie.id,
  'Name': movie.name,
  'Type': 'Movie',
  'ProductionYear': movie.year,
  'RunTimeTicks': movie.minutes * 60 * 10000000,
  'Genres': movie.genres,
  'CommunityRating': movie.community,
  'CriticRating': movie.critic,
  'OfficialRating': 'NR',
  'PrimaryImageAspectRatio': 0.68,
  'ImageTags': {'Primary': 'poster-${movie.id}'},
  'UserData': {'Played': movie.played, 'IsFavorite': movie.favorite},
};

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

final class _ShortlistStore implements ShortlistStore {
  List<ShortlistEntry> _entries = const [
    (id: 'goldrush', title: 'The Gold Rush'),
    (id: 'sherlockjr', title: 'Sherlock Jr.'),
  ];

  @override
  Future<List<ShortlistEntry>> read() async => _entries;

  @override
  Future<void> write(List<ShortlistEntry> entries) async => _entries = entries;
}

/// Serves `/Items/<id>/Images/Primary` from `<POSTER_DIR>/<id>.img`.
final class _PosterHttpOverrides extends HttpOverrides {
  _PosterHttpOverrides(this.directory);

  final Directory directory;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _PosterClient(directory);
}

final class _PosterClient implements HttpClient {
  _PosterClient(this.directory);

  final Directory directory;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    final segments = url.pathSegments;
    final index = segments.indexOf('Items');
    final file = index >= 0 && index + 1 < segments.length
        ? File('${directory.path}/${segments[index + 1]}.img')
        : null;
    final bytes = file != null && file.existsSync()
        ? file.readAsBytesSync()
        : null;
    return _PosterRequest(bytes);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PosterRequest implements HttpClientRequest {
  _PosterRequest(this.bytes);

  final List<int>? bytes;

  @override
  final HttpHeaders headers = _NoHeaders();

  @override
  Future<HttpClientResponse> close() async => _PosterResponse(bytes);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _NoHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PosterResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _PosterResponse(this.bytes);

  final List<int>? bytes;

  @override
  int get statusCode => bytes == null ? HttpStatus.notFound : HttpStatus.ok;

  @override
  int get contentLength => bytes?.length ?? 0;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([?bytes]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
