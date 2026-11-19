import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/core/widgets/candy_bounce.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Shuffle mode: a single-reel slot machine that spins through eligible
/// posters and locks onto the randomly selected pick.
final class DiscoveryShuffle extends StatefulWidget {
  const DiscoveryShuffle({
    required this.state,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.imageHeaders = const <String, String>{},
    super.key,
  });

  final DiscoveryState state;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Map<String, String> imageHeaders;

  @override
  State<DiscoveryShuffle> createState() => _DiscoveryShuffleState();
}

final class _DiscoveryShuffleState extends State<DiscoveryShuffle>
    with SingleTickerProviderStateMixin {
  /// Built on first use: a shuffle screen that never spins must not own a
  /// ticker, and `dispose` must never create one on a dead element.
  AnimationController? _controllerOrNull;
  AnimationController get _controller => _controllerOrNull ??=
      AnimationController(vsync: this, duration: CandyMotion.reelSpin)
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);
  final math.Random _random = math.Random();
  final Stopwatch _hapticClock = Stopwatch()..start();

  /// Posters on the reel, top to bottom; the last entry is the pick.
  List<CatalogCandidate> _reel = const <CatalogCandidate>[];
  Animation<double> _position = const AlwaysStoppedAnimation<double>(0);
  int _landings = 0;
  int _lastTickIndex = 0;
  int _lastHapticMs = -1000;
  double _lastPosition = 0;
  int _lastElapsedUs = 0;
  double _blur = 0;

  bool get _spinning => _reel.isNotEmpty;

  @override
  void didUpdateWidget(covariant DiscoveryShuffle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Something outside the reel (filters, a dismissal, a refill) replaced
    // the pick mid-spin: stop rather than land on a stale title.
    if (_spinning && widget.state.currentRevealId != _reel.last.id) {
      _stopReel();
    }
  }

  @override
  void dispose() {
    _controllerOrNull?.dispose();
    _controllerOrNull = null;
    super.dispose();
  }

  void _spin() {
    final cubit = context.read<DiscoveryCubit>();
    final previous = _candidateIn(cubit.state);
    // revealNext emits synchronously, so the new pick is readable right away.
    unawaited(cubit.revealNext());
    final next = cubit.state;
    final target = _candidateIn(next);
    if (target == null) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _landings++);
      return;
    }
    _startSpin(target, previous: previous, pool: next.eligibleCandidates);
  }

  void _startSpin(
    CatalogCandidate target, {
    required CatalogCandidate? previous,
    required List<CatalogCandidate> pool,
  }) {
    final others = pool.where((candidate) => candidate.id != target.id).toList()
      ..shuffle(_random);
    final source = others.isEmpty ? <CatalogCandidate>[target] : others;
    final fillers = <CatalogCandidate>[
      for (var index = 0; index < CandyReel.travel; index++)
        source[index % source.length],
    ];
    // A lead poster sits above the start so the wind-up never shows a gap.
    _reel = <CatalogCandidate>[
      fillers.last,
      previous ?? fillers.first,
      ...fillers,
      target,
    ];
    final end = (_reel.length - 1).toDouble();
    const start = 1.0;
    _position = TweenSequence<double>(<TweenSequenceItem<double>>[
      // Wind-up: the reel pulls back a touch, like a lever being drawn.
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: start,
          end: start - 0.16,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 7,
      ),
      // Release: rapid acceleration, then a long mechanical deceleration
      // that slightly overshoots the payline.
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: start - 0.16,
          end: end + 0.12,
        ).chain(CurveTween(curve: const Cubic(0.33, 0, 0.1, 1))),
        weight: 80,
      ),
      // Lock: the detent pulls the poster back onto the payline.
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: end + 0.12,
          end: end,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 13,
      ),
    ]).animate(_controller);
    _lastTickIndex = start.round();
    _lastPosition = start;
    _lastElapsedUs = 0;
    _blur = 0;
    _precacheReel();
    unawaited(HapticFeedback.lightImpact());
    setState(() {});
    unawaited(_controller.forward(from: 0));
  }

  void _stopReel() {
    _controller.stop();
    setState(() {
      _reel = const <CatalogCandidate>[];
      _blur = 0;
    });
  }

  void _onTick() {
    final position = _position.value;
    final elapsedUs = _controller.lastElapsedDuration?.inMicroseconds ?? 0;
    final deltaUs = elapsedUs - _lastElapsedUs;
    if (deltaUs > 0) {
      // Reel speed in posters per second drives the motion blur.
      final velocity = (position - _lastPosition).abs() / (deltaUs / 1e6);
      _blur = math.min(CandyReel.maxBlurSigma, velocity * 0.55);
    }
    _lastPosition = position;
    _lastElapsedUs = elapsedUs;
    final index = position.round();
    if (index != _lastTickIndex) {
      _lastTickIndex = index;
      final now = _hapticClock.elapsedMilliseconds;
      if (now - _lastHapticMs >= 45) {
        _lastHapticMs = now;
        unawaited(HapticFeedback.selectionClick());
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    unawaited(HapticFeedback.heavyImpact());
    setState(() {
      _reel = const <CatalogCandidate>[];
      _blur = 0;
      _landings++;
    });
  }

  void _precacheReel() {
    final seen = <String>{};
    for (final (index, candidate) in _reel.indexed) {
      final isTarget = index == _reel.length - 1;
      if (!seen.add('${candidate.id}-$isTarget')) {
        continue;
      }
      final provider = _posterProvider(candidate, target: isTarget);
      if (provider != null) {
        unawaited(
          precacheImage(provider, context, onError: (error, stackTrace) {}),
        );
      }
    }
  }

  ImageProvider? _posterProvider(
    CatalogCandidate candidate, {
    required bool target,
  }) {
    final uri = candidate.poster.variantUri(
      maxWidth: target
          ? CandyImages.posterDisplayNetworkWidth
          : CandyReel.posterNetworkWidth,
      quality: target
          ? CandyImages.posterDisplayQuality
          : CandyReel.posterQuality,
    );
    if (uri == null) {
      return null;
    }
    return ResizeImage.resizeIfNeeded(
      target ? CandyImages.posterCacheWidth : CandyReel.posterNetworkWidth,
      null,
      NetworkImage(uri.toString(), headers: widget.imageHeaders),
    );
  }

  CatalogCandidate? _candidateIn(DiscoveryState state) {
    final id = state.currentRevealId;
    if (id == null) {
      return null;
    }
    return state.candidates
        .where((candidate) => candidate.id == id)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final candidate = _candidateIn(widget.state);
    final spinning = _spinning;
    final Widget windowContent;
    if (spinning) {
      windowContent = _ReelStrip(
        reel: _reel,
        position: _position,
        blur: () => _blur,
        headers: widget.imageHeaders,
      );
    } else if (candidate == null) {
      windowContent = _ShuffleIdle(
        key: WidgetKeys.discoveryShufflePlaceholder,
        exhausted:
            widget.state.noEligibleCandidates ||
            widget.state.eligibleCandidates.isEmpty,
      );
    } else {
      windowContent = Semantics(
        label: localization.discoveryDetailsLabel(candidate.name),
        child: CandyBounce(
          key: WidgetKeys.discoveryCandidate(candidate.id),
          onPressed: () => showDiscoveryDetails(
            context,
            candidate,
            onLoadDetails: widget.onLoadDetails,
            onOpenTrailer: widget.onOpenTrailer,
            imageHeaders: widget.imageHeaders,
          ),
          child: DiscoveryWatchedFade(
            candidate: candidate,
            child: DiscoveryPoster(
              candidate: candidate,
              headers: widget.imageHeaders,
              fit: BoxFit.contain,
              fadeIn: false,
              showFallbackTitle: true,
            ),
          ),
        ),
      );
    }

    return Column(
      key: WidgetKeys.discoveryShuffle,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CandySpacing.compact,
      children: <Widget>[
        Expanded(
          child: _ReelWindow(
            landings: _landings,
            spinning: spinning,
            reduceMotion: reduceMotion,
            child: windowContent,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : CandyMotion.standard,
            reverseDuration: reduceMotion ? Duration.zero : CandyMotion.quick,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: <Widget>[...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: spinning || candidate == null
                ? const SizedBox.shrink(key: ValueKey<String>('no-pick'))
                : Semantics(
                    key: WidgetKeys.discoveryShuffleCandidate(candidate.id),
                    container: true,
                    liveRegion: true,
                    label: localization.discoveryShuffleLandedLabel(
                      candidate.name,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: ExcludeSemantics(
                            child: DiscoveryTitleBlock(
                              candidate: candidate,
                              prominent: true,
                            ),
                          ),
                        ),
                        if (DiscoveryOrganizerScope.maybeOf(context)
                            case final organize?)
                          IconButton(
                            key: WidgetKeys.discoveryOrganizeButton,
                            tooltip: localization.discoveryOrganizeLabel,
                            onPressed: () =>
                                unawaited(organize(context, candidate)),
                            icon: const Icon(Icons.playlist_add_rounded),
                          ),
                        DiscoveryFavoriteButton(
                          candidate: candidate,
                          onToggleFavorite: widget.onToggleFavorite,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        _FavoriteBiasControl(
          bias: widget.state.favoriteBias,
          hasFavorites: widget.state.eligibleCandidates.any(
            (candidate) => candidate.favorite == true,
          ),
          enabled: !spinning,
        ),
        FilledButton.icon(
          key: WidgetKeys.discoveryRevealButton,
          onPressed: spinning ? null : _spin,
          icon: const Icon(Icons.casino_rounded),
          label: Text(
            spinning
                ? localization.discoverySpinningLabel
                : candidate == null
                ? localization.discoveryRevealLabel
                : localization.discoverySpinAgainLabel,
          ),
        ),
      ],
    );
  }
}

/// How strongly the reel leans toward Jellyfin favorites.
final class _FavoriteBiasControl extends StatelessWidget {
  const _FavoriteBiasControl({
    required this.bias,
    required this.hasFavorites,
    required this.enabled,
  });

  final double bias;
  final bool hasFavorites;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = (bias * 100).round();
    final active = bias > 0;
    final starved = active && !hasFavorites;
    final valueLabel = active
        ? l10n.discoveryFavorPercent(percent)
        : l10n.discoveryFavorOffLabel;
    return Row(
      children: <Widget>[
        Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 20,
          color: active ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: CandySpacing.compact / 1.5),
        Flexible(
          child: Text(
            starved
                ? l10n.discoveryFavorNoneLabel
                : l10n.discoveryFavorFavoritesLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: starved ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Slider(
            key: WidgetKeys.discoveryFavoriteBias,
            value: bias,
            divisions: 10,
            label: valueLabel,
            semanticFormatterCallback: (value) => value <= 0
                ? l10n.discoveryFavorOffLabel
                : l10n.discoveryFavorSemantic((value * 100).round()),
            onChanged: enabled
                ? (value) =>
                      context.read<DiscoveryCubit>().setFavoriteBias(value)
                : null,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            valueLabel,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelLarge?.copyWith(
              color: active ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// The framed slot window: a payline on both edges and a glow that flares
/// when the reel locks onto a pick.
final class _ReelWindow extends StatelessWidget {
  const _ReelWindow({
    required this.landings,
    required this.spinning,
    required this.reduceMotion,
    required this.child,
  });

  final int landings;
  final bool spinning;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(CandyShapes.card);
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(landings),
      tween: Tween<double>(begin: landings > 0 ? 1 : 0, end: 0),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, glow, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: CandyColors.background,
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.35 * glow),
              blurRadius: 40 * glow,
              spreadRadius: 2 * glow,
              offset: Offset(0, 6 * glow),
            ),
          ],
        ),
        position: DecorationPosition.background,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color:
                  Color.lerp(
                    spinning ? scheme.primary : CandyColors.outline,
                    scheme.primary,
                    glow,
                  ) ??
                  scheme.primary,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            child,
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: spinning ? 1 : 0,
                duration: reduceMotion ? Duration.zero : CandyMotion.standard,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xE6000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0xE6000000),
                      ],
                      stops: <double>[0, 0.22, 0.78, 1],
                    ),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _PaylinePainter(
                  color: spinning
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PaylinePainter extends CustomPainter {
  const _PaylinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const depth = 9.0;
    const half = 8.0;
    final y = size.height / 2;
    final paint = Paint()..color = color;
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, y - half)
          ..lineTo(depth, y)
          ..lineTo(0, y + half)
          ..close(),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(size.width, y - half)
          ..lineTo(size.width - depth, y)
          ..lineTo(size.width, y + half)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_PaylinePainter oldDelegate) => oldDelegate.color != color;
}

/// The moving strip. Only the one or two posters crossing the window are
/// built each frame; speed drives a vertical motion blur.
final class _ReelStrip extends StatelessWidget {
  const _ReelStrip({
    required this.reel,
    required this.position,
    required this.blur,
    required this.headers,
  });

  final List<CatalogCandidate> reel;
  final Animation<double> position;
  final double Function() blur;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return AnimatedBuilder(
            animation: position,
            builder: (context, _) {
              final value = position.value;
              final first = value.floor();
              final items = <Widget>[
                for (var index = first; index <= first + 1; index++)
                  if (index >= 0 && index < reel.length)
                    Positioned(
                      key: ValueKey<int>(index),
                      left: 0,
                      right: 0,
                      top: (index - value) * height,
                      height: height,
                      child: DiscoveryPoster(
                        candidate: reel[index],
                        headers: headers,
                        fit: BoxFit.contain,
                        fadeIn: false,
                        showFallbackTitle: true,
                        networkWidth: index == reel.length - 1
                            ? CandyImages.posterDisplayNetworkWidth
                            : CandyReel.posterNetworkWidth,
                        quality: index == reel.length - 1
                            ? CandyImages.posterDisplayQuality
                            : CandyReel.posterQuality,
                        cacheWidth: index == reel.length - 1
                            ? CandyImages.posterCacheWidth
                            : CandyReel.posterNetworkWidth,
                      ),
                    ),
              ];
              final strip = Stack(clipBehavior: Clip.hardEdge, children: items);
              final sigma = blur();
              if (sigma < 0.5) {
                return strip;
              }
              return ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaY: sigma),
                child: strip,
              );
            },
          );
        },
      ),
    );
  }
}

final class _ShuffleIdle extends StatelessWidget {
  const _ShuffleIdle({required this.exhausted, super.key});

  /// Nothing is left to pick under the current filters and decisions.
  final bool exhausted;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CandySpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: CandySpacing.compact,
          children: <Widget>[
            Icon(
              exhausted ? Icons.filter_alt_off_outlined : Icons.casino_outlined,
              size: CandyIconSize.hero,
              color: exhausted
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.primary,
              semanticLabel: localization.discoveryShuffleLabel,
            ),
            Text(
              exhausted
                  ? localization.discoveryNoCandidatesTitle
                  : localization.discoveryShuffleIdleTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                exhausted
                    ? localization.discoveryNoCandidatesDescription
                    : localization.discoveryShuffleIdleDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
