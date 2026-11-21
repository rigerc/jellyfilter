import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:jellyfilter/core/media/entities/catalog_series_progress.dart';
import 'package:jellyfilter/core/network/media_browser_authorization.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_filter.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_page.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_result.dart';
import 'package:jellyfilter/features/catalog/domain/failures/catalog_failure.dart';
import 'package:jellyfilter/features/catalog/domain/repositories/catalog_repository.dart';

/// Paginated Jellyfin catalog transport and deterministic local refinement.
final class JellyfinCatalogRepository implements CatalogRepository {
  JellyfinCatalogRepository({
    required this.client,
    required this.serverUrl,
    required this.accessToken,
    required this.deviceId,
    required this.userId,
    this.mediaType = CatalogMediaType.movie,
    this.pageSize = 50,
    this.timeout = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _clock = now ?? _utcNow {
    if (pageSize < 1 || pageSize > 50) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'must be between 1 and 50',
      );
    }
  }

  final http.Client client;
  final String serverUrl;
  final String accessToken;
  final String deviceId;
  final String userId;

  /// The kind of title this repository reads: movies or TV series.
  final CatalogMediaType mediaType;
  final int pageSize;
  final Duration timeout;
  final DateTime Function() _clock;

  bool get _series => mediaType == CatalogMediaType.series;

  /// Jellyfin's item type for [mediaType].
  String get _itemType => _series ? 'Series' : 'Movie';

  /// Jellyfin's library collection type for [mediaType].
  String get _collectionType => _series ? 'tvshows' : 'movies';

  /// Item fields every catalog page asks for.
  String get _fields => _series
      ? 'Genres,Tags,Studios,PrimaryImageAspectRatio,DateCreated,'
            'ChildCount,RecursiveItemCount,DateLastMediaAdded'
      : 'Genres,Tags,Studios,PrimaryImageAspectRatio,DateCreated';

