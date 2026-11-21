import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/core/widgets/candy_bounce.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_metadata.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_empty_state.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_load_more.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Browse as a list: compact rows on phones, and table-like columns under a
/// header row on wide screens.
final class DiscoveryList extends StatefulWidget {
  const DiscoveryList({
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

  /// Screen width from which rows show ratings and genres in columns.
  static const wideWidth = 700.0;

  final List<CatalogCandidate> candidates;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Future<void> Function()? onLoadMore;

  /// Title to start scrolled to, so switching layouts keeps your place.
  final int initialIndex;

  /// Reports the first title that is mostly in view as the list scrolls.
  final ValueChanged<int>? onTopIndexChanged;
  final Map<String, String> imageHeaders;

  @override
  State<DiscoveryList> createState() => _DiscoveryListState();
}

final class _DiscoveryListState extends State<DiscoveryList> {
  ScrollController? _controller;
  double _extent = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _reportTopIndex() {
    final controller = _controller;
    final count = widget.candidates.length;
    if (controller == null || !controller.hasClients || _extent <= 0) {
      return;
    }
    if (count == 0) {
      return;
    }
    final index = ((controller.offset + _extent / 2) / _extent).floor();
    widget.onTopIndexChanged?.call(index.clamp(0, count - 1));
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.candidates;
    if (candidates.isEmpty) {
      return const DiscoveryEmptyState();
    }
    final wide = MediaQuery.sizeOf(context).width >= DiscoveryList.wideWidth;
    final styles = _RowStyles.of(context);
    _extent = styles.rowExtent(wide: wide);
    final controller = _controller ??= ScrollController(
      initialScrollOffset: widget.initialIndex * _extent,
    )..addListener(_reportTopIndex);
    final list = DiscoveryLoadMore(
      onLoadMore: widget.onLoadMore,
      child: ListView.builder(
        key: WidgetKeys.discoveryList,
        controller: controller,
        itemExtent: _extent,
        itemCount: candidates.length,
        itemBuilder: (context, index) => RepaintBoundary(
          key: ValueKey<String>(candidates[index].id),
          child: _DiscoveryListRow(
            candidate: candidates[index],
            wide: wide,
            styles: styles,
            onToggleFavorite: widget.onToggleFavorite,
            onLoadDetails: widget.onLoadDetails,
            onOpenTrailer: widget.onOpenTrailer,
            imageHeaders: widget.imageHeaders,
          ),
        ),
      ),
    );
    if (!wide) {
      return list;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DiscoveryListHeader(styles: styles),
        const Divider(height: 1),
        Expanded(child: list),
      ],
    );
  }
}

/// Text styles and fixed sizes shared by the header and every row, so the
/// columns line up and each row has the same, text-scale-aware height.
final class _RowStyles {
  _RowStyles._({
    required this.title,
    required this.detail,
    required this.header,
    required this.scaler,
  });

  factory _RowStyles.of(BuildContext context) {
    final theme = Theme.of(context);
    final base = DefaultTextStyle.of(context).style;
    final muted = theme.colorScheme.onSurfaceVariant;
    return _RowStyles._(
      title: base.merge(
        theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      detail: base.merge(
        theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.3),
      ),
      header: base.merge(theme.textTheme.labelMedium?.copyWith(color: muted)),
      scaler: MediaQuery.textScalerOf(context),
    );
  }

  static const thumbnailWidth = 56.0;
  static const thumbnailHeight = 84.0;
  static const verticalPadding = 8.0;
  static const lineGap = 2.0;
  static const iconSize = 14.0;
  static const ratedWidth = 72.0;
  static const communityWidth = 96.0;
  static const criticsWidth = 80.0;

  /// Room for the shortlist and favorite buttons, kept even when a title
  /// has no shortlist button so the columns stay aligned.
  static const actionsWidth = CandySpacing.minimumTouchTarget * 2;

  /// Guards against rounding between measured and laid-out text.
  static const _slack = 4.0;

  final TextStyle title;
  final TextStyle detail;
  final TextStyle header;
  final TextScaler scaler;

