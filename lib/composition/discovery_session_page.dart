import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/network/media_browser_authorization.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/catalog/application/catalog_cubit.dart';
import 'package:jellyfilter/features/catalog/data/jellyfin_catalog_repository.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/failures/catalog_failure.dart';
import 'package:jellyfilter/features/connection/domain/entities/stored_session.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/application/random_discovery_selector.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/discovery_store.dart';
import 'package:jellyfilter/features/discovery/domain/serialization/catalog_filter_codec.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/favorites/application/favorite_cubit.dart';
import 'package:jellyfilter/features/favorites/data/jellyfin_favorite_repository.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/persistence/data/shared_preferences_discovery_store.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

final class DiscoverySessionPage extends StatefulWidget {
  const DiscoverySessionPage({
    required this.session,
    required this.client,
    this.onReconnect,
    this.discoveryStore,
    super.key,
  });

  final StoredSession session;
  final http.Client client;
  final VoidCallback? onReconnect;
  final DiscoveryStore? discoveryStore;

  @override
  State<DiscoverySessionPage> createState() => _DiscoverySessionPageState();
}

final class _DiscoverySessionPageState extends State<DiscoverySessionPage>
    with WidgetsBindingObserver {
  /// Minimum gap between favorite syncs triggered by resume or mode changes.
  static const _favoriteSyncInterval = Duration(seconds: 10);

  late final CatalogCubit _catalogCubit;
  late final DiscoveryCubit _discoveryCubit;
  late final FavoriteCubit _favoriteCubit;
  late final LibraryActionsRepository _libraryActions;
  StreamSubscription<DiscoveryState>? _discoverySubscription;
  String? _loadedFilterFingerprint;
  DiscoveryMode? _lastMode;
  DateTime? _lastFavoriteSync;
  bool _syncingFavorites = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    _catalogCubit = CatalogCubit(
      JellyfinCatalogRepository(
        client: widget.client,
        serverUrl: session.serverUrl,
        accessToken: session.accessToken,
        deviceId: session.deviceId,
        userId: session.userId,
      ),
    );
    _discoveryCubit = DiscoveryCubit(
      store:
          widget.discoveryStore ??
          SharedPreferencesDiscoveryStore(
            SharedPreferencesAsyncBlobPreferences(),
          ),
      scopeKey: '${session.serverUrl}/${session.userId}',
      selector: RandomDiscoverySelector(),
    );
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Favorites may have changed in another Jellyfin app while we were away.
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncFavorites());
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
      await _catalogCubit.syncFavorites();
    } finally {
      _syncingFavorites = false;
    }
  }

  Future<void> _start() async {
    await _discoveryCubit.hydrate();
    _lastMode = _discoveryCubit.state.mode;
    _discoverySubscription = _discoveryCubit.stream.listen(
      _reloadWhenDiscoveryChanges,
    );
    await _loadCatalog(_discoveryCubit.state);
  }

  void _reloadWhenDiscoveryChanges(DiscoveryState state) {
    final modeChanged = state.mode != _lastMode;
    _lastMode = state.mode;
    final fingerprint = _fingerprint(state);
    if (fingerprint != _loadedFilterFingerprint) {
      unawaited(_loadCatalog(state));
      return;
    }
    if (modeChanged) {
      unawaited(_syncFavorites());
    }
  }

  Future<void> _loadCatalog(DiscoveryState state) async {
    _loadedFilterFingerprint = _fingerprint(state);
    await _catalogCubit.load(filter: state.filter, loadAllPages: true);
  }

  String _fingerprint(DiscoveryState state) =>
      CatalogFilterCodec.encode(state.filter).toString();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_catalogCubit.close());
    unawaited(_discoveryCubit.close());
    unawaited(_favoriteCubit.close());
    unawaited(_discoverySubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return MultiBlocProvider(
      providers: [
        BlocProvider<CatalogCubit>.value(value: _catalogCubit),
        BlocProvider<FavoriteCubit>.value(value: _favoriteCubit),
      ],
      child: BlocConsumer<CatalogCubit, CatalogState>(
        listenWhen: (previous, current) => switch ((previous, current)) {
          (
            CatalogLoaded(candidates: final before),
            CatalogLoaded(candidates: final after),
          ) =>
            !identical(before, after),
          (_, CatalogLoaded()) => true,
          _ => false,
        },
        listener: (context, state) {
          if (state case CatalogLoaded(:final candidates)) {
            unawaited(_discoveryCubit.replaceCandidates(candidates));
          }
        },
        builder: (context, state) {
          final loading = switch (state) {
            CatalogLoading() || CatalogLoaded(loadingMore: true) => true,
            _ => false,
          };
          final failedWithoutCandidates = switch (state) {
            CatalogLoaded(candidates: final values, failure: final failure) =>
              values.isEmpty &&
                  failure != null &&
                  failure is! NoCatalogMatchFailure,
            _ => false,
          };
          if (failedWithoutCandidates) {
            return _CatalogError(onReconnect: widget.onReconnect ?? _retry);
          }
          if (state is CatalogLoading &&
              _discoveryCubit.state.candidates.isEmpty) {
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
                  onTagsSaved: _catalogCubit.setTags,
                ),
                cubit: _discoveryCubit,
                libraries: state is CatalogLoaded ? state.libraries : const [],
                facets: state is CatalogLoaded
                    ? state.facets
                    : const CatalogFacets(),
                onLoadMore: _catalogCubit.loadMore,
                onLoadDetails: _loadDetails,
                onOpenTrailer: _openTrailer,
                imageHeaders: <String, String>{
                  'Authorization': MediaBrowserAuthorization.value(
                    deviceId: session.deviceId,
                    token: session.accessToken,
                  ),
                },
                onToggleFavorite: _toggleFavorite,
              ),
              if (loading) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }

  /// Flips a favorite instantly, confirms it with Jellyfin, and rolls back
  /// on failure. A newer tap on the same title owns the final outcome.
  Future<bool> _toggleFavorite(CatalogCandidate candidate) async {
    final current =
        _catalogCubit.favoriteOf(candidate.id) ?? candidate.favorite == true;
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
    // The catalog is the source of truth; the discovery list mirrors it, and
    // is patched directly too in case the catalog is mid-reload.
    _catalogCubit.setFavorite(candidate.id, favorite);
    unawaited(
      _discoveryCubit.updateCandidate(candidate.copyWith(favorite: favorite)),
    );
  }

  Future<CatalogCandidate?> _loadDetails(CatalogCandidate candidate) async =>
      (await _catalogCubit.loadDetails(candidate.id)).value;

  Future<bool> _openTrailer(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  void _retry() => unawaited(_loadCatalog(_discoveryCubit.state));
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
  const _CatalogError({required this.onReconnect});

  final VoidCallback onReconnect;

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
