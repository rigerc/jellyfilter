import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_empty_state.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_load_more.dart';

final class DiscoveryGrid extends StatefulWidget {
  const DiscoveryGrid({
    required this.candidates,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.onLoadMore,
    this.initialIndex = 0,
    this.onTopIndexChanged,
    this.imageHeaders = const <String, String>{},
    super.key,
  });

  final List<CatalogCandidate> candidates;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Future<void> Function()? onLoadMore;

  /// Title to start scrolled to, so switching layouts keeps your place.
  final int initialIndex;

  /// Reports the first title that is mostly in view as the grid scrolls.
  final ValueChanged<int>? onTopIndexChanged;
  final Map<String, String> imageHeaders;

  @override
  State<DiscoveryGrid> createState() => _DiscoveryGridState();
}

final class _DiscoveryGridState extends State<DiscoveryGrid> {
  static const _mainAxisSpacing = CandySpacing.page;
  static const _crossAxisSpacing = CandySpacing.compact;

  ScrollController? _controller;
  int _columns = 2;
  double _rowStride = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _reportTopIndex() {
    final controller = _controller;
    final count = widget.candidates.length;
    if (controller == null || !controller.hasClients || _rowStride <= 0) {
      return;
    }
    if (count == 0) {
      return;
    }
    final row = ((controller.offset + _rowStride / 2) / _rowStride).floor();
    widget.onTopIndexChanged?.call((row * _columns).clamp(0, count - 1));
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.candidates;
    if (candidates.isEmpty) {
      return const DiscoveryEmptyState();
    }
    final width = MediaQuery.sizeOf(context).width;
    _columns = width >= 700
        ? 4
        : width >= 480
        ? 3
        : 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.maxWidth - (_columns - 1) * _crossAxisSpacing) /
            _columns;
        _rowStride = tileWidth / CandyShapes.gridCardRatio + _mainAxisSpacing;
        final controller = _controller ??= ScrollController(
          initialScrollOffset: (widget.initialIndex ~/ _columns) * _rowStride,
        )..addListener(_reportTopIndex);
        return DiscoveryLoadMore(
          onLoadMore: widget.onLoadMore,
          child: GridView.builder(
            key: WidgetKeys.discoveryGrid,
            controller: controller,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              mainAxisSpacing: _mainAxisSpacing,
              crossAxisSpacing: _crossAxisSpacing,
              childAspectRatio: CandyShapes.gridCardRatio,
            ),
            itemCount: candidates.length,
            itemBuilder: (context, index) => RepaintBoundary(
              key: ValueKey<String>(candidates[index].id),
              child: DiscoveryCandidateCard(
                candidate: candidates[index],
                onToggleFavorite: widget.onToggleFavorite,
                onLoadDetails: widget.onLoadDetails,
                onOpenTrailer: widget.onOpenTrailer,
                imageHeaders: widget.imageHeaders,
              ),
            ),
          ),
        );
      },
    );
  }
}
