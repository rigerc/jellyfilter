// Sample library and capture helpers shared by the website screenshot and
// video renders. Not part of the test suite.
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
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/connection/domain/entities/stored_session.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../../test/shared/fake_discovery_store.dart';

const posterDir = String.fromEnvironment('POSTER_DIR');
const outDir = String.fromEnvironment('OUT_DIR');
const fontDir = String.fromEnvironment('FONT_DIR');

/// Phone-sized canvas: 400 × 768 logical pixels at 2×.
const logicalSize = Size(400, 768);
const pixelRatio = 2.0;

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

typedef _Show = ({
  String id,
  String name,
  int year,
  int endYear,
  List<int> seasons,
  int watched,
  int minutes,
  List<String> genres,
  double community,
  bool favorite,
  ({String name, int season, int episode})? nextUp,
  String overview,
});

/// Real season and episode counts; the user's progress is invented.
const _shows = <_Show>[
  (
    id: 'startrek',
    name: 'Star Trek',
    year: 1966,
    endYear: 1969,
    seasons: [29, 26, 24],
    watched: 32,
    minutes: 50,
    genres: ['Sci-Fi & Fantasy', 'Action & Adventure'],
    community: 8.4,
    favorite: true,
    nextUp: (name: 'Mirror, Mirror', season: 2, episode: 4),
    overview:
        'The crew of the starship Enterprise explores the galaxy on a five-year mission.',
  ),
  (
    id: 'twilight',
    name: 'The Twilight Zone',
    year: 1959,
    endYear: 1964,
    seasons: [36, 29, 37, 18, 36],
    watched: 36,
    minutes: 25,
    genres: ['Sci-Fi & Fantasy', 'Mystery', 'Drama'],
    community: 8.9,
    favorite: false,
    nextUp: (name: 'King Nine Will Not Return', season: 2, episode: 1),
    overview:
        'Rod Serling hosts an anthology of eerie, twist-ending tales of the strange and the uncanny.',
  ),
  (
    id: 'addams',
    name: 'The Addams Family',
    year: 1964,
    endYear: 1966,
    seasons: [34, 30],
    watched: 0,
    minutes: 25,
    genres: ['Comedy', 'Family'],
    community: 8.0,
    favorite: false,
    nextUp: null,
    overview:
        'A wealthy, ghoulish family lives happily by its own macabre rules.',
  ),
  (
    id: 'lucy',
    name: 'I Love Lucy',
    year: 1951,
    endYear: 1957,
    seasons: [35, 31, 31, 30, 26, 27],
    watched: 180,
    minutes: 25,
    genres: ['Comedy'],
    community: 8.5,
    favorite: true,
    nextUp: null,
    overview:
        "Lucy Ricardo schemes to break into show business, much to her bandleader husband's dismay.",
  ),
  (
    id: 'munsters',
    name: 'The Munsters',
    year: 1964,
    endYear: 1966,
    seasons: [38, 32],
    watched: 0,
    minutes: 25,
    genres: ['Comedy', 'Family', 'Sci-Fi & Fantasy'],
    community: 7.5,
    favorite: false,
    nextUp: null,
    overview:
        'A family of friendly monsters tries to fit in on a suburban street.',
  ),
  (
    id: 'griffith',
    name: 'The Andy Griffith Show',
    year: 1960,
    endYear: 1968,
    seasons: [32, 31, 32, 32, 32, 30, 30, 30],
    watched: 0,
    minutes: 25,
    genres: ['Comedy', 'Family'],
    community: 8.0,
    favorite: false,
    nextUp: null,
    overview:
        'Sheriff Andy Taylor keeps the peace in the small town of Mayberry.',
  ),
  (
    id: 'dragnet',
    name: 'Dragnet',
    year: 1951,
    endYear: 1959,
    seasons: [35, 35, 35, 35, 34, 34, 34, 34],
    watched: 0,
    minutes: 30,
    genres: ['Crime', 'Drama'],
    community: 7.6,
    favorite: false,
    nextUp: null,
    overview:
        'Sergeant Joe Friday works cases with the Los Angeles police, just the facts.',
  ),
];

/// Every title with artwork, for warming the image cache.
List<String> get samplePosterIds => <String>[
  for (final movie in _movies) movie.id,
  for (final show in _shows) show.id,
];

/// Lets the catalog arrive, then gives real time to fetch and decode
/// posters, which fake test time never does.
Future<void> settleWithImages(WidgetTester tester) async {
  for (var round = 0; round < 6; round++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
  }
  await tester.pumpAndSettle();
}

