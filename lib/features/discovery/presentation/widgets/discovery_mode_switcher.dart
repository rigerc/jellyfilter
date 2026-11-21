import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_browse.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_shuffle.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_swipe.dart';

final class DiscoveryModeSwitcher extends StatelessWidget {
  const DiscoveryModeSwitcher({
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.onLoadMore,
    this.onRetryCatalog,
    this.imageHeaders = const <String, String>{},
    super.key,
  });

  final Future<bool> Function(CatalogCandidate candidate)? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetryCatalog;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlocBuilder<DiscoveryCubit, DiscoveryState>(
      builder: (context, state) => AnimatedSwitcher(
        key: WidgetKeys.discoveryModeTransition,
        duration: reduceMotion ? Duration.zero : CandyMotion.standard,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey<DiscoveryMode>(state.mode),
          child: switch (state.mode) {
            DiscoveryMode.grid => DiscoveryBrowse(
              candidates: state.filteredCandidates,
              layout: state.browseLayout,
              onToggleFavorite: onToggleFavorite,
              onLoadDetails: onLoadDetails,
              onOpenTrailer: onOpenTrailer,
              onLoadMore: onLoadMore,
              imageHeaders: imageHeaders,
            ),
            DiscoveryMode.swipe => DiscoverySwipe(
              candidates: state.undecidedCandidates,
              onToggleFavorite: onToggleFavorite,
              onLoadDetails: onLoadDetails,
              onOpenTrailer: onOpenTrailer,
              imageHeaders: imageHeaders,
            ),
            DiscoveryMode.shuffle => Builder(
              builder: (context) => DiscoveryShuffle(
                state: state,
                shortlist: context.watch<ShortlistCubit?>()?.state,
                onRetryCatalog: onRetryCatalog,
                onToggleFavorite: onToggleFavorite,
                onLoadDetails: onLoadDetails,
                onOpenTrailer: onOpenTrailer,
                imageHeaders: imageHeaders,
              ),
            ),
          },
        ),
      ),
    );
  }
}