  /// Which kinds of title the user's libraries hold, read from their
  /// library types. Null when the server cannot say.
  Future<Set<CatalogMediaType>?> loadAvailableMediaTypes() async {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null || baseUrl.host.isEmpty) {
      return null;
    }
    final uri = _endpoint(baseUrl, <String>[
      'UserViews',
    ]).replace(queryParameters: <String, String>{'userId': userId});
    final response = (await _get(uri)).response;
    if (response == null || _responseFailure(response) != null) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || decoded['Items'] is! List) {
      return null;
    }
    final types = (decoded['Items'] as List)
        .whereType<Map>()
        .map((item) => item['CollectionType'])
        .whereType<String>()
        .map(
          (type) => switch (type.toLowerCase()) {
            'movies' => CatalogMediaType.movie,
            'tvshows' => CatalogMediaType.series,
            _ => null,
          },
        )
        .whereType<CatalogMediaType>()
        .toSet();
    return Set<CatalogMediaType>.unmodifiable(types);
  }

  /// Resolves an explicit set of title IDs independently of discovery filters.
  Future<List<CatalogCandidate>> loadByIds(Set<String> ids) async {
    final movies = <CatalogCandidate>[];
    final requestedIds = ids.toList(growable: false);
    for (var offset = 0; offset < requestedIds.length; offset += pageSize) {
      final batch = requestedIds.skip(offset).take(pageSize).toSet();
      var startIndex = 0;
      final foundIds = <String>{};
      while (true) {
        final page = await loadPage(startIndex: startIndex, includedIds: batch);
        final failure = page.failure;
        if (failure != null &&
            failure is! NoCatalogMatchFailure &&
            failure is! MissingMetadataCatalogFailure) {
          throw failure;
        }
        for (final candidate in page.candidates) {
          if (!batch.contains(candidate.id)) {
            throw const IncompatibleCatalogFailure();
          }
          if (foundIds.add(candidate.id)) {
            movies.add(candidate);
          }
        }
        if (!page.hasMore || foundIds.length == batch.length) {
          break;
        }
        if (page.nextIndex <= startIndex || page.nextIndex >= batch.length) {
          throw const PartialCatalogFailure();
        }
        startIndex = page.nextIndex;
      }
    }
    return movies;
  }

  @override
  Future<CatalogPage> loadPage({
    CatalogFilter filter = const CatalogFilter(),
    int startIndex = 0,
    CatalogRequestCancellation? cancellation,
    Set<String> excludedIds = const <String>{},
    Set<String> includedIds = const <String>{},
  }) async {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null || baseUrl.host.isEmpty || startIndex < 0) {
      return const CatalogPage(
        candidates: <CatalogCandidate>[],
        hasMore: false,
        nextIndex: 0,
        total: 0,
        failure: IncompatibleCatalogFailure(),
      );
    }
    final capturedUtcNow = (filter.dateWindowAnchor ?? _clock()).toUtc();
    var requestedStartIndex = startIndex;
    var readAhead = 0;
    while (true) {
      if (cancellation?.isCancelled ?? false) {
        return CatalogPage(
          candidates: const <CatalogCandidate>[],
          hasMore: false,
          nextIndex: requestedStartIndex,
          total: 0,
        );
      }
      final uri = _itemsUri(
        baseUrl,
        requestedStartIndex,
        filter,
        excludedIds: excludedIds,
        includedIds: includedIds,
      );
      final request = await _get(uri, cancellation: cancellation);
      final response = request.response;
      if (response == null) {
        return CatalogPage(
          candidates: const <CatalogCandidate>[],
          hasMore: false,
          nextIndex: requestedStartIndex,
          total: 0,
          failure: request.failure,
        );
      }
      final decoded = _decodePage(response, requestedStartIndex);
      if (decoded.failure != null) {
        return CatalogPage(
          candidates: const <CatalogCandidate>[],
          hasMore: false,
          nextIndex: requestedStartIndex,
          total: decoded.total,
          failure: decoded.failure,
        );
      }
      final page = _catalogPage(
        decoded,
        filter,
        capturedUtcNow: capturedUtcNow,
        narrowed: excludedIds.isNotEmpty || includedIds.isNotEmpty,
      );
      // Local refinement (all genres/tags, exclusions) can empty a page; keep
      // reading ahead, but only so far, so a strict filter stays responsive.
      final shouldReadAhead =
          !(cancellation?.isCancelled ?? false) &&
          filter.needsLocalRefinement &&
          page.candidates.isEmpty &&
          page.failure == null &&
          page.hasMore &&
          ++readAhead <= _maxReadAhead;
      if (!shouldReadAhead) {
        return page;
      }
      requestedStartIndex = page.nextIndex;
    }
  }

  @override
  Future<CatalogResult<List<CatalogLibrary>>> loadLibraries() async {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null || baseUrl.host.isEmpty) {
      return const CatalogResult<List<CatalogLibrary>>.failure(
        IncompatibleCatalogFailure(),
      );
    }
    final uri = _endpoint(baseUrl, <String>[
      'UserViews',
    ]).replace(queryParameters: <String, String>{'userId': userId});
    final request = await _get(uri);
    final response = request.response;
    if (response == null) {
      return CatalogResult<List<CatalogLibrary>>.failure(request.failure);
    }
    final failure = _responseFailure(response);
    if (failure != null) {
      return CatalogResult<List<CatalogLibrary>>.failure(failure);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['Items'] is! List) {
        return const CatalogResult<List<CatalogLibrary>>.failure(
          IncompatibleCatalogFailure(),
        );
      }
      final libraries = (decoded['Items'] as List)
          .whereType<Map>()
          .map(_parseLibrary)
          .whereType<CatalogLibrary>()
          .where(
            (library) =>
                library.collectionType.toLowerCase() == _collectionType,
          )
          .toList(growable: false);
      return CatalogResult<List<CatalogLibrary>>.success(
        List<CatalogLibrary>.unmodifiable(libraries),
      );
    } on FormatException {
      return const CatalogResult<List<CatalogLibrary>>.failure(
        IncompatibleCatalogFailure(),
      );
    }
  }

  /// Extra pages read when local refinement leaves a page empty.
  static const _maxReadAhead = 10;

  /// Upper bound on favorites fetched in one sync (pages of [_favoritePage]).
  static const _maxFavorites = 5000;
  static const _favoritePage = 500;

  @override
  Future<CatalogResult<Set<String>>> loadFavoriteIds() async {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null || baseUrl.host.isEmpty) {
      return const CatalogResult<Set<String>>.failure(
        IncompatibleCatalogFailure(),
      );
    }
    final ids = <String>{};
    var startIndex = 0;
    while (startIndex < _maxFavorites) {
      // Ids only: no images, user data, or extra fields, so this stays cheap.
      final uri = _endpoint(baseUrl, <String>['Items']).replace(
        queryParameters: <String, String>{
          'userId': userId,
          'includeItemTypes': _itemType,
          'recursive': 'true',
          'isFavorite': 'true',
          // A series is a folder, so only movies can ask for non-folders.
          if (!_series) 'filters': 'IsNotFolder',
          'enableImages': 'false',
          'enableUserData': 'false',
          'enableTotalRecordCount': 'true',
          'fields': '',
          'startIndex': '$startIndex',
          'limit': '$_favoritePage',
        },
      );
      final request = await _get(uri);
      final response = request.response;
      if (response == null) {
        return CatalogResult<Set<String>>.failure(request.failure);
      }
      final failure = _responseFailure(response);
      if (failure != null) {
        return CatalogResult<Set<String>>.failure(failure);
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        return const CatalogResult<Set<String>>.failure(
          IncompatibleCatalogFailure(),
        );
      }
      if (decoded is! Map || decoded['Items'] is! List) {
        return const CatalogResult<Set<String>>.failure(
          IncompatibleCatalogFailure(),
        );
      }
      final items = decoded['Items'] as List;
      ids.addAll(
        items
            .whereType<Map>()
            .map((item) => item['Id'])
            .whereType<String>()
            .where((id) => id.isNotEmpty),
      );
      final total = decoded['TotalRecordCount'];
      startIndex += items.length;
      if (items.isEmpty || total is! int || startIndex >= total) {
        break;
      }
    }
    return CatalogResult<Set<String>>.success(Set<String>.unmodifiable(ids));
  }

  @override
  Future<CatalogResult<CatalogFacets>> loadFacets({String? parentId}) async {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null || baseUrl.host.isEmpty) {
      return const CatalogResult<CatalogFacets>.failure(
        IncompatibleCatalogFailure(),
      );
    }
    final parameters = <String, String>{
      'userId': userId,
      'includeItemTypes': _itemType,
      if (parentId != null && parentId.isNotEmpty) 'parentId': parentId,
    };
    final legacyRequest = _get(
      _endpoint(baseUrl, <String>[
        'Items',
        'Filters',
      ]).replace(queryParameters: parameters),
    );
    final currentRequest = _get(
      _endpoint(baseUrl, <String>['Items', 'Filters2']).replace(
        queryParameters: <String, String>{...parameters, 'recursive': 'true'},
      ),
    );
    final legacy = await legacyRequest;
    final current = await currentRequest;
    final failedRequest = <_CatalogHttpResult>[
      legacy,
      current,
    ].where((result) => result.failure != null).firstOrNull;
    if (failedRequest != null) {
      return CatalogResult<CatalogFacets>.failure(failedRequest.failure);
    }
    final legacyResponse = legacy.response;
    final currentResponse = current.response;
    if (legacyResponse == null || currentResponse == null) {
      return const CatalogResult<CatalogFacets>.failure(
        IncompatibleCatalogFailure(),
      );
    }
    final responseFailure =
        _responseFailure(legacyResponse) ?? _responseFailure(currentResponse);
    if (responseFailure != null) {
      return CatalogResult<CatalogFacets>.failure(responseFailure);
    }
    try {
      final legacyJson = jsonDecode(legacyResponse.body);
      final currentJson = jsonDecode(currentResponse.body);
      if (legacyJson is! Map || currentJson is! Map) {
        return const CatalogResult<CatalogFacets>.failure(
          IncompatibleCatalogFailure(),
        );
      }
      return CatalogResult<CatalogFacets>.success(
        _parseFacets(legacyJson, currentJson),
      );
    } on FormatException {
      return const CatalogResult<CatalogFacets>.failure(
        IncompatibleCatalogFailure(),
      );
    }
  }

  @override
  Future<CatalogResult<CatalogCandidate>> loadDetails(String itemId) async {
    final baseUrl = Uri.tryParse(serverUrl);
    final normalizedId = itemId.trim();
    if (baseUrl == null || baseUrl.host.isEmpty || normalizedId.isEmpty) {
      return const CatalogResult<CatalogCandidate>.failure(
        IncompatibleCatalogFailure(),
      );
    }
    final uri = _endpoint(baseUrl, <String>[
      'Items',
      normalizedId,
    ]).replace(queryParameters: <String, String>{'userId': userId});
    final request = await _get(uri);
    final response = request.response;
    if (response == null) {
      return CatalogResult<CatalogCandidate>.failure(request.failure);
    }
    final failure = _responseFailure(response);
    if (failure != null) {
      return CatalogResult<CatalogCandidate>.failure(failure);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const CatalogResult<CatalogCandidate>.failure(
          IncompatibleCatalogFailure(),
        );
      }
      final candidate = _parseCandidate(
        decoded.map<String, Object?>((key, value) => MapEntry('$key', value)),
      );
      return candidate == null
          ? const CatalogResult<CatalogCandidate>.failure(
              IncompatibleCatalogFailure(),
            )
          : CatalogResult<CatalogCandidate>.success(candidate);
    } on FormatException {
      return const CatalogResult<CatalogCandidate>.failure(
        IncompatibleCatalogFailure(),
      );
    }
  }

  @override
  Future<CatalogResult<CatalogSeriesProgress>> loadSeriesProgress(
    String seriesId,
  ) async {
    final baseUrl = Uri.tryParse(serverUrl);
    final id = seriesId.trim();
    if (baseUrl == null || baseUrl.host.isEmpty || id.isEmpty) {
      return const CatalogResult<CatalogSeriesProgress>.failure(
        IncompatibleCatalogFailure(),
      );
    }
    final seasonsRequest = _getItemList(
      _endpoint(baseUrl, <String>['Shows', id, 'Seasons']).replace(
        queryParameters: <String, String>{
          'userId': userId,
          'fields': 'ChildCount,RecursiveItemCount',
          'enableUserData': 'true',
          'enableImages': 'false',
        },
      ),
    );
    final nextUpRequest = _getItemList(
      _endpoint(baseUrl, <String>['Shows', 'NextUp']).replace(
        queryParameters: <String, String>{
          'userId': userId,
          'seriesId': id,
          'limit': '1',
          'fields': '',
          'enableUserData': 'false',
          'enableImages': 'false',
        },
      ),
    );
    final seasons = await seasonsRequest;
    final nextUp = await nextUpRequest;
    final seasonItems = seasons.value;
    if (seasonItems == null) {
      return CatalogResult<CatalogSeriesProgress>.failure(seasons.failure);
    }
    return CatalogResult<CatalogSeriesProgress>.success(
      CatalogSeriesProgress(
        seasons: seasonItems
            .map(_parseSeason)
            .whereType<CatalogSeason>()
            .toList(growable: false),
        // Next up is a bonus: the seasons still help when it fails.
        nextUp: nextUp.value
            ?.map(_parseEpisode)
            .whereType<CatalogEpisode>()
            .firstOrNull,
      ),
    );
  }

  Future<CatalogResult<List<Map<String, Object?>>>> _getItemList(
    Uri uri,
  ) async {
    final request = await _get(uri);
    final response = request.response;
    if (response == null) {
      return CatalogResult<List<Map<String, Object?>>>.failure(request.failure);
    }
    final failure = _responseFailure(response);
    if (failure != null) {
      return CatalogResult<List<Map<String, Object?>>>.failure(failure);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['Items'] is! List) {
        return const CatalogResult<List<Map<String, Object?>>>.failure(
          IncompatibleCatalogFailure(),
        );
      }
      return CatalogResult<List<Map<String, Object?>>>.success(
        (decoded['Items'] as List)
            .whereType<Map>()
            .map(
              (item) => item.map<String, Object?>(
                (key, value) => MapEntry('$key', value),
              ),
            )
            .toList(growable: false),
      );
    } on FormatException {
      return const CatalogResult<List<Map<String, Object?>>>.failure(
        IncompatibleCatalogFailure(),
      );
    }
  }

  CatalogSeason? _parseSeason(Map<String, Object?> item) {
    final id = _string(item['Id']);
    final name = _string(item['Name']);
    if (item['Type'] != 'Season' ||
        id == null ||
        id.isEmpty ||
        name == null ||
        name.isEmpty) {
      return null;
    }
    final userData = item['UserData'];
    return CatalogSeason(
      id: id,
      name: name,
      number: _nonNegativeInt(item['IndexNumber']),
      episodeCount:
          _nonNegativeInt(item['RecursiveItemCount']) ??
          _nonNegativeInt(item['ChildCount']),
      unplayedEpisodeCount: userData is Map
          ? _nonNegativeInt(userData['UnplayedItemCount'])
          : null,
    );
  }

  CatalogEpisode? _parseEpisode(Map<String, Object?> item) {
    final id = _string(item['Id']);
    final name = _string(item['Name']);
    if (item['Type'] != 'Episode' ||
        id == null ||
        id.isEmpty ||
        name == null ||
        name.isEmpty) {
      return null;
    }
    return CatalogEpisode(
      id: id,
      name: name,
      seasonNumber: _nonNegativeInt(item['ParentIndexNumber']),
      episodeNumber: _nonNegativeInt(item['IndexNumber']),
      runtimeMinutes: _runtimeMinutes(item['RunTimeTicks']),
    );
  }

  @override
  Stream<CatalogPage> streamPages({
    CatalogFilter filter = const CatalogFilter(),
  }) async* {
    final baseUrl = Uri.tryParse(serverUrl);
    if (baseUrl == null || baseUrl.host.isEmpty) {
      yield const CatalogPage(
        candidates: <CatalogCandidate>[],
        hasMore: false,
        nextIndex: 0,
        total: 0,
        failure: IncompatibleCatalogFailure(),
      );
      return;
    }
    final capturedUtcNow = (filter.dateWindowAnchor ?? _clock()).toUtc();
    var startIndex = 0;
    var previousStartIndex = -1;
    String? previousPageFingerprint;
    final seenIds = <String>{};
    var matchedAny = false;
    var total = 0;
    while (startIndex != previousStartIndex) {
      previousStartIndex = startIndex;
      final http.Response response;
      try {
        response = await _send(_itemsUri(baseUrl, startIndex, filter));
      } on HandshakeException {
        yield const CatalogPage(
          candidates: <CatalogCandidate>[],
          hasMore: false,
          nextIndex: 0,
          total: 0,
          failure: InvalidCertificateCatalogFailure(),
        );
        return;
      } on SocketException {
        yield const CatalogPage(
          candidates: <CatalogCandidate>[],
          hasMore: false,
          nextIndex: 0,
          total: 0,
          failure: UnreachableCatalogFailure(),
        );
        return;
      } on TimeoutException {
        yield const CatalogPage(
          candidates: <CatalogCandidate>[],
          hasMore: false,
          nextIndex: 0,
          total: 0,
          failure: UnreachableCatalogFailure(),
        );
        return;
      } on http.ClientException {
        yield const CatalogPage(
          candidates: <CatalogCandidate>[],
          hasMore: false,
          nextIndex: 0,
          total: 0,
          failure: UnreachableCatalogFailure(),
        );
        return;
      }
      final decoded = _decodePage(response, startIndex);
      if (decoded.failure != null) {
        yield CatalogPage(
          candidates: const <CatalogCandidate>[],
          hasMore: false,
          nextIndex: startIndex,
          total: decoded.total,
          failure: decoded.failure,
        );
        return;
      }
      total = decoded.total;
      final fingerprint = decoded.rawItems
          .map((item) => '${item['Id']}:${item['Type']}')
          .join('|');
      if (fingerprint == previousPageFingerprint && fingerprint.isNotEmpty) {
        yield CatalogPage(
          candidates: const <CatalogCandidate>[],
          hasMore: false,
          nextIndex: startIndex,
          total: total,
          failure: const PartialCatalogFailure(),
        );
        return;
      }
      previousPageFingerprint = fingerprint;
      final mediaItems = decoded.rawItems.where(
        (item) => item['Type'] == _itemType,
      );
      final parsedItems = mediaItems
          .map(_parseCandidate)
          .toList(growable: false);
      final hasMalformedItem =
          parsedItems.any((candidate) => candidate == null) ||
          decoded.hasMalformedItems ||
          mediaItems.any(_hasMalformedMetadata);
      final candidates = parsedItems
          .whereType<CatalogCandidate>()
          .where((candidate) => seenIds.add(candidate.id))
          .where((candidate) => filter.matches(candidate, now: capturedUtcNow))
          .toList(growable: false);
      final hasMissingMetadata = candidates.any(
        (candidate) =>
            candidate.poster.isFallback || candidate.backdrop.isFallback,
      );
      matchedAny = matchedAny || candidates.isNotEmpty;
      final returnedCount = decoded.rawItemCount;
      final nextIndex = decoded.startIndex + returnedCount;
      final hasMore = returnedCount > 0 && nextIndex < total;
      final isEmptyWithRemaining =
          returnedCount == 0 && decoded.startIndex < total;
      final isFinal = !hasMore;
      CatalogFailure? terminalFailure;
      if (isFinal && total == 0 && filter.isActive) {
        terminalFailure = const NoCatalogMatchFailure();
      } else if (isFinal && total == 0) {
        terminalFailure = const NoAccessibleLibraryFailure();
      } else if (isEmptyWithRemaining) {
        terminalFailure = const PartialCatalogFailure();
      } else if (isFinal && filter.isActive && !matchedAny) {
        terminalFailure = const NoCatalogMatchFailure();
      } else if (hasMalformedItem) {
        terminalFailure = const PartialCatalogFailure();
      } else if (hasMissingMetadata) {
        terminalFailure = const MissingMetadataCatalogFailure();
      }
      yield CatalogPage(
        candidates: candidates,
        hasMore: hasMore,
        nextIndex: nextIndex,
        total: total,
        failure: terminalFailure,
      );
      if (!hasMore) {
        return;
      }
      startIndex = nextIndex;
    }
  }

  Future<http.Response> _send(
    Uri uri, {
    CatalogRequestCancellation? cancellation,
  }) async {
    final abort = Completer<void>();
    void cancel() {
      if (!abort.isCompleted) abort.complete();
    }

    unawaited(cancellation?.whenCancelled.then((_) => cancel()));
    if (cancellation?.isCancelled ?? false) {
      throw http.RequestAbortedException(uri);
    }
    final request =
        http.AbortableRequest('GET', uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll(<String, String>{
            'Authorization': MediaBrowserAuthorization.value(
              deviceId: deviceId,
              token: accessToken,
            ),
          });
    return (() async {
      return http.Response.fromStream(await client.send(request));
    })().timeout(
      timeout,
      onTimeout: () {
        cancel();
        throw TimeoutException('Catalog request timed out', timeout);
      },
    );
  }

  Future<_CatalogHttpResult> _get(
    Uri uri, {
    CatalogRequestCancellation? cancellation,
  }) async {
    try {
      return _CatalogHttpResult.response(
        await _send(uri, cancellation: cancellation),
      );
    } on HandshakeException {
      return const _CatalogHttpResult.failure(
        InvalidCertificateCatalogFailure(),
      );
    } on SocketException {
      return const _CatalogHttpResult.failure(UnreachableCatalogFailure());
    } on TimeoutException {
      return const _CatalogHttpResult.failure(UnreachableCatalogFailure());
    } on http.ClientException {
      return const _CatalogHttpResult.failure(UnreachableCatalogFailure());
    }
  }

  /// [narrowed] means the request named titles to include or exclude, so an
  /// empty answer says nothing about whether the library is accessible.
  CatalogPage _catalogPage(
    _DecodedPage decoded,
    CatalogFilter filter, {
    required DateTime capturedUtcNow,
    bool narrowed = false,
  }) {
    final mediaItems = decoded.rawItems.where(
      (item) => item['Type'] == _itemType,
    );
    final parsedItems = mediaItems.map(_parseCandidate).toList(growable: false);
    final candidates = parsedItems
        .whereType<CatalogCandidate>()
        .where((candidate) => filter.matches(candidate, now: capturedUtcNow))
        .toList(growable: false);
    final nextIndex = decoded.startIndex + decoded.rawItemCount;
    final hasMore = decoded.rawItemCount > 0 && nextIndex < decoded.total;
    final malformed =
        decoded.hasMalformedItems ||
        parsedItems.any((candidate) => candidate == null) ||
        mediaItems.any(_hasMalformedMetadata);
    final missingImages = candidates.any(
      (candidate) =>
          candidate.poster.isFallback || candidate.backdrop.isFallback,
    );
    final failure = switch ((
      decoded.total,
      candidates.isEmpty,
      malformed,
      missingImages,
    )) {
      (0, _, _, _) when filter.isActive || narrowed =>
        const NoCatalogMatchFailure(),
      (0, _, _, _) => const NoAccessibleLibraryFailure(),
      (_, true, _, _) when !hasMore && filter.isActive =>
        const NoCatalogMatchFailure(),
      (_, _, true, _) => const PartialCatalogFailure(),
      (_, _, _, true) => const MissingMetadataCatalogFailure(),
      _ => null,
    };
    return CatalogPage(
      candidates: candidates,
      hasMore: hasMore,
      nextIndex: nextIndex,
      total: decoded.total,
      failure: failure,
    );
  }

  CatalogFailure? _responseFailure(http.Response response) {
    if (response.statusCode == 401) {
      return const ExpiredCatalogFailure();
    }
    if (response.statusCode == 403) {
      return const UnauthorizedCatalogFailure();
    }
    if (response.statusCode >= 500) {
      return const ServerCatalogFailure();
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      return const RedirectCatalogFailure();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const IncompatibleCatalogFailure();
    }
    return null;
  }

  Uri _endpoint(Uri baseUrl, List<String> segments) => baseUrl.replace(
    pathSegments: <String>[
      ...baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
      ...segments,
    ],
    query: null,
    fragment: null,
  );

  Uri _itemsUri(
    Uri baseUrl,
    int startIndex,
    CatalogFilter filter, {
    Set<String> excludedIds = const <String>{},
    Set<String> includedIds = const <String>{},
  }) {
    final path = '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/Items';
    final genres = filter.genres.toList()..sort();
    final years =
        filter.decades
            .expand(
              (decade) =>
                  Iterable<int>.generate(10, (offset) => decade + offset),
            )
            .toSet()
            .toList()
          ..sort();
    final minimumCommunity = filter.minimumCommunityRating;
    final minimumCritic = filter.minimumCriticRating;
    return baseUrl.replace(
      path: path,
      queryParameters: <String, String>{
        'userId': userId,
        'parentId': ?filter.libraryId,
        'includeItemTypes': _itemType,
        'recursive': 'true',
        'fields': _fields,
        'enableUserData': 'true',
        'enableImages': 'true',
        'enableImageTypes': 'Primary,Backdrop',
        'imageTypeLimit': '1',
        'enableTotalRecordCount': 'true',
        if (!_series) 'filters': 'IsNotFolder',
        if (filter.searchTerm.trim().isNotEmpty)
          'searchTerm': filter.searchTerm.trim(),
        if (filter.watched != null) 'isPlayed': '${filter.watched}',
        if (filter.favorite != null) 'isFavorite': '${filter.favorite}',
        if (minimumCommunity != null) 'minCommunityRating': '$minimumCommunity',
        if (minimumCritic != null) 'minCriticRating': '$minimumCritic',
        if (genres.isNotEmpty) 'genres': genres.first,
        // Jellyfin matches any listed tag; every tag is enforced locally.
        if (filter.tags.isNotEmpty)
          'tags': (filter.tags.toList()..sort()).first,
        if (years.isNotEmpty) 'years': years.join(','),
        if (filter.officialRatings.isNotEmpty)
          'officialRatings': (filter.officialRatings.toList()..sort()).join(
            '|',
          ),
        if (excludedIds.isNotEmpty)
          'excludeItemIds': (excludedIds.toList()..sort()).take(100).join(','),
        if (includedIds.isNotEmpty)
          'ids': (includedIds.toList()..sort()).take(pageSize).join(','),
        ..._sortParameters(
          filter.sort,
          reversed: filter.canReverseSort && filter.sortReversed,
        ),
        'startIndex': '$startIndex',
        'limit': '$pageSize',
      },
    );
  }

  _DecodedPage _decodePage(http.Response response, int requestedStartIndex) {
    if (response.statusCode == 401) {
      return const _DecodedPage.failure(ExpiredCatalogFailure());
    }
    if (response.statusCode == 403) {
      return const _DecodedPage.failure(UnauthorizedCatalogFailure());
    }
    if (response.statusCode >= 500) {
      return const _DecodedPage.failure(ServerCatalogFailure());
    }
    if (response.statusCode >= 300 && response.statusCode < 400) {
      return const _DecodedPage.failure(RedirectCatalogFailure());
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const _DecodedPage.failure(IncompatibleCatalogFailure());
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['Items'] is! List) {
        return const _DecodedPage.failure(IncompatibleCatalogFailure());
      }
      final rawItems = decoded['Items'] as List;
      final hasMalformedItems = rawItems.any((item) => item is! Map);
      final items = rawItems
          .whereType<Map>()
          .map(
            (item) => item.map<String, Object?>(
              (key, value) => MapEntry('$key', value),
            ),
          )
          .toList(growable: false);
      final total = decoded['TotalRecordCount'];
      if (total is! int || total < 0) {
        return const _DecodedPage.failure(IncompatibleCatalogFailure());
      }
      final startIndex = decoded['StartIndex'];
      return _DecodedPage(
        items,
        total,
        startIndex is int && startIndex >= 0 ? startIndex : requestedStartIndex,
        hasMalformedItems,
        rawItems.length,
      );
    } on Object catch (_) {
      return const _DecodedPage.failure(IncompatibleCatalogFailure());
    }
  }

  CatalogCandidate? _parseCandidate(Map<String, Object?> item) {
    final id = item['Id'];
    final name = item['Name'];
    final mediaType = item['Type'] == _itemType ? this.mediaType : null;
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        mediaType == null) {
      return null;
    }
    final userData = item['UserData'] is Map
        ? (item['UserData'] as Map).map<String, Object?>(
            (key, value) => MapEntry('$key', value),
          )
        : const <String, Object?>{};
    final genres = item['Genres'] is List
        ? (item['Genres'] as List)
              .whereType<String>()
              .map((genre) => genre.toLowerCase())
              .toSet()
        : const <String>{};
    final imageTags = item['ImageTags'] is Map
        ? (item['ImageTags'] as Map).map<String, Object?>(
            (key, value) => MapEntry('$key', value),
          )
        : const <String, Object?>{};
    final backdropTags = item['BackdropImageTags'] is List
        ? (item['BackdropImageTags'] as List).whereType<String>().toList(
            growable: false,
          )
        : const <String>[];
    final blurHashes = item['ImageBlurHashes'] is Map
        ? (item['ImageBlurHashes'] as Map).map<String, Object?>(
            (key, value) => MapEntry('$key', value),
          )
        : const <String, Object?>{};
    final primaryTag = _string(imageTags['Primary']);
    final backdropTag = backdropTags.firstOrNull;
    final primaryAspectRatio = _number(item['PrimaryImageAspectRatio']);
    return CatalogCandidate(
      id: id,
      name: name,
      mediaType: mediaType,
      year: item['ProductionYear'] is int
          ? item['ProductionYear'] as int
          : null,
      runtimeMinutes: _runtimeMinutes(item['RunTimeTicks']),
      genres: genres,
      tags: item['Tags'] is List
          ? (item['Tags'] as List)
                .whereType<String>()
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toSet()
          : const <String>{},
      communityRating: _number(item['CommunityRating']),
      criticRating: _number(item['CriticRating']),
      officialRating: _string(item['OfficialRating']),
      status: _string(item['Status']),
      dateCreated: _dateTime(item['DateCreated']),
      overview: _string(item['Overview']),
      cast: item['People'] is List
          ? (item['People'] as List)
                .whereType<Map>()
                .map((person) => person['Name'])
                .whereType<String>()
                .toList(growable: false)
          : const <String>[],
      trailers: _trailers(item['RemoteTrailers']),
      watched: _bool(userData['Played']),
      favorite: _bool(userData['IsFavorite']),
      studios: _nameList(item['Studios']).toSet(),
      playCount: _nonNegativeInt(userData['PlayCount']),
      lastPlayed: _dateTime(userData['LastPlayedDate']),
      likes: _bool(userData['Likes']),
      userRating: _number(userData['Rating']),
      series: _series ? _seriesFacts(item, userData) : null,
      poster: _image(
        baseUrl: Uri.parse(serverUrl),
        id: id,
        tag: primaryTag,
        backdrop: false,
        aspectRatio: primaryAspectRatio != null && primaryAspectRatio > 0
            ? primaryAspectRatio
            : 0.67,
        blurHash: _blurHash(blurHashes, 'Primary', primaryTag),
      ),
      backdrop: _image(
        baseUrl: Uri.parse(serverUrl),
        id: id,
        tag: backdropTag,
        backdrop: true,
        aspectRatio: 1.78,
        blurHash: _blurHash(blurHashes, 'Backdrop', backdropTag),
      ),
    );
  }

  CatalogSeriesFacts _seriesFacts(
    Map<String, Object?> item,
    Map<String, Object?> userData,
  ) => CatalogSeriesFacts(
    seasonCount: _nonNegativeInt(item['ChildCount']),
    episodeCount: _nonNegativeInt(item['RecursiveItemCount']),
    unplayedEpisodeCount: _nonNegativeInt(userData['UnplayedItemCount']),
    endYear: _string(item['Status'])?.toLowerCase() == 'ended'
        ? _dateTime(item['EndDate'])?.year
        : null,
    lastEpisodeAdded: _dateTime(item['DateLastMediaAdded']),
  );

  List<CatalogTrailer> _trailers(Object? value) {
    if (value is! List) {
      return const <CatalogTrailer>[];
    }
    final seen = <Uri>{};
    return value
        .whereType<Map>()
        .map(_parseTrailer)
        .whereType<CatalogTrailer>()
        .where((trailer) => seen.add(trailer.uri))
        .toList(growable: false);
  }

  CatalogTrailer? _parseTrailer(Map<Object?, Object?> trailer) {
    final rawUrl = _string(trailer['Url']);
    if (rawUrl == null) {
      return null;
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return CatalogTrailer(name: _string(trailer['Name']), uri: uri);
  }

  CatalogImage _image({
    required Uri baseUrl,
    required String id,
    required String? tag,
    required bool backdrop,
    required double aspectRatio,
    required String? blurHash,
  }) {
    if (tag == null || tag.isEmpty) {
      return const CatalogImage.fallback();
    }
    final kind = backdrop ? 'Backdrop' : 'Primary';
    final path =
        '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/Items/$id/Images/$kind';
    return CatalogImage(
      uri: baseUrl.replace(
        path: path,
        queryParameters: <String, String>{'tag': tag},
      ),
      isFallback: false,
      aspectRatio: aspectRatio,
      blurHash: blurHash,
    );
  }

  String? _blurHash(
    Map<String, Object?> imageBlurHashes,
    String imageType,
    String? tag,
  ) {
    if (tag == null || imageBlurHashes[imageType] is! Map) {
      return null;
    }
    final hashes = imageBlurHashes[imageType] as Map;
    return _string(hashes[tag]);
  }

  CatalogLibrary? _parseLibrary(Map<Object?, Object?> item) {
    final id = item['Id'];
    final name = item['Name'];
    final collectionType = item['CollectionType'];
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.isEmpty ||
        collectionType is! String ||
        collectionType.isEmpty) {
      return null;
    }
    return CatalogLibrary(id: id, name: name, collectionType: collectionType);
  }

  CatalogFacets _parseFacets(Map legacy, Map current) {
    final genres = <String>{
      ..._stringList(legacy['Genres']),
      ..._nameList(current['Genres']),
    }.toList()..sort();
    final years = _intList(legacy['Years']).toSet().toList()..sort();
    final officialRatings = _stringList(
      legacy['OfficialRatings'],
    ).toSet().toList()..sort();
    final tags = <String>{
      ..._stringList(legacy['Tags']),
      ..._stringList(current['Tags']),
    }.toList()..sort();
    return CatalogFacets(
      genres: List<String>.unmodifiable(genres),
      years: List<int>.unmodifiable(years),
      officialRatings: List<String>.unmodifiable(officialRatings),
      tags: List<String>.unmodifiable(tags),
      audioLanguages: _facetValues(current['AudioLanguages']),
      subtitleLanguages: _facetValues(current['SubtitleLanguages']),
    );
  }

  List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
      : const <String>[];

  List<int> _intList(Object? value) =>
      value is List ? value.whereType<int>().toList() : const <int>[];

  List<String> _nameList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => item['Name'])
            .whereType<String>()
            .where((item) => item.isNotEmpty)
            .toList()
      : const <String>[];

  List<CatalogFacetValue> _facetValues(Object? value) {
    if (value is! List) {
      return const <CatalogFacetValue>[];
    }
    final values =
        value
            .whereType<Map>()
            .map((item) {
              final name = item['Name'];
              final facetValue = item['Value'];
              return name is String &&
                      name.isNotEmpty &&
                      facetValue is String &&
                      facetValue.isNotEmpty
                  ? CatalogFacetValue(name: name, value: facetValue)
                  : null;
            })
            .whereType<CatalogFacetValue>()
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    return List<CatalogFacetValue>.unmodifiable(values);
  }

  int? _runtimeMinutes(Object? ticks) =>
      ticks is int ? ticks ~/ 600000000 : null;

  double? _number(Object? value) => value is num ? value.toDouble() : null;

  DateTime? _dateTime(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  String? _string(Object? value) => value is String ? value : null;

  bool? _bool(Object? value) => value is bool ? value : null;

  int? _nonNegativeInt(Object? value) =>
      value is int && value >= 0 ? value : null;

  bool _hasMalformedMetadata(Map<String, Object?> item) {
    final userData = item['UserData'];
    if (userData != null && userData is! Map) {
      return true;
    }
    if (userData is Map) {
      final played = userData['Played'];
      final favorite = userData['IsFavorite'];
      if ((played != null && played is! bool) ||
          (favorite != null && favorite is! bool)) {
        return true;
      }
    }
    final genres = item['Genres'];
    final imageTags = item['ImageTags'];
    final backdropTags = item['BackdropImageTags'];
    final people = item['People'];
    return (genres != null && genres is! List) ||
        (imageTags != null && imageTags is! Map) ||
        (backdropTags != null && backdropTags is! List) ||
        (people != null && people is! List) ||
        (item['RunTimeTicks'] != null && item['RunTimeTicks'] is! int) ||
        (item['ProductionYear'] != null && item['ProductionYear'] is! int) ||
        (item['CommunityRating'] != null && item['CommunityRating'] is! num) ||
        (item['CriticRating'] != null && item['CriticRating'] is! num) ||
        (item['DateCreated'] != null &&
            (item['DateCreated'] is! String ||
                _dateTime(item['DateCreated']) == null));
  }

  /// Jellyfin sort parameters, with the natural direction flipped when
  /// [reversed].
  Map<String, String> _sortParameters(
    CatalogSort sort, {
    bool reversed = false,
  }) {
    final parameters = _naturalSortParameters(sort);
    final order = parameters['sortOrder'];
    if (!reversed || order == null) {
      return parameters;
    }
    return <String, String>{
      ...parameters,
      'sortOrder': order == 'Ascending' ? 'Descending' : 'Ascending',
    };
  }

  Map<String, String> _naturalSortParameters(CatalogSort sort) =>
      switch (sort) {
        // For you is ranked on the device, over the default server order.
        CatalogSort.defaultOrder ||
        CatalogSort.forYou => const <String, String>{
          'sortBy': 'CommunityRating,SortName',
          'sortOrder': 'Descending,Ascending',
        },
        CatalogSort.random => const <String, String>{'sortBy': 'Random'},
        CatalogSort.recentlyAdded => const <String, String>{
          'sortBy': 'DateCreated',
          'sortOrder': 'Descending',
        },
        CatalogSort.title => const <String, String>{
          'sortBy': 'SortName',
          'sortOrder': 'Ascending',
        },
        CatalogSort.releaseYear => const <String, String>{
          'sortBy': 'ProductionYear',
          'sortOrder': 'Descending',
        },
        CatalogSort.communityRating => const <String, String>{
          'sortBy': 'CommunityRating',
          'sortOrder': 'Descending',
        },
        CatalogSort.runtime => const <String, String>{
          'sortBy': 'Runtime',
          'sortOrder': 'Ascending',
        },
        CatalogSort.newEpisodes => const <String, String>{
          'sortBy': 'DateLastContentAdded,SortName',
          'sortOrder': 'Descending,Ascending',
        },
      };

  static DateTime _utcNow() => DateTime.now().toUtc();
}

final class _DecodedPage {
  const _DecodedPage(
    this.rawItems,
    this.total,
    this.startIndex,
    this.hasMalformedItems,
    this.rawItemCount,
  ) : failure = null;

  const _DecodedPage.failure(this.failure)
    : rawItems = const <Map<String, Object?>>[],
      total = 0,
      startIndex = 0,
      hasMalformedItems = false,
      rawItemCount = 0;

  final List<Map<String, Object?>> rawItems;
  final int total;
  final int startIndex;
  final bool hasMalformedItems;
  final int rawItemCount;
  final CatalogFailure? failure;
}

final class _CatalogHttpResult {
  const _CatalogHttpResult.response(this.response) : failure = null;

  const _CatalogHttpResult.failure(this.failure) : response = null;

  final http.Response? response;
  final CatalogFailure? failure;
}
