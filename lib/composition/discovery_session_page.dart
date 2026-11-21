import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/composition/media_session.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/media/entities/catalog_series_progress.dart';
import 'package:jellyfilter/core/network/media_browser_authorization.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/catalog/application/catalog_cubit.dart';
import 'package:jellyfilter/features/catalog/data/jellyfin_catalog_repository.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/failures/catalog_failure.dart';
import 'package:jellyfilter/features/connection/domain/entities/stored_session.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/application/random_discovery_selector.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/discovery_store.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';
import 'package:jellyfilter/features/discovery/domain/serialization/catalog_filter_codec.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/favorites/application/favorite_cubit.dart';
import 'package:jellyfilter/features/favorites/data/jellyfin_favorite_repository.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_bulk_playlist_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/persistence/data/shared_preferences_discovery_store.dart';
import 'package:jellyfilter/features/persistence/data/shared_preferences_shortlist_store.dart';
import 'package:jellyfilter/features/recommendations/application/recommendation_cubit.dart';
import 'package:jellyfilter/features/recommendations/data/jellyfin_taste_repository.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/repositories/taste_repository.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

final class DiscoverySessionPage extends StatefulWidget {
  const DiscoverySessionPage({
    required this.session,
    required this.client,
    this.onReconnect,
    this.discoveryStore,
    this.shortlistStore,
    this.seriesShortlistStore,
    this.tasteRepository,
    this.seriesTasteRepository,
    super.key,
  });

  final StoredSession session;
  final http.Client client;
  final VoidCallback? onReconnect;
  final DiscoveryStore? discoveryStore;

  /// Saved movies; the default keeps them on the device.
  final ShortlistStore? shortlistStore;

  /// Saved shows, kept apart from movies; the default keeps them on the
  /// device.
  final ShortlistStore? seriesShortlistStore;
  final TasteRepository? tasteRepository;
  final TasteRepository? seriesTasteRepository;

  @override
  State<DiscoverySessionPage> createState() => _DiscoverySessionPageState();
}

