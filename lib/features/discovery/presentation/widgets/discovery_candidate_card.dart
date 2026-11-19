import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/core/widgets/candy_bounce.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// A poster-first title tile. Grid tiles stay compact; swipe and shuffle use
/// the prominent variant with a larger title.
final class DiscoveryCandidateCard extends StatelessWidget {
  const DiscoveryCandidateCard({
    required this.candidate,
    this.onToggleFavorite,
    this.onLoadDetails,
    this.onOpenTrailer,
    this.imageHeaders = const <String, String>{},
    this.posterFit = BoxFit.cover,
    this.prominent = false,
    super.key,
  });

  final CatalogCandidate candidate;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Map<String, String> imageHeaders;
  final BoxFit posterFit;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(
      prominent ? CandyShapes.card : CandyShapes.poster,
    );
    return Semantics(
      label: localization.discoveryDetailsLabel(candidate.name),
      child: CandyBounce(
        key: WidgetKeys.discoveryCandidate(candidate.id),
        onPressed: () => showDiscoveryDetails(
          context,
          candidate,
          onLoadDetails: onLoadDetails,
          onOpenTrailer: onOpenTrailer,
          imageHeaders: imageHeaders,
        ),
        // Long press: straight to playlists & tags.
        onLongPress: switch (DiscoveryOrganizerScope.maybeOf(context)) {
          final organize? => () => unawaited(organize(context, candidate)),
          null => null,
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: prominent
              ? CandySpacing.compact
              : CandySpacing.compact / 1.5,
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: CandyColors.outline),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: DiscoveryWatchedFade(
                      candidate: candidate,
                      child: DiscoveryPoster(
                        candidate: candidate,
                        headers: imageHeaders,
                        fit: posterFit,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: CandySpacing.compact / 3,
                    ),
                    child: DiscoveryTitleBlock(
                      candidate: candidate,
                      prominent: prominent,
                    ),
                  ),
                ),
                DiscoveryFavoriteButton(
                  candidate: candidate,
                  onToggleFavorite: onToggleFavorite,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggles a Jellyfin favorite. The toggle callback owns optimistic state;
/// this only mirrors a confirmed change when nothing else has, so a host
/// without its own state still updates.
Future<void> toggleDiscoveryFavorite(
  BuildContext context,
  CatalogCandidate candidate,
  FavoriteToggle? onToggleFavorite,
) async {
  final cubit = context.read<DiscoveryCubit>();
  bool? shown() => cubit.state.candidates
      .where((item) => item.id == candidate.id)
      .firstOrNull
      ?.favorite;
  final before = shown();
  final succeeded = await onToggleFavorite?.call(candidate) ?? false;
  if (succeeded) {
    if (shown() == before) {
      await cubit.updateCandidate(candidate.copyWith(favorite: before != true));
    }
  } else if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).discoveryFavoriteError),
        ),
      );
  }
}

/// Dims a watched title's poster and marks it, when "Fade watched" is on.
final class DiscoveryWatchedFade extends StatelessWidget {
  const DiscoveryWatchedFade({
    required this.candidate,
    required this.child,
    super.key,
  });