  double rowExtent({required bool wide}) {
    final titleLine = _lineHeight(title);
    final detailLine = math.max(_lineHeight(detail), iconSize);
    final text = wide
        ? titleLine + lineGap + detailLine
        : titleLine + 2 * (lineGap + detailLine);
    return math.max(thumbnailHeight, text) + 2 * verticalPadding + _slack;
  }

  double _lineHeight(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ág', style: style),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }
}

final class _DiscoveryListHeader extends StatelessWidget {
  const _DiscoveryListHeader({required this.styles});

  final _RowStyles styles;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    Text label(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: styles.header,
    );
    // Each value in a row names its own column for screen readers.
    return ExcludeSemantics(
      child: Padding(
        key: WidgetKeys.discoveryListHeader,
        padding: const EdgeInsets.symmetric(vertical: CandySpacing.compact / 2),
        child: Row(
          spacing: CandySpacing.compact,
          children: <Widget>[
            const SizedBox(width: _RowStyles.thumbnailWidth),
            Expanded(
              flex: 3,
              child: label(localization.discoveryListTitleColumn),
            ),
            Expanded(flex: 2, child: label(localization.discoveryGenresTitle)),
            SizedBox(
              width: _RowStyles.ratedWidth,
              child: label(localization.discoveryListRatedColumn),
            ),
            SizedBox(
              width: _RowStyles.communityWidth,
              child: label(localization.discoveryCommunityShort),
            ),
            SizedBox(
              width: _RowStyles.criticsWidth,
              child: label(localization.discoveryCriticsShort),
            ),
            const SizedBox(width: _RowStyles.actionsWidth),
          ],
        ),
      ),
    );
  }
}

final class _DiscoveryListRow extends StatelessWidget {
  const _DiscoveryListRow({
    required this.candidate,
    required this.wide,
    required this.styles,
    required this.onToggleFavorite,
    required this.onLoadDetails,
    required this.onOpenTrailer,
    required this.imageHeaders,
  });

  final CatalogCandidate candidate;
  final bool wide;
  final _RowStyles styles;
  final FavoriteToggle? onToggleFavorite;
  final CandidateDetailsLoader? onLoadDetails;
  final TrailerLauncher? onOpenTrailer;
  final Map<String, String> imageHeaders;

  /// Scores then genres on one line, cut short with an ellipsis when the
  /// row is narrow or the text is large.
  Widget? _scoreLine(
    AppLocalizations localization,
    String? community,
    String? critic,
    String genres,
  ) {
    if (community == null && critic == null && genres.isEmpty) {
      return null;
    }
    InlineSpan score(IconData icon, String value) => TextSpan(
      children: <InlineSpan>[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            icon,
            size: _RowStyles.iconSize,
            color: styles.detail.color,
          ),
        ),
        TextSpan(text: '\u2009$value   '),
      ],
    );
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (community != null) score(Icons.star_rounded, community),
          if (critic != null) score(Icons.rate_review_outlined, critic),
          if (genres.isNotEmpty) TextSpan(text: genres),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: styles.detail,
      semanticsLabel: <String>[
        if (community != null)
          localization.discoveryCommunityRatingLabel(community),
        if (critic != null) localization.discoveryCriticRatingLabel(critic),
        if (genres.isNotEmpty) localization.discoveryGenresLabel(genres),
      ].join(', '),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final fadeEnabled = context.select(
      (DiscoveryCubit cubit) => cubit.state.fadeWatched,
    );
    final watched = fadeEnabled && candidate.watched == true;
    final community = candidate.communityRating?.toStringAsFixed(1);
    final critic = candidate.criticRating?.toStringAsFixed(0);
    final rated = candidate.officialRating?.trim();
    final genres = discoveryGenreNames(candidate).join(', ');

