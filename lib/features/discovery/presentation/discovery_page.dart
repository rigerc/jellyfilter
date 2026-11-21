import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/discovery/application/browse_selection_cubit.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_bulk_playlist_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_clear_dialog.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_controls.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_media_scope.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_mode_selector.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_mode_switcher.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_selection.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_shortlist.dart';

typedef FavoriteToggle = Future<bool> Function(CatalogCandidate candidate);
typedef CandidateDetailsLoader =
    Future<CatalogCandidate?> Function(CatalogCandidate candidate);
typedef TrailerLauncher = Future<bool> Function(Uri uri);

final class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({
    required this.cubit,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.onLoadMore,
    this.onRetryCatalog,
    this.libraries = const <CatalogLibrary>[],
    this.facets = const CatalogFacets(),
    this.imageHeaders = const <String, String>{},
    this.onOrganize,
    this.onAddToPlaylist,
    this.mediaTypes = const <CatalogMediaType>{},
    this.onMediaTypeChanged,
    this.onLoadSeriesProgress,
    super.key,
  });

  /// The kinds of title the server holds; with both, the header offers a
  /// switch that calls [onMediaTypeChanged].
  final Set<CatalogMediaType> mediaTypes;
  final ValueChanged<CatalogMediaType>? onMediaTypeChanged;

  /// Loads seasons and the next episode for a show's details.
  final SeriesProgressLoader? onLoadSeriesProgress;

  /// Opens playlists & tags for a title; null hides those actions.
  final CandidateOrganizer? onOrganize;

  /// Adds the titles selected in Browse to a playlist; null hides it.
  final BulkPlaylistAdder? onAddToPlaylist;
  final DiscoveryCubit cubit;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetryCatalog;
  final List<CatalogLibrary> libraries;
  final CatalogFacets facets;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DiscoveryCubit>.value(value: cubit),
        BlocProvider<BrowseSelectionCubit>(
          create: (_) => BrowseSelectionCubit(),
        ),
      ],
      child: DiscoveryMediaScope(
        mediaType: cubit.mediaType,
        available: mediaTypes,
        onChanged: onMediaTypeChanged,
        loadSeriesProgress: onLoadSeriesProgress,
        child: DiscoveryOrganizerScope(
          organize: onOrganize,
          child: _DiscoveryView(
            onToggleFavorite: onToggleFavorite,
            onAddToPlaylist: onAddToPlaylist,
            onLoadDetails: onLoadDetails,
            onOpenTrailer: onOpenTrailer,
            onLoadMore: onLoadMore,
            onRetryCatalog: onRetryCatalog,
            libraries: libraries,
            facets: facets,
            imageHeaders: imageHeaders,
          ),
        ),
      ),
    );
  }
}

final class _DiscoveryView extends StatelessWidget {
  const _DiscoveryView({
    required this.imageHeaders,
    required this.libraries,
    required this.facets,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.onLoadMore,
    this.onRetryCatalog,
    this.onAddToPlaylist,
  });

  final FavoriteToggle? onToggleFavorite;
  final BulkPlaylistAdder? onAddToPlaylist;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetryCatalog;
  final List<CatalogLibrary> libraries;
  final CatalogFacets facets;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final selecting = context.select(
      (BrowseSelectionCubit selection) => selection.isSelecting,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlocListener<DiscoveryCubit, DiscoveryState>(
      listenWhen: (previous, current) =>
          previous.mode != current.mode ||
          !identical(previous.filteredCandidates, current.filteredCandidates),
      // Selection belongs to Browse and to the titles it currently shows.
      listener: (context, state) {
        final selection = context.read<BrowseSelectionCubit>();
        if (state.mode != DiscoveryMode.grid) {
          selection.clear();
          return;
        }
        selection.retain(state.filteredCandidates.map((movie) => movie.id));
      },
      child: PopScope(
        canPop: !selecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            context.read<BrowseSelectionCubit>().clear();
          }
        },
        child: _scaffold(
          context,
          selecting: selecting,
          reduceMotion: reduceMotion,
        ),
      ),
    );
  }

  Widget _scaffold(
    BuildContext context, {
    required bool selecting,
    required bool reduceMotion,
  }) {
    return Scaffold(
      key: WidgetKeys.discoveryPage,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : CandyMotion.quick,
        child: selecting
            ? DiscoverySelectionActions(
                onToggleFavorite: onToggleFavorite,
                onAddToPlaylist: onAddToPlaylist,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DiscoveryShortlistStrip(imageHeaders: imageHeaders),
                  const DiscoveryModeSelector(),
                ],
              ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CandySpacing.gutter,
            CandySpacing.compact,
            CandySpacing.gutter,
            CandySpacing.compact,
          ),
          child: Column(
            spacing: CandySpacing.cardGap,
            children: <Widget>[
              DiscoveryControls(
                libraries: libraries,
                facets: facets,
                onClear: () => confirmClearDiscovery(context),
              ),
              Expanded(
                child: DiscoveryModeSwitcher(
                  onToggleFavorite: onToggleFavorite,
                  onLoadDetails: onLoadDetails,
                  onOpenTrailer: onOpenTrailer,
                  onLoadMore: onLoadMore,
                  onRetryCatalog: onRetryCatalog,
                  imageHeaders: imageHeaders,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
