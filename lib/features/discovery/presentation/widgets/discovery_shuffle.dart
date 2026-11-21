import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/core/widgets/candy_bounce.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/domain/entities/shuffle_duration.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/shuffle_reel_motion.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

enum _ShuffleSource { filtered, forYou, shortlist }

/// Shuffle mode: a single-reel slot machine that spins through eligible
/// posters and locks onto the randomly selected pick.
final class DiscoveryShuffle extends StatefulWidget {
  const DiscoveryShuffle({
    required this.state,
    this.shortlist,
    this.onRetryCatalog,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.imageHeaders = const <String, String>{},
    super.key,
  });

  final DiscoveryState state;
  final ShortlistState? shortlist;
  final VoidCallback? onRetryCatalog;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Map<String, String> imageHeaders;

  @override
  State<DiscoveryShuffle> createState() => _DiscoveryShuffleState();
}

final class _DiscoveryShuffleState extends State<DiscoveryShuffle>
    with SingleTickerProviderStateMixin {
  static const _spinDragDistance = 48.0;

  /// Built on first use: a shuffle screen that never spins must not own a
  /// ticker, and `dispose` must never create one on a dead element.
  AnimationController? _controllerOrNull;
  AnimationController get _controller => _controllerOrNull ??=
      AnimationController(
          vsync: this,
          duration: widget.state.shuffleDuration.duration,
        )
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
  ShuffleReelMotion? _motion;
  double _blur = 0;

  /// The reel has stopped travelling and is easing back onto the pick.
  bool _settling = false;
  Offset? _dragOrigin;

  bool get _spinning => _reel.isNotEmpty;
  bool get _usesShortlist => widget.shortlist?.useShortlist ?? false;

  @override
  void didUpdateWidget(covariant DiscoveryShuffle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Something outside the reel (filters, a dismissal, a refill) replaced
    // the pick mid-spin: stop rather than land on a stale title.
    final pickId = _usesShortlist
        ? widget.shortlist?.pick?.id
        : widget.state.currentRevealId;
    if (_spinning && pickId != _reel.last.id) {
      _stopReel();
    }
  }

  @override
  void dispose() {
    _controllerOrNull?.dispose();
    _controllerOrNull = null;
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final origin = _dragOrigin;
    if (origin == null ||
        (details.localPosition - origin).distance < _spinDragDistance) {
      return;
    }
    _dragOrigin = null;
    _spin();
  }

  void _spin() {
    if (_spinning) {
      return;
    }
    final cubit = context.read<DiscoveryCubit>();
    if (_usesShortlist) {
      final shortlist = context.read<ShortlistCubit>();
      final previous = shortlist.state.pick;
      final pool = shortlist.state.pool;
      final target = shortlist.revealNext();
      if (target != null) {
        _reveal(
          target,
          previous: previous,
          pool: pool,
          immediate: pool.length == 1,
        );
      }
      return;
    }
    final previous = _candidateIn(cubit.state);
    // revealNext emits synchronously, so the new pick is readable right away.
    unawaited(cubit.revealNext());
    final next = cubit.state;
    final target = _candidateIn(next);
    if (target != null) {
      _reveal(target, previous: previous, pool: next.eligibleCandidates);
    }
  }

  void _reveal(
    CatalogCandidate target, {
    required CatalogCandidate? previous,
    required List<CatalogCandidate> pool,
    bool immediate = false,
  }) {
    final duration = widget.state.shuffleDuration;
    if (immediate ||
        MediaQuery.disableAnimationsOf(context) ||
        duration == ShuffleDuration.instant) {
      unawaited(HapticFeedback.mediumImpact());
      setState(() => _landings++);
      return;
    }
    _controller.duration = duration.duration;
    _startSpin(target, previous: previous, pool: pool);
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
    final motion = ShuffleReelMotion(
      end: (_reel.length - 1).toDouble(),
      duration: _controller.duration ?? Duration.zero,
    );
    _motion = motion;
    _position = motion.position.animate(_controller);
    _lastTickIndex = ShuffleReelMotion.start.round();
    _blur = 0;
    _settling = false;
    _precacheReel();
    unawaited(HapticFeedback.lightImpact());
    setState(() {});
    unawaited(_controller.forward(from: 0));
  }

  void _stopReel() {
    _controller.stop();
    setState(() {
      _reel = const <CatalogCandidate>[];
      _motion = null;
      _blur = 0;
      _settling = false;
    });
  }

  void _onTick() {
    final progress = _controller.value;
    _blur = _motion?.blurSigma(progress) ?? 0;
    final settling = progress >= ShuffleReelMotion.settleStart;
    if (settling != _settling) {
      // Lift the edge shading while the poster settles, so the frame is
      // clear by the time it lands.
      setState(() => _settling = settling);
    }
    final index = _position.value.round();
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
      _motion = null;
      _blur = 0;
      _settling = false;
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
    final shortlist = widget.shortlist;
    final usesShortlist = _usesShortlist;
    final pool = usesShortlist
        ? shortlist?.pool ?? const <CatalogCandidate>[]
        : widget.state.eligibleCandidates;
    final candidate = usesShortlist
        ? shortlist?.pick
        : _candidateIn(widget.state);
    final directReveal = usesShortlist && pool.length == 1;
    final spinning = _spinning;
    final canSpin =
        !spinning &&
        (usesShortlist ? pool.isNotEmpty : widget.onRetryCatalog == null);
    final canDrag = canSpin && pool.isNotEmpty;
    final Widget windowContent;
    if (spinning) {
      windowContent = _ReelStrip(
        reel: _reel,
        position: _position,
        blur: () => _blur,
        headers: widget.imageHeaders,
      );
    } else if (usesShortlist && shortlist != null && pool.isEmpty) {
      windowContent = _shortlistStatus(context, shortlist);
    } else if (widget.onRetryCatalog case final retry? when !usesShortlist) {
      windowContent = _ShuffleMessage(
        message: localization.catalogErrorTitle,
        action: TextButton(
          key: WidgetKeys.discoveryShuffleCatalogRetry,
          onPressed: retry,
          child: Text(localization.discoveryRetryLabel),
        ),
      );
    } else if (candidate == null) {
      windowContent = _ShuffleIdle(
        key: WidgetKeys.discoveryShufflePlaceholder,
        usesShortlist: usesShortlist,
        exhausted:
            !usesShortlist &&
            (widget.state.noEligibleCandidates ||
                widget.state.eligibleCandidates.isEmpty),
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
            // A poster still downloading when the reel lands fades in over
            // its placeholder; a cached one shows at once.
            child: DiscoveryPoster(
              candidate: candidate,
              headers: widget.imageHeaders,
              fit: BoxFit.contain,
              showFallbackTitle: true,
            ),
          ),
        ),
      );
    }

    final reelAndSettings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CandySpacing.compact,
      children: <Widget>[
        if (shortlist != null)
          SegmentedButton<_ShuffleSource>(
            key: WidgetKeys.discoveryShuffleSource,
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _ShuffleSource.filtered,
                label: Text(
                  localization.discoveryShuffleFilteredSourceLabel,
                  key: WidgetKeys.discoveryShuffleFilteredSource,
                  textAlign: TextAlign.center,
                ),
              ),
              ButtonSegment(
                value: _ShuffleSource.forYou,
                label: Text(
                  localization.discoveryShuffleForYouSourceLabel,
                  key: WidgetKeys.discoveryShuffleForYouSource,
                  textAlign: TextAlign.center,
                ),
              ),
              ButtonSegment(
                value: _ShuffleSource.shortlist,
                label: Text(
                  localization.discoveryShortlistLabel,
                  key: WidgetKeys.discoveryShuffleShortlistSource,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            selected: {
              usesShortlist
                  ? _ShuffleSource.shortlist
                  : widget.state.shuffleForYou
                  ? _ShuffleSource.forYou
                  : _ShuffleSource.filtered,
            },
            onSelectionChanged: spinning
                ? null
                : (selection) {
                    final source = selection.single;
                    final discovery = context.read<DiscoveryCubit>();
                    unawaited(discovery.clearReveal());
                    if (source != _ShuffleSource.shortlist) {
                      unawaited(
                        discovery.setShuffleForYou(
                          source == _ShuffleSource.forYou,
                        ),
                      );
                    }
                    context.read<ShortlistCubit>().selectSource(
                      useShortlist: source == _ShuffleSource.shortlist,
                    );
                  },
          ),
        Expanded(
          child: _ReelWindow(
            landings: _landings,
            shaded: spinning && !_settling,
            reduceMotion: reduceMotion,
            child: GestureDetector(
              key: WidgetKeys.discoveryShuffleReel,
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              excludeFromSemantics: true,
              onPanStart: canDrag
                  ? (details) => _dragOrigin = details.localPosition
                  : null,
              onPanUpdate: canDrag ? _onPanUpdate : null,
              child: windowContent,
            ),
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
                        DiscoveryShortlistButton(candidate: candidate),
                        DiscoveryFavoriteButton(
                          candidate: candidate,
                          onToggleFavorite: widget.onToggleFavorite,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (!usesShortlist && !widget.state.shuffleForYou)
          _FavoriteBiasControl(
            bias: widget.state.favoriteBias,
            hasFavorites: pool.any((candidate) => candidate.favorite == true),
            enabled: !spinning,
          ),
      ],
    );
    return Column(
      key: WidgetKeys.discoveryShuffle,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CandySpacing.compact,
      children: [
        Expanded(
          child: shortlist == null
              ? reelAndSettings
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(16) / 16;
                    final minimumHeight =
                        310 + 110 * (textScale - 1).clamp(0.0, 2.0);
                    if (constraints.maxHeight >= minimumHeight) {
                      return reelAndSettings;
                    }
                    return SingleChildScrollView(
                      child: SizedBox(
                        height: minimumHeight,
                        child: reelAndSettings,
                      ),
                    );
                  },
                ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: WidgetKeys.discoveryRevealButton,
                onPressed: canSpin ? _spin : null,
                icon: const Icon(Icons.casino_rounded),
                label: Text(
                  spinning
                      ? localization.discoverySpinningLabel
                      : directReveal
                      ? localization.discoveryShortlistRevealLabel(
                          widget.state.mediaType.name,
                        )
                      : candidate == null
                      ? localization.discoveryRevealLabel
                      : localization.discoverySpinAgainLabel,
                ),
              ),
            ),
            if (!usesShortlist || pool.length > 1) ...[
              const SizedBox(width: CandySpacing.compact),
              PopupMenuButton<ShuffleDuration>(
                key: WidgetKeys.discoveryShuffleDuration,
                tooltip: localization.discoveryShuffleDurationLabel,
                enabled: !spinning,
                initialValue: widget.state.shuffleDuration,
                popUpAnimationStyle: reduceMotion
                    ? AnimationStyle.noAnimation
                    : null,
                onSelected: context.read<DiscoveryCubit>().setShuffleDuration,
                itemBuilder: (context) => <PopupMenuEntry<ShuffleDuration>>[
                  for (final choice in ShuffleDuration.values)
                    CheckedPopupMenuItem<ShuffleDuration>(
                      key: WidgetKeys.discoveryShuffleDurationChoice(
                        choice.name,
                      ),
                      value: choice,
                      checked: choice == widget.state.shuffleDuration,
                      child: Text(_durationLabel(localization, choice)),
                    ),
                ],
                child: SizedBox(
                  height: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.timer_outlined),
                      const SizedBox(width: CandySpacing.compact / 2),
                      Text(
                        _durationLabel(
                          localization,
                          widget.state.shuffleDuration,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _shortlistStatus(BuildContext context, ShortlistState shortlist) {
    final l10n = AppLocalizations.of(context);
    final kind = widget.state.mediaType.name;
    if (shortlist.isHydrated && shortlist.entries.isEmpty) {
      return _ShuffleMessage(
        message: l10n.discoveryShortlistEmpty(kind),
        action: TextButton(
          key: WidgetKeys.discoveryShortlistBrowse,
          onPressed: () =>
              context.read<DiscoveryCubit>().setMode(DiscoveryMode.grid),
          child: Text(l10n.discoveryShortlistBrowseLabel(kind)),
        ),
      );
    }
    return switch (shortlist.lookup) {
      ShortlistLookup.idle || ShortlistLookup.loading => _ShuffleMessage(
        message: l10n.discoveryShortlistLoading,
        action: const Padding(
          padding: EdgeInsets.all(CandySpacing.compact),
          child: CircularProgressIndicator(),
        ),
      ),
      ShortlistLookup.failed => _ShuffleMessage(
        message: l10n.discoveryShortlistLookupError,
        action: TextButton(
          key: WidgetKeys.discoveryShortlistRetry,
          onPressed: context.read<ShortlistCubit>().refresh,
          child: Text(l10n.discoveryRetryLabel),
        ),
      ),
      ShortlistLookup.ready => _ShuffleMessage(
        message: l10n.discoveryShortlistNoneAvailable(kind),
      ),
    };
  }
}

final class _ShuffleMessage extends StatelessWidget {
  const _ShuffleMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(CandySpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: CandySpacing.compact,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(message, textAlign: TextAlign.center),
          ),
          ?action,
        ],
      ),
    ),
  );
}

String _durationLabel(AppLocalizations l10n, ShuffleDuration choice) =>
    choice == ShuffleDuration.instant
    ? l10n.discoveryShuffleInstantLabel
    : l10n.discoveryShuffleDurationSeconds(
        choice.duration.inMilliseconds / 1000,
      );

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

/// Clips the reel and adds a glow when it lands on a pick.
final class _ReelWindow extends StatelessWidget {
  const _ReelWindow({
    required this.landings,
    required this.shaded,
    required this.reduceMotion,
    required this.child,
  });

  final int landings;

  /// Darkens the top and bottom edges while the reel is travelling.
  final bool shaded;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(CandyShapes.card);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        // Only the glow restarts on each landing; the poster above it keeps
        // its place in the tree, so landing never rebuilds it.
        TweenAnimationBuilder<double>(
          key: ValueKey<int>(landings),
          tween: Tween<double>(begin: landings > 0 ? 1 : 0, end: 0),
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, glow, _) => DecoratedBox(
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
          ),
        ),
        ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              child,
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: shaded ? 1 : 0,
                  duration: reduceMotion ? Duration.zero : CandyMotion.standard,
                  curve: Curves.easeInOutCubic,
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
            ],
          ),
        ),
      ],
    );
  }
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

  /// Below this sigma the blur is invisible and is skipped entirely.
  static const _sharpSigma = 0.01;

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
                        // Fillers whiz past, but the pick may arrive late
                        // and should fade in rather than pop.
                        fadeIn: index == reel.length - 1,
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
              final sigma = blur();
              // Stays mounted for the whole spin and switches off at zero,
              // so the blur fades out without rebuilding the posters.
              return ImageFiltered(
                key: WidgetKeys.discoveryShuffleReelBlur,
                enabled: sigma > _sharpSigma,
                imageFilter: ImageFilter.blur(sigmaY: sigma),
                child: Stack(clipBehavior: Clip.hardEdge, children: items),
              );
            },
          );
        },
      ),
    );
  }
}

final class _ShuffleIdle extends StatelessWidget {
  const _ShuffleIdle({
    required this.exhausted,
    required this.usesShortlist,
    super.key,
  });

  /// Nothing is left to pick under the current filters and decisions.
  final bool exhausted;
  final bool usesShortlist;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: CandySpacing.page,
          vertical: CandySpacing.compact,
        ),
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
                    : usesShortlist
                    ? localization.discoveryShortlistIdleDescription
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