    final title = Text(
      candidate.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: styles.title,
    );
    final metaLine = _MetaLine(
      candidate: candidate,
      watched: watched,
      // Phones fold the content rating into the meta line.
      rated: wide ? null : rated,
      styles: styles,
    );
    final Widget details;
    if (wide) {
      details = Row(
        spacing: CandySpacing.compact,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: _RowStyles.lineGap,
              children: <Widget>[title, metaLine],
            ),
          ),
          Expanded(
            flex: 2,
            child: _ColumnValue(
              value: genres.isEmpty ? null : genres,
              semanticsLabel: localization.discoveryGenresLabel(genres),
              styles: styles,
            ),
          ),
          SizedBox(
            width: _RowStyles.ratedWidth,
            child: _ColumnValue(
              value: rated == null || rated.isEmpty ? null : rated,
              semanticsLabel: localization.discoveryContentRatingLabel(
                rated ?? '',
              ),
              styles: styles,
            ),
          ),
          SizedBox(
            width: _RowStyles.communityWidth,
            child: _ColumnValue(
              value: community,
              icon: Icons.star_rounded,
              semanticsLabel: localization.discoveryCommunityRatingLabel(
                community ?? '',
              ),
              styles: styles,
            ),
          ),
          SizedBox(
            width: _RowStyles.criticsWidth,
            child: _ColumnValue(
              value: critic,
              icon: Icons.rate_review_outlined,
              semanticsLabel: localization.discoveryCriticRatingLabel(
                critic ?? '',
              ),
              styles: styles,
            ),
          ),
        ],
      );
    } else {
      details = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _RowStyles.lineGap,
        children: <Widget>[
          title,
          metaLine,
          ?_scoreLine(localization, community, critic, genres),
        ],
      );
    }

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
        // Long press: straight to playlists & tags, as in the grid.
        onLongPress: switch (DiscoveryOrganizerScope.maybeOf(context)) {
          final organize? => () => unawaited(organize(context, candidate)),
          null => null,
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: _RowStyles.verticalPadding,
          ),
          child: Row(
            spacing: CandySpacing.compact,
            children: <Widget>[
              Expanded(
                child: AnimatedOpacity(
                  opacity: watched ? 0.35 : 1,
                  duration: reduceMotion ? Duration.zero : CandyMotion.standard,
                  child: Row(
                    spacing: CandySpacing.compact,
                    children: <Widget>[
                      _Thumbnail(candidate: candidate, headers: imageHeaders),
                      Expanded(child: details),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: _RowStyles.actionsWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    DiscoveryShortlistButton(candidate: candidate),
                    DiscoveryFavoriteButton(
                      candidate: candidate,
                      onToggleFavorite: onToggleFavorite,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.candidate, required this.headers});

  final CatalogCandidate candidate;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CandyShapes.compact / 1.5);
    return SizedBox(
      width: _RowStyles.thumbnailWidth,
      height: _RowStyles.thumbnailHeight,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: CandyColors.outline),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: DiscoveryPoster(
              candidate: candidate,
              headers: headers,
              fit: BoxFit.cover,
              networkWidth: CandyImages.posterThumbnailNetworkWidth,
              quality: CandyImages.posterThumbnailQuality,
              cacheWidth: CandyImages.posterThumbnailNetworkWidth,
            ),
          ),
        ),
      ),
    );
  }
}

/// Year and runtime, plus the watched mark and (on phones) content rating.
final class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.candidate,
    required this.watched,
    required this.rated,
    required this.styles,
  });

  final CatalogCandidate candidate;
  final bool watched;
  final String? rated;
  final _RowStyles styles;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    final rating = rated;
    final meta = <String>[
      discoveryMetaLine(localization, candidate),
      if (rating != null && rating.isNotEmpty) rating,
    ].where((part) => part.isNotEmpty).join('  ·  ');
    return Row(
      spacing: CandySpacing.compact / 3,
      children: <Widget>[
        if (watched)
          Icon(
            Icons.check_circle_rounded,
            size: _RowStyles.iconSize,
            color: styles.detail.color,
            semanticLabel: localization.discoveryWatchedBadge,
          ),
        Flexible(
          child: Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: styles.detail,
          ),
        ),
      ],
    );
  }
}

/// One cell of the wide layout; a dash when the value is missing.
final class _ColumnValue extends StatelessWidget {
  const _ColumnValue({
    required this.value,
    required this.semanticsLabel,
    required this.styles,
    this.icon,
  });

  final String? value;
  final String semanticsLabel;
  final _RowStyles styles;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null) {
      return ExcludeSemantics(child: Text('–', style: styles.detail));
    }
    final glyph = icon;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        spacing: 2,
        children: <Widget>[
          if (glyph != null)
            Icon(glyph, size: _RowStyles.iconSize, color: styles.detail.color),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.detail,
            ),
          ),
        ],
      ),
    );
  }
}
