import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfin_picker/core/keys/widget_keys.dart';
import 'package:jellyfin_picker/core/media/entities/catalog_candidate.dart';
import 'package:jellyfin_picker/core/theme/candy_theme.dart';
import 'package:jellyfin_picker/core/widgets/candy_bounce.dart';
import 'package:jellyfin_picker/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfin_picker/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfin_picker/features/discovery/presentation/widgets/discovery_empty_state.dart';
import 'package:jellyfin_picker/l10n/generated/app_localizations.dart';

enum _SwipeVerdict { like, nope }

/// A dating-app style card stack: drag the top card, it tilts and stamps
/// LIKE or NOPE; release past the threshold (or flick) to send it flying.
final class DiscoverySwipe extends StatefulWidget {
  const DiscoverySwipe({
    required this.candidates,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.imageHeaders = const <String, String>{},
    super.key,
  });

  final List<CatalogCandidate> candidates;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Map<String, String> imageHeaders;

  @override
  State<DiscoverySwipe> createState() => _DiscoverySwipeState();
}

final class _DiscoverySwipeState extends State<DiscoverySwipe>
    with SingleTickerProviderStateMixin {
  /// Fraction of the deck width a drag must travel to count on release.
  static const _commitFraction = 0.28;

  /// Horizontal fling speed (logical px/s) that counts regardless of travel.
  static const _flingVelocity = 900.0;

  /// Tilt in radians per deck-width of horizontal travel (~20° at the edge).
  static const _tiltPerWidth = 0.35;

  /// Room below the top card where the waiting cards peek out.
  static const _peek = 20.0;

  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(_onAnimate);
  Animation<Offset>? _animation;
  Offset _drag = Offset.zero;
  Size _deck = Size.zero;
  bool _dragging = false;
  bool _pastThreshold = false;

  /// The id of a card that has flown out and is waiting for the cubit to
  /// drop it; it stays off-screen until the list updates.
  String? _departedId;

  @override
  void didUpdateWidget(covariant DiscoverySwipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    final departed = _departedId;
    if (departed != null && widget.candidates.firstOrNull?.id != departed) {
      _departedId = null;
      _drag = Offset.zero;
      _pastThreshold = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  double get _threshold => math.max(1, _deck.width * _commitFraction);

  /// 0 at rest, 1 once the drag reaches the commit threshold.
  double get _progress => (_drag.dx.abs() / _threshold).clamp(0.0, 1.0);

  void _onAnimate() {
    final animation = _animation;
    if (animation != null) {
      setState(() => _drag = animation.value);
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_departedId != null) {
      return;
    }
    _controller.stop();
    _dragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_dragging) {
      return;
    }
    setState(() => _drag += details.delta);
    final past = _drag.dx.abs() >= _threshold;
    if (past != _pastThreshold) {
      _pastThreshold = past;
      if (past) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_dragging) {
      return;
    }
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond;
    final flung =
        velocity.dx.abs() >= _flingVelocity &&
        velocity.dx.sign == _drag.dx.sign;
    if (_drag.dx.abs() >= _threshold || flung) {
      _flyOut(
        _drag.dx > 0 ? _SwipeVerdict.like : _SwipeVerdict.nope,
        velocity: velocity,
      );
    } else {
      _springBack();
    }
  }

  void _springBack() {
    _pastThreshold = false;
    if (_reduceMotion) {
      setState(() => _drag = Offset.zero);
      return;
    }
    _animate(
      to: Offset.zero,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
    );
  }

  /// Sends the top card off-screen, then records the decision.
  void _flyOut(_SwipeVerdict verdict, {Offset velocity = Offset.zero}) {
    final candidate = widget.candidates.firstOrNull;
    if (candidate == null || _departedId != null) {
      return;
    }
    _departedId = candidate.id;
    _dragging = false;
    unawaited(
      verdict == _SwipeVerdict.like
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.lightImpact(),
    );
    void commit() {
      final cubit = context.read<DiscoveryCubit>();
      unawaited(
        verdict == _SwipeVerdict.like
            ? cubit.like(candidate.id)
            : cubit.reject(candidate.id),
      );
    }

    final direction = verdict == _SwipeVerdict.like ? 1.0 : -1.0;
    final width = math.max(_deck.width, 1.0);
    final target = Offset(
      direction * width * 1.5,
      // Keep the card's vertical momentum so a diagonal flick arcs away.
      _drag.dy + (velocity.dy * 0.12).clamp(-width * 0.6, width * 0.6),
    );
    if (_reduceMotion) {
      setState(() => _drag = target);
      commit();
      return;
    }
    // Faster flicks leave faster; a button press uses a measured exit.
    final speed = velocity.dx.abs();
    final duration = Duration(
      milliseconds: speed > _flingVelocity
          ? (260 - (speed - _flingVelocity) / 30).clamp(160, 260).round()
          : 300,
    );
    _animate(
      to: target,
      duration: duration,
      curve: Curves.easeOutCubic,
      onDone: commit,
    );
  }

  void _animate({
    required Offset to,
    required Duration duration,
    required Curve curve,
    VoidCallback? onDone,
  }) {
    _animation = Tween<Offset>(
      begin: _drag,
      end: to,
    ).chain(CurveTween(curve: curve)).animate(_controller);
    _controller
      ..duration = duration
      ..reset();
    _controller.forward().whenCompleteOrCancel(() {
      if (mounted && _controller.isCompleted) {
        onDone?.call();
      }
    });
  }

  /// Button press: lean the card toward the verdict, then fling it.
  void _decide(_SwipeVerdict verdict) {
    if (_departedId != null) {
      return;
    }
    _controller.stop();
    _flyOut(verdict);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.candidates;
    if (candidates.isEmpty) {
      return const DiscoveryEmptyState();
    }
    final top = candidates.first;
    final next = candidates.length > 1 ? candidates[1] : null;
    final third = candidates.length > 2 ? candidates[2] : null;
    final reduceMotion = _reduceMotion;
    final progress = _progress;
    final leaning = _drag.dx == 0
        ? null
        : _drag.dx > 0
        ? _SwipeVerdict.like
        : _SwipeVerdict.nope;
    return Column(
      key: WidgetKeys.discoverySwipeDeck,
      spacing: CandySpacing.cardGap,
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _deck = constraints.biggest;
              final tilt = reduceMotion
                  ? 0.0
                  : (_drag.dx / math.max(_deck.width, 1)).clamp(-1.0, 1.0) *
                        _tiltPerWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  if (third != null)
                    _BackCard(
                      key: ValueKey<String>('back-${third.id}'),
                      depth: 2 - progress,
                      child: _card(third),
                    ),
                  if (next != null)
                    _BackCard(
                      key: ValueKey<String>('back-${next.id}'),
                      depth: 1 - progress,
                      child: _card(next),
                    ),
                  Positioned(
                    key: ValueKey<String>('top-${top.id}'),
                    left: 0,
                    top: 0,
                    right: 0,
                    bottom: _peek,
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      onPanCancel: () {
                        if (_dragging) {
                          _dragging = false;
                          _springBack();
                        }
                      },
                      child: Transform.translate(
                        offset: _drag,
                        child: Transform.rotate(
                          // Pivot below the card, like a card held at its base.
                          angle: tilt,
                          alignment: const Alignment(0, 1.8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              _card(top, interactive: true),
                              _Stamp(
                                verdict: _SwipeVerdict.like,
                                opacity: leaning == _SwipeVerdict.like
                                    ? progress
                                    : 0,
                              ),
                              _Stamp(
                                verdict: _SwipeVerdict.nope,
                                opacity: leaning == _SwipeVerdict.nope
                                    ? progress
                                    : 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _SwipeButtons(
          leaning: leaning,
          progress: progress,
          onNope: () => _decide(_SwipeVerdict.nope),
          onLike: () => _decide(_SwipeVerdict.like),
          onDetails: () => _openDetails(top),
          onOrganize: switch (DiscoveryOrganizerScope.maybeOf(context)) {
            final organize? => () => unawaited(organize(context, top)),
            null => null,
          },
        ),
      ],
    );
  }

  void _openDetails(CatalogCandidate candidate) => unawaited(
    showDiscoveryDetails(
      context,
      candidate,
      onLoadDetails: widget.onLoadDetails,
      onOpenTrailer: widget.onOpenTrailer,
      imageHeaders: widget.imageHeaders,
    ),
  );

  Widget _card(CatalogCandidate candidate, {bool interactive = false}) {
    final card = _SwipeCard(
      candidate: candidate,
      onToggleFavorite: widget.onToggleFavorite,
      onOpenDetails: () => _openDetails(candidate),
      imageHeaders: widget.imageHeaders,
      elevated: interactive,
    );
    // Dragging only moves an already-painted layer; the poster isn't redrawn.
    final layer = RepaintBoundary(child: card);
    return interactive
        ? layer
        : IgnorePointer(child: ExcludeSemantics(child: layer));
  }
}

/// A solid, full-bleed card: poster edge to edge, title over a dark fade.
final class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.candidate,
    required this.onToggleFavorite,
    required this.onOpenDetails,
    required this.imageHeaders,
    required this.elevated,
  });

  final CatalogCandidate candidate;
  final FavoriteToggle? onToggleFavorite;
  final VoidCallback onOpenDetails;
  final Map<String, String> imageHeaders;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(CandyShapes.card);
    final meta = discoveryMetaLine(l10n, candidate);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevated
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Semantics(
          label: l10n.discoveryDetailsLabel(candidate.name),
          child: CandyBounce(
            key: WidgetKeys.discoveryCandidate(candidate.id),
            onPressed: onOpenDetails,
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  DiscoveryWatchedFade(
                    candidate: candidate,
                    child: DiscoveryPoster(
                      candidate: candidate,
                      headers: imageHeaders,
                      fit: BoxFit.contain,
                      showFallbackTitle: false,
                    ),
                  ),
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0x00000000),
                            Color(0x00000000),
                            Color(0xE6000000),
                          ],
                          stops: <double>[0, 0.55, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: CandySpacing.page,
                    right: CandySpacing.compact,
                    bottom: CandySpacing.cardGap,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                candidate.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  height: 1.15,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Color(0x99000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              if (meta.isNotEmpty)
                                Text(
                                  meta,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFFE9E2D8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DiscoveryFavoriteButton(
                          candidate: candidate,
                          onToggleFavorite: onToggleFavorite,
                          idleColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A waiting card: slightly smaller and dimmer, rising as the top card
/// leaves. [depth] is 0 when it is about to become the top card.
final class _BackCard extends StatelessWidget {
  const _BackCard({required this.depth, required this.child, super.key});

  final double depth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clamped = depth.clamp(0.0, 2.0);
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: _DiscoverySwipeState._peek,
      child: Transform.translate(
        offset: Offset(0, 10 * clamped),
        child: Transform.scale(
          scale: 1 - 0.05 * clamped,
          alignment: Alignment.bottomCenter,
          // A dimming veil is cheaper per frame than an Opacity layer.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CandyShapes.card),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                child,
                IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: 0.4 * clamped.clamp(0.0, 1.0),
                    ),
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

final class _Stamp extends StatelessWidget {
  const _Stamp({required this.verdict, required this.opacity});

  final _SwipeVerdict verdict;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final like = verdict == _SwipeVerdict.like;
    final color = like ? scheme.primary : scheme.error;
    return IgnorePointer(
      child: Align(
        // A LIKE stamp sits on the side the card is moving away from, so it
        // stays on-screen and readable, as on dating apps.
        alignment: like
            ? const Alignment(-0.8, -0.78)
            : const Alignment(0.8, -0.78),
        child: Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: like ? -0.3 : 0.3,
            child: Transform.scale(
              scale: 1.25 - 0.25 * opacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CandyColors.background.withValues(alpha: 0.45),
                  border: Border.all(color: color, width: 4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Text(
                    like
                        ? l10n.discoverySwipeLikeStamp
                        : l10n.discoverySwipeNopeStamp,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round action buttons; the one matching the drag direction swells.
final class _SwipeButtons extends StatelessWidget {
  const _SwipeButtons({
    required this.leaning,
    required this.progress,
    required this.onNope,
    required this.onLike,
    required this.onDetails,
    this.onOrganize,
  });

  final VoidCallback? onOrganize;

  final _SwipeVerdict? leaning;
  final double progress;
  final VoidCallback onNope;
  final VoidCallback onLike;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    double scaleFor(_SwipeVerdict verdict) => leaning == verdict
        ? 1 + 0.18 * progress
        : 1 - 0.08 * (leaning == null ? 0 : progress);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: CandySpacing.cardGap,
      children: <Widget>[
        Transform.scale(
          scale: scaleFor(_SwipeVerdict.nope),
          child: _RoundButton(
            key: WidgetKeys.discoverySwipeReject,
            tooltip: l10n.discoveryRejectLabel,
            icon: Icons.close_rounded,
            size: 64,
            foreground: scheme.error,
            background: CandyColors.surface,
            border: scheme.error,
            fill: leaning == _SwipeVerdict.nope ? progress : 0,
            onPressed: onNope,
          ),
        ),
        _RoundButton(
          key: WidgetKeys.discoverySwipeInfo,
          tooltip: l10n.discoverySwipeInfoLabel,
          icon: Icons.info_outline_rounded,
          size: 48,
          foreground: scheme.onSurfaceVariant,
          background: CandyColors.surface,
          border: CandyColors.outline,
          fill: 0,
          onPressed: onDetails,
        ),
        if (onOrganize case final organize?)
          _RoundButton(
            key: WidgetKeys.discoveryOrganizeButton,
            tooltip: l10n.discoveryOrganizeLabel,
            icon: Icons.playlist_add_rounded,
            size: 48,
            foreground: scheme.onSurfaceVariant,
            background: CandyColors.surface,
            border: CandyColors.outline,
            fill: 0,
            onPressed: organize,
          ),
        Transform.scale(
          scale: scaleFor(_SwipeVerdict.like),
          child: _RoundButton(
            key: WidgetKeys.discoverySwipeLike,
            tooltip: l10n.discoveryLikeLabel,
            icon: Icons.favorite_rounded,
            size: 64,
            foreground: scheme.primary,
            background: CandyColors.surface,
            border: scheme.primary,
            fill: leaning == _SwipeVerdict.like ? progress : 0,
            onPressed: onLike,
          ),
        ),
      ],
    );
  }
}

final class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.foreground,
    required this.background,
    required this.border,
    required this.fill,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final double size;
  final Color foreground;
  final Color background;
  final Color border;

  /// 0–1: how far the button has flooded with its accent color.
  final double fill;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final filled = Color.lerp(background, foreground, fill) ?? background;
    final iconColor =
        Color.lerp(foreground, CandyColors.contrastInk, fill) ?? foreground;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled,
        shape: CircleBorder(side: BorderSide(color: border, width: 2)),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              color: iconColor,
              size: size * 0.45,
              semanticLabel: tooltip,
            ),
          ),
        ),
      ),
    );
  }
}