/// Text uses Roboto, as on Android when the brand fonts are not bundled.
Future<void> loadFonts() async {
  Future<ByteData> font(String file) async =>
      ByteData.sublistView(await File('$fontDir/$file').readAsBytes());
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
    return _json({
      'Items': [
        {'Id': 'movies', 'Name': 'Movies', 'CollectionType': 'movies'},
        {'Id': 'shows', 'Name': 'Shows', 'CollectionType': 'tvshows'},
      ],
    });
  }
  if (path.startsWith('/Shows/')) {
    return _json({'Items': _episodes(path, query)});
  }
  if (path.startsWith('/Items/Filters')) {
    return _json(<String, Object?>{});
  }
  if (path == '/Items') {
    final favoritesOnly = query['isFavorite'] == 'true';
    final items = query['includeItemTypes'] == 'Series'
        ? [
            for (final show in _shows)
              if (!favoritesOnly || show.favorite) _series(show),
          ]
        : [
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

int _total(_Show show) => show.seasons.fold(0, (sum, count) => sum + count);

Map<String, Object?> _series(_Show show) => <String, Object?>{
  'Id': show.id,
  'Name': show.name,
  'Type': 'Series',
  'ProductionYear': show.year,
  'EndDate': '${show.endYear}-06-01T00:00:00Z',
  'Status': 'Ended',
  'ChildCount': show.seasons.length,
  'RecursiveItemCount': _total(show),
  'RunTimeTicks': show.minutes * 60 * 10000000,
  'Genres': show.genres,
  'CommunityRating': show.community,
  'OfficialRating': 'TV-PG',
  'Overview': show.overview,
  'PrimaryImageAspectRatio': 0.68,
  'ImageTags': {'Primary': 'poster-${show.id}'},
  'UserData': {
    'Played': show.watched == _total(show),
    'IsFavorite': show.favorite,
    'UnplayedItemCount': _total(show) - show.watched,
  },
};

/// Seasons from `/Shows/<id>/Seasons`, or next up from `/Shows/NextUp`.
List<Object?> _episodes(String path, Map<String, String> query) {
  final segments = path.split('/');
  final id = segments.length > 2 && segments[2] != 'NextUp'
      ? segments[2]
      : query['seriesId'];
  final show = _shows.where((show) => show.id == id).firstOrNull;
  if (show == null) {
    return const <Object?>[];
  }
  if (segments.last == 'NextUp') {
    final next = show.nextUp;
    return [
      if (next != null)
        {
          'Id': '${show.id}-next',
          'Name': next.name,
          'Type': 'Episode',
          'ParentIndexNumber': next.season,
          'IndexNumber': next.episode,
          'RunTimeTicks': show.minutes * 60 * 10000000,
        },
    ];
  }
  var watched = show.watched;
  return [
    for (final (index, count) in show.seasons.indexed)
      () {
        final played = watched.clamp(0, count);
        watched -= played;
        return {
          'Id': '${show.id}-season-${index + 1}',
          'Name': 'Season ${index + 1}',
          'Type': 'Season',
          'IndexNumber': index + 1,
          'RecursiveItemCount': count,
          'UserData': {'UnplayedItemCount': count - played},
        };
      }(),
  ];
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

final class SampleShortlistStore implements ShortlistStore {
  SampleShortlistStore([
    this._entries = const [
      (id: 'goldrush', title: 'The Gold Rush'),
      (id: 'sherlockjr', title: 'Sherlock Jr.'),
    ],
  ]);

  List<ShortlistEntry> _entries;

  @override
  Future<List<ShortlistEntry>> read() async => _entries;

  @override
  Future<void> write(List<ShortlistEntry> entries) async => _entries = entries;
}

/// Serves `/Items/<id>/Images/Primary` from `<POSTER_DIR>/<id>.img`.
final class PosterHttpOverrides extends HttpOverrides {
  PosterHttpOverrides(this.directory);

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

const _scope = 'https://jellyfin.example/user';

/// The real discovery screen over the sample library, in dark theme, on
/// [mediaType] with [snapshot] as that side's saved state.
Widget sampleApp(
  DiscoverySnapshot snapshot, {
  CatalogMediaType mediaType = CatalogMediaType.movie,
}) => MaterialApp(
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
    discoveryStore: mediaType == CatalogMediaType.series
        ? (ImmediateDiscoveryStore()
            ..mediaType = mediaType
            ..others['$_scope|series'] = snapshot)
        : (ImmediateDiscoveryStore()..snapshot = snapshot),
    shortlistStore: SampleShortlistStore(),
    seriesShortlistStore: SampleShortlistStore(const [
      (id: 'twilight', title: 'The Twilight Zone'),
      (id: 'lucy', title: 'I Love Lucy'),
    ]),
  ),
);

/// Sizes the test view like a phone and serves posters from [posterDir].
void prepareView(WidgetTester tester) {
  if (posterDir.isEmpty || outDir.isEmpty || fontDir.isEmpty) {
    fail('Run through tool/website_media.sh.');
  }
  HttpOverrides.global = PosterHttpOverrides(Directory(posterDir));
  tester.view.physicalSize = logicalSize * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
}

/// Encodes what [finder] paints as PNG bytes.
Future<Uint8List> capturePng(WidgetTester tester, Finder finder) async {
  final bytes = await tester.runAsync(() async {
    final image = await captureImage(finder.evaluate().single);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}