final class _DiscoverySessionPageState extends State<DiscoverySessionPage>
    with WidgetsBindingObserver {
  /// Minimum gap between favorite syncs triggered by resume or mode changes.
  static const _favoriteSyncInterval = Duration(seconds: 10);

  /// Minimum gap between watch history refreshes on resume.
  static const _historyRefreshInterval = Duration(minutes: 5);

  late final String _scope;
  late final DiscoveryBlobPreferences _preferences =
      SharedPreferencesAsyncBlobPreferences();
  late final DiscoveryStore _store;
  late final FavoriteCubit _favoriteCubit;
  late final LibraryActionsRepository _libraryActions;
  late final JellyfinCatalogRepository _movieCatalog;

  /// One session per kind of title, created the first time it is shown.
  final Map<CatalogMediaType, MediaSession> _sessions =
      <CatalogMediaType, MediaSession>{};
  late MediaSession _active;

  /// The kinds the server holds; empty until Jellyfin says.
  Set<CatalogMediaType> _available = const <CatalogMediaType>{};
  DateTime? _lastFavoriteSync;
  bool _syncingFavorites = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _scope = '${session.serverUrl}/${session.userId}';
    _store =
        widget.discoveryStore ?? SharedPreferencesDiscoveryStore(_preferences);
    _movieCatalog = _catalogRepository(CatalogMediaType.movie);
    _active = _sessionFor(CatalogMediaType.movie);
    _favoriteCubit = FavoriteCubit(
      JellyfinFavoriteRepository(
        client: widget.client,
        serverUrl: session.serverUrl,
        accessToken: session.accessToken,
        deviceId: session.deviceId,
        userId: session.userId,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
    _libraryActions = JellyfinLibraryActionsRepository(
      client: widget.client,
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
      deviceId: session.deviceId,
      userId: session.userId,
    );
    unawaited(_start());
  }

  JellyfinCatalogRepository _catalogRepository(CatalogMediaType type) {
    final session = widget.session;
    return JellyfinCatalogRepository(
      client: widget.client,
      serverUrl: session.serverUrl,
      accessToken: session.accessToken,
      deviceId: session.deviceId,
      userId: session.userId,
      mediaType: type,
    );
  }

  /// The session for [type], built and wired on first use.
  MediaSession _sessionFor(CatalogMediaType type) =>
      _sessions[type] ??= _createSession(type);

  MediaSession _createSession(CatalogMediaType type) {
    final session = widget.session;
    final movies = type == CatalogMediaType.movie;
    // Movies keep the keys they always had, so nothing saved is lost.
    final scope = movies ? _scope : '$_scope|${type.name}';
    final catalog = movies ? _movieCatalog : _catalogRepository(type);
    final shortlistStore = movies
        ? widget.shortlistStore
        : widget.seriesShortlistStore;
    final tasteRepository = movies
        ? widget.tasteRepository
        : widget.seriesTasteRepository;
    final media = MediaSession(
      mediaType: type,
      catalog: CatalogCubit(catalog),
      discovery: DiscoveryCubit(
        store: _store,
        scopeKey: scope,
        selector: RandomDiscoverySelector(),
        mediaType: type,
      ),
      shortlist: ShortlistCubit(
        store:
            shortlistStore ??
            SharedPreferencesShortlistStore(_preferences, scope),
        loadMovies: catalog.loadByIds,
        selector: RandomDiscoverySelector(),
        mediaType: type,
      ),
      recommendations: RecommendationCubit(
        repository:
            tasteRepository ??
            JellyfinTasteRepository(
              client: widget.client,
              serverUrl: session.serverUrl,
              accessToken: session.accessToken,
              deviceId: session.deviceId,
              userId: session.userId,
              mediaType: type,
            ),
      ),
    );
    unawaited(media.shortlist.hydrate());
    CatalogState? previous;
    media.subscriptions.addAll(<StreamSubscription<Object?>>[
      // Every loaded page reaches discovery, even while the other kind of
      // title is on screen, so switching back shows a complete catalog.
      media.catalog.stream.listen((state) {
        final before = previous;
        previous = state;
        if (state is! CatalogLoaded) {
          return;
        }
        if (before is CatalogLoaded &&
            identical(before.candidates, state.candidates)) {
          return;
        }
        unawaited(media.discovery.replaceCandidates(state.candidates));
      }),
      media.catalog.stream.listen((_) => _feedRecommendations(media)),
      media.shortlist.stream.listen((_) => _feedRecommendations(media)),
      media.recommendations.stream.listen(
        (state) => unawaited(media.discovery.updateAffinity(state.affinity)),
      ),
    ]);
    return media;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Favorites may have changed in another Jellyfin app while we were away.
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncFavorites());
      _refreshHistory(_active);
    }
  }

  void _refreshHistory(MediaSession media) {
    final last = media.lastHistoryRefresh;
    final now = DateTime.now();
    if (last != null && now.difference(last) < _historyRefreshInterval) {
      return;
    }
    media.lastHistoryRefresh = now;
    unawaited(media.recommendations.refreshHistory());
  }

  /// Hands the catalog and the user's choices to recommendations, and
  /// starts learning once a For you view is in use.
  void _feedRecommendations(MediaSession media) {
    final discovery = media.discovery.state;
    final catalog = media.catalog.state;
    unawaited(
      media.recommendations.update(
        candidates: catalog is CatalogLoaded
            ? catalog.candidates
            : const <CatalogCandidate>[],
        choices: LocalTasteChoices(
          likedIds: discovery.likedIds,
          rejectedIds: discovery.rejectedIds,
          shortlistedIds: media.shortlist.state.entries
              .map((entry) => entry.id)
              .toSet(),
        ),
      ),
    );
    if (discovery.filter.sort == CatalogSort.forYou ||
        discovery.shuffleForYou) {
      media.lastHistoryRefresh ??= DateTime.now();
      unawaited(media.recommendations.activate());
    }
  }

  Future<void> _syncFavorites() async {
    final last = _lastFavoriteSync;
    final now = DateTime.now();
    if (_syncingFavorites ||
        (last != null && now.difference(last) < _favoriteSyncInterval)) {
      return;
    }
    _syncingFavorites = true;
    _lastFavoriteSync = now;
    try {
      await _active.catalog.syncFavorites();
    } finally {
      _syncingFavorites = false;
    }
  }

  Future<void> _start() async {
    unawaited(_checkAvailability());
    CatalogMediaType? stored;
    try {
      stored = await _store.readMediaType(_scope);
    } on Object catch (_) {
      // A missing choice just means movies, as before shows existed.
    }
    if (!mounted) {
      return;
    }
    if (stored != null && stored != _active.mediaType) {
      setState(() => _active = _sessionFor(stored!));
    }
    await _show(_active);
  }

  /// Learns which kinds of title the server holds. Shows the switch when
  /// there are both, and leaves a kind the server no longer has.
  Future<void> _checkAvailability() async {
    final types = await _movieCatalog.loadAvailableMediaTypes();
    if (!mounted || types == null) {
      return;
    }
    setState(() => _available = types);
    if (types.isEmpty || types.contains(_active.mediaType)) {
      return;
    }
    await _switchTo(
      types.contains(CatalogMediaType.movie)
          ? CatalogMediaType.movie
          : types.first,
    );
  }

  Future<void> _switchTo(CatalogMediaType type) async {
    if (!mounted || type == _active.mediaType) {
      return;
    }
    final from = _active;
    final to = _sessionFor(type);
    setState(() => _active = to);
    try {
      await _store.writeMediaType(_scope, type);
    } on Object catch (_) {
      // Only the choice for next launch is lost.
    }
    await _show(to, adoptFrom: from.discovery.state);
  }

  /// Restores [media]'s saved state, takes on the tab and layout the user
  /// was just using, and loads its catalog the first time.
  Future<void> _show(MediaSession media, {DiscoveryState? adoptFrom}) async {
    await (media.hydration ??= media.discovery.hydrate());
    if (!mounted) {
      return;
    }
    if (adoptFrom != null) {
      await media.discovery.adoptPresentation(adoptFrom);
    }
    if (media.listening) {
      unawaited(_syncFavorites());
      return;
    }
    media.listening = true;
    media.lastMode = media.discovery.state.mode;
    media.subscriptions.add(
      media.discovery.stream.listen(
        (state) => _reloadWhenDiscoveryChanges(media, state),
      ),
    );
    _feedRecommendations(media);
    await _loadCatalog(media, media.discovery.state);
  }

  void _reloadWhenDiscoveryChanges(MediaSession media, DiscoveryState state) {
    _feedRecommendations(media);
    final modeChanged = state.mode != media.lastMode;
    media.lastMode = state.mode;
    final fingerprint = _fingerprint(state);
    if (fingerprint != media.loadedFilterFingerprint) {
      unawaited(_loadCatalog(media, state));
      return;
    }
    if (modeChanged && identical(media, _active)) {
      unawaited(_syncFavorites());
    }
  }

  Future<void> _loadCatalog(MediaSession media, DiscoveryState state) async {
    media.loadedFilterFingerprint = _fingerprint(state);
    await media.catalog.load(filter: state.filter, loadAllPages: true);
  }

  String _fingerprint(DiscoveryState state) =>
      CatalogFilterCodec.encode(state.filter).toString();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_favoriteCubit.close());
    for (final media in _sessions.values) {
      unawaited(media.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = _active;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : CandyMotion.standard,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<CatalogMediaType>(media.mediaType),
        child: MultiBlocProvider(
          providers: [
            BlocProvider<CatalogCubit>.value(value: media.catalog),
            BlocProvider<DiscoveryCubit>.value(value: media.discovery),
            BlocProvider<FavoriteCubit>.value(value: _favoriteCubit),
            BlocProvider<ShortlistCubit>.value(value: media.shortlist),
          ],
          child: BlocBuilder<CatalogCubit, CatalogState>(
            bloc: media.catalog,
            builder: (context, state) => _page(context, media, state),
          ),
        ),
      ),
    );
  }

  Widget _page(BuildContext context, MediaSession media, CatalogState state) {
    final session = widget.session;
    final isShuffle = context.select(
      (DiscoveryCubit cubit) => cubit.state.mode == DiscoveryMode.shuffle,
    );
    final useShortlist = context.select(
      (ShortlistCubit cubit) => cubit.state.useShortlist,
    );
    final loading = switch (state) {
      CatalogLoading() || CatalogLoaded(loadingMore: true) => true,
      _ => false,
    };
    final failedWithoutCandidates = switch (state) {
      CatalogLoaded(candidates: final values, failure: final failure) =>
        values.isEmpty && failure != null && failure is! NoCatalogMatchFailure,
      _ => false,
    };
    final other = _available
        .where((type) => type != media.mediaType)
        .firstOrNull;
    if (failedWithoutCandidates && !isShuffle) {
      return _CatalogError(
        onReconnect: widget.onReconnect ?? _retry,
        switchTo: other,
        onSwitch: other == null ? null : () => unawaited(_switchTo(other)),
      );
    }
    if (!isShuffle &&
        state is CatalogLoading &&
        media.discovery.state.candidates.isEmpty) {
      return const _CatalogLoading();
    }
    return Stack(
      children: <Widget>[
        DiscoveryPage(
          onOrganize: (context, candidate) => showDiscoveryOrganizer(
            context,
            candidate,
            repository: _libraryActions,
            initialTags: candidate.tags.toList(),
            knownTags: state is CatalogLoaded
                ? state.facets.tags
                : const <String>[],
            onTagsSaved: media.catalog.setTags,
          ),
          // Jellyfin would add every episode of a show to a playlist.
          onAddToPlaylist: media.mediaType == CatalogMediaType.movie
              ? (context, movies) => showDiscoveryBulkPlaylist(
                  context,
                  movies,
                  repository: _libraryActions,
                )
              : null,
          cubit: media.discovery,
          mediaTypes: _available,
          onMediaTypeChanged: (type) => unawaited(_switchTo(type)),
          onLoadSeriesProgress: _loadSeriesProgress,
          libraries: state is CatalogLoaded ? state.libraries : const [],
          facets: state is CatalogLoaded ? state.facets : const CatalogFacets(),
          onLoadMore: media.catalog.loadMore,
          onLoadDetails: _loadDetails,
          onOpenTrailer: _openTrailer,
          imageHeaders: <String, String>{
            'Authorization': MediaBrowserAuthorization.value(
              deviceId: session.deviceId,
              token: session.accessToken,
            ),
          },
          onToggleFavorite: _toggleFavorite,
          onRetryCatalog: failedWithoutCandidates
              ? (widget.onReconnect ?? _retry)
              : null,
        ),
        if (loading && !(isShuffle && useShortlist))
          const LinearProgressIndicator(),
      ],
    );
  }

  /// The session that holds [candidate]'s kind of title.
  MediaSession _owner(CatalogCandidate candidate) =>
      _sessions[candidate.mediaType] ?? _active;

  /// Flips a favorite instantly, confirms it with Jellyfin, and rolls back
  /// on failure. A newer tap on the same title owns the final outcome.
  Future<bool> _toggleFavorite(CatalogCandidate candidate) async {
    final catalog = _owner(candidate).catalog;
    final current =
        catalog.favoriteOf(candidate.id) ?? candidate.favorite == true;
    final requested = !current;
    _showFavorite(candidate, requested);
    await _favoriteCubit.setFavorite(
      itemId: candidate.id,
      isFavorite: requested,
    );
    if (!mounted) {
      return true;
    }
    final mutation = _favoriteCubit.state.forItem(candidate.id);
    final superseded =
        mutation == null ||
        mutation.status == FavoriteStatus.pending ||
        mutation.requestedValue != requested;
    if (superseded || mutation.status == FavoriteStatus.succeeded) {
      return true;
    }
    _showFavorite(candidate, current);
    return false;
  }

  void _showFavorite(CatalogCandidate candidate, bool favorite) {
    final media = _owner(candidate);
    // The catalog is the source of truth; the discovery list mirrors it, and
    // is patched directly too in case the catalog is mid-reload.
    media.catalog.setFavorite(candidate.id, favorite);
    media.shortlist.setFavorite(candidate.id, favorite);
    unawaited(
      media.discovery.updateCandidate(candidate.copyWith(favorite: favorite)),
    );
  }

  Future<CatalogCandidate?> _loadDetails(CatalogCandidate candidate) async =>
      (await _owner(candidate).catalog.loadDetails(candidate.id)).value;

  Future<CatalogSeriesProgress?> _loadSeriesProgress(
    CatalogCandidate series,
  ) async => (await _owner(series).catalog.loadSeriesProgress(series.id)).value;

  Future<bool> _openTrailer(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  void _retry() {
    if (_available.isEmpty) {
      unawaited(_checkAvailability());
    }
    unawaited(_loadCatalog(_active, _active.discovery.state));
  }
}

final class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: AppLocalizations.of(context).catalogLoadingLabel,
          child: const CircularProgressIndicator(),
        ),
      ),
    ),
  );
}

final class _CatalogError extends StatelessWidget {
  const _CatalogError({
    required this.onReconnect,
    this.switchTo,
    this.onSwitch,
  });

  final VoidCallback onReconnect;

  /// The other kind of title, offered so a failing one is not a dead end.
  final CatalogMediaType? switchTo;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(CandySpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: CandySpacing.compact,
              children: <Widget>[
                const Icon(Icons.cloud_off_outlined),
                Text(
                  localization.catalogErrorTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                Text(
                  localization.catalogErrorDescription,
                  textAlign: TextAlign.center,
                ),
                FilledButton.icon(
                  onPressed: onReconnect,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(localization.catalogReconnectLabel),
                ),
                if ((switchTo, onSwitch) case (final type?, final onTap?))
                  TextButton(
                    onPressed: onTap,
                    child: Text(
                      type == CatalogMediaType.series
                          ? localization.discoveryShowShowsTooltip
                          : localization.discoveryShowMoviesTooltip,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
