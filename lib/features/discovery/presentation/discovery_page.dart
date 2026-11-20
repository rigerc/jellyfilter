import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_clear_dialog.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_controls.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_mode_selector.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_mode_switcher.dart';
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
    super.key,
  });

  /// Opens playlists & tags for a title; null hides those actions.
  final CandidateOrganizer? onOrganize;
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
    return BlocProvider.value(
      value: cubit,
      child: DiscoveryOrganizerScope(
        organize: onOrganize,
        child: _DiscoveryView(
          onToggleFavorite: onToggleFavorite,
          onLoadDetails: onLoadDetails,
          onOpenTrailer: onOpenTrailer,
          onLoadMore: onLoadMore,
          onRetryCatalog: onRetryCatalog,
          libraries: libraries,
          facets: facets,
          imageHeaders: imageHeaders,
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
  });

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
    return Scaffold(
      key: WidgetKeys.discoveryPage,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DiscoveryShortlistStrip(imageHeaders: imageHeaders),
          const DiscoveryModeSelector(),
        ],
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