  final CatalogCandidate candidate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fadeEnabled = context.select(
      (DiscoveryCubit cubit) => cubit.state.fadeWatched,
    );
    final fade = fadeEnabled && candidate.watched == true;
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AnimatedOpacity(
          opacity: fade ? 0.35 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : CandyMotion.standard,
          child: child,
        ),
        if (fade)
          Positioned(
            key: WidgetKeys.discoveryWatchedBadge(candidate.id),
            top: CandySpacing.compact / 1.5,
            left: CandySpacing.compact / 1.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CandyColors.background.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(CandyShapes.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      AppLocalizations.of(context).discoveryWatchedBadge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The heart toggle shared by every view: it pops when the state flips.
final class DiscoveryFavoriteButton extends StatelessWidget {
  const DiscoveryFavoriteButton({
    required this.candidate,
    required this.onToggleFavorite,
    this.idleColor,
    super.key,
  });

  final CatalogCandidate candidate;
  final FavoriteToggle? onToggleFavorite;

  /// Outline color when not a favorite; defaults to the muted foreground.
  final Color? idleColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final favorite = candidate.favorite == true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IconButton(
      key: WidgetKeys.discoveryFavorite(candidate.id),
      tooltip: favorite
          ? l10n.discoveryFavoriteRemoveLabel
          : l10n.discoveryFavoriteAddLabel,
      onPressed: onToggleFavorite == null
          ? null
          : () {
              unawaited(HapticFeedback.selectionClick());
              unawaited(
                toggleDiscoveryFavorite(context, candidate, onToggleFavorite),
              );
            },
      icon: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : CandyMotion.standard,
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey<bool>(favorite),
          color: favorite
              ? scheme.primary
              : idleColor ?? scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Title plus a quiet year · runtime line.
final class DiscoveryTitleBlock extends StatelessWidget {
  const DiscoveryTitleBlock({
    required this.candidate,
    this.prominent = false,
    super.key,
  });

  final CatalogCandidate candidate;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = discoveryMetaLine(AppLocalizations.of(context), candidate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          candidate.name,
          maxLines: prominent ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style:
              (prominent
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.titleSmall)
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
        ),
        if (meta.isNotEmpty)
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
      ],
    );
  }
}

String discoveryMetaLine(
  AppLocalizations localization,
  CatalogCandidate candidate,
) {
  final runtime = candidate.runtimeMinutes;
  return <String>[
    if (candidate.year case final year?) '$year',
    if (runtime != null && runtime > 0)
      localization.discoveryRuntimeMinutes(runtime),
  ].join('  ·  ');
}

/// Progressive poster: blurhash or tiny preview first, then the full image.
final class DiscoveryPoster extends StatelessWidget {
  const DiscoveryPoster({
    required this.candidate,
    required this.headers,
    required this.fit,
    this.networkWidth = CandyImages.posterDisplayNetworkWidth,
    this.quality = CandyImages.posterDisplayQuality,
    this.cacheWidth = CandyImages.posterCacheWidth,
    this.fadeIn = true,
    this.showFallbackTitle = false,
    super.key,
  });

  final CatalogCandidate candidate;
  final Map<String, String> headers;
  final BoxFit fit;
  final int networkWidth;
  final int quality;
  final int cacheWidth;
  final bool fadeIn;

  /// Names the title on artwork-less posters where no caption is nearby.
  final bool showFallbackTitle;

  @override
  Widget build(BuildContext context) {
    final previewUri = candidate.poster.variantUri(
      maxWidth: CandyImages.posterPreviewNetworkWidth,
      quality: CandyImages.posterPreviewQuality,
      blur: CandyImages.posterPreviewBlur,
    );
    final displayUri = candidate.poster.variantUri(
      maxWidth: networkWidth,
      quality: quality,
    );
    if (previewUri == null || displayUri == null) {
      return DiscoveryPosterFallback(
        title: showFallbackTitle ? candidate.name : null,
      );
    }
    final blurHash = candidate.poster.blurHash;
    final placeholder = blurHash != null && validateBlurhash(blurHash)
        ? BlurHash(
            key: WidgetKeys.discoveryPosterBlurHash(candidate.id),
            hash: blurHash,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            imageFit: fit,
            decodingWidth: 20,
            decodingHeight: (20 / candidate.poster.aspectRatio).round().clamp(
              1,
              32,
            ),
            optimizationMode: BlurHashOptimizationMode.approximation,
          )
        : Image.network(
            previewUri.toString(),
            key: WidgetKeys.discoveryPosterPreview,
            headers: headers,
            fit: fit,
            cacheWidth: CandyImages.posterPreviewNetworkWidth,
            filterQuality: FilterQuality.low,
            errorBuilder: (context, error, stackTrace) =>
                DiscoveryPosterFallback(
                  title: showFallbackTitle ? candidate.name : null,
                ),
          );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        placeholder,
        Image.network(
          displayUri.toString(),
          headers: headers,
          fit: fit,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || !fadeIn) {
              return child;
            }
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: reduceMotion ? Duration.zero : CandyMotion.quick,
              curve: Curves.easeOutCubic,
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

final class DiscoveryPosterFallback extends StatelessWidget {
  const DiscoveryPosterFallback({this.title, super.key});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = title;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(CandySpacing.compact),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: CandySpacing.compact,
          children: <Widget>[
            Icon(
              Icons.local_movies_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            if (label != null)
              Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
