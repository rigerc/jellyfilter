import 'package:flutter/material.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/domain/entities/browse_layout.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_grid.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_list.dart';

/// The Browse tab: the same titles as poster tiles or as a list, keeping the
/// title at the top of the screen in view when the layout changes.
final class DiscoveryBrowse extends StatefulWidget {
  const DiscoveryBrowse({
    required this.candidates,
    required this.layout,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.onLoadMore,
    this.imageHeaders = const <String, String>{},
    super.key,
  });

  final List<CatalogCandidate> candidates;
  final BrowseLayout layout;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Future<void> Function()? onLoadMore;
  final Map<String, String> imageHeaders;

  @override
  State<DiscoveryBrowse> createState() => _DiscoveryBrowseState();
}

final class _DiscoveryBrowseState extends State<DiscoveryBrowse> {
  /// Read when a layout is built; scrolling only updates it, so it never
  /// rebuilds anything.
  int _topIndex = 0;

  void _onTopIndexChanged(int index) => _topIndex = index;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final layout = widget.layout;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : CandyMotion.standard,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(
        key: ValueKey<BrowseLayout>(layout),
        child: switch (layout) {
          BrowseLayout.grid => DiscoveryGrid(
            candidates: widget.candidates,
            onToggleFavorite: widget.onToggleFavorite,
            onLoadDetails: widget.onLoadDetails,
            onOpenTrailer: widget.onOpenTrailer,
            onLoadMore: widget.onLoadMore,
            initialIndex: _topIndex,
            onTopIndexChanged: _onTopIndexChanged,
            imageHeaders: widget.imageHeaders,
          ),
          BrowseLayout.list => DiscoveryList(
            candidates: widget.candidates,
            onToggleFavorite: widget.onToggleFavorite,
            onLoadDetails: widget.onLoadDetails,
            onOpenTrailer: widget.onOpenTrailer,
            onLoadMore: widget.onLoadMore,
            initialIndex: _topIndex,
            onTopIndexChanged: _onTopIndexChanged,
            imageHeaders: widget.imageHeaders,
          ),
        },
      ),
    );
  }
}
