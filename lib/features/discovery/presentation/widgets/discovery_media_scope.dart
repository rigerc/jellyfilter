import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_series_progress.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Loads a series' seasons and next episode; null when Jellyfin can't say.
typedef SeriesProgressLoader =
    Future<CatalogSeriesProgress?> Function(CatalogCandidate series);

/// Hands the movies/shows switch and series lookups to every view below.
final class DiscoveryMediaScope extends InheritedWidget {
  const DiscoveryMediaScope({
    required super.child,
    this.mediaType = CatalogMediaType.movie,
    this.available = const <CatalogMediaType>{},
    this.onChanged,
    this.loadSeriesProgress,
    super.key,
  });

  /// The kind of title on screen.
  final CatalogMediaType mediaType;

  /// The kinds the server holds. The switch shows only when there are two.
  final Set<CatalogMediaType> available;
  final ValueChanged<CatalogMediaType>? onChanged;
  final SeriesProgressLoader? loadSeriesProgress;

  /// Whether the user can switch between movies and shows.
  bool get canSwitch => onChanged != null && available.length > 1;

  static DiscoveryMediaScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DiscoveryMediaScope>();

  @override
  bool updateShouldNotify(DiscoveryMediaScope oldWidget) =>
      oldWidget.mediaType != mediaType ||
      !_sameSet(oldWidget.available, available) ||
      oldWidget.onChanged != onChanged ||
      oldWidget.loadSeriesProgress != loadSeriesProgress;

  static bool _sameSet(Set<Object?> left, Set<Object?> right) =>
      left.length == right.length && left.containsAll(right);
}

/// One toggle that flips discovery between movies and TV shows. It takes
/// the brand's place: an icon for the kind on screen, with a swap badge,
/// beside the [child] title.
final class DiscoveryMediaToggle extends StatelessWidget {
  const DiscoveryMediaToggle({
    required this.selected,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final CatalogMediaType selected;
  final ValueChanged<CatalogMediaType> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final series = selected == CatalogMediaType.series;
    final next = series ? CatalogMediaType.movie : CatalogMediaType.series;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // The title and count beside the icon are read as the button's label.
    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: series
            ? l10n.discoveryShowMoviesTooltip
            : l10n.discoveryShowShowsTooltip,
        child: Tooltip(
          message: series
              ? l10n.discoveryShowMoviesTooltip
              : l10n.discoveryShowShowsTooltip,
          excludeFromSemantics: true,
          child: InkWell(
            key: WidgetKeys.discoveryMediaTypeToggle,
            onTap: () => onChanged(next),
            borderRadius: BorderRadius.circular(CandyShapes.compact),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: CandySpacing.minimumTouchTarget,
              ),
              child: Row(
                spacing: CandySpacing.compact,
                children: <Widget>[
                  ExcludeSemantics(
                    child: SizedBox.square(
                      dimension: CandyIconSize.brand,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  CandyShapes.compact,
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: reduceMotion
                                    ? Duration.zero
                                    : CandyMotion.quick,
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                child: Icon(
                                  series
                                      ? Icons.live_tv_rounded
                                      : Icons.movie_outlined,
                                  key: ValueKey<CatalogMediaType>(selected),
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            end: -4,
                            bottom: -4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(1),
                                child: Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 12,
                                  color: scheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
