import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_series_progress.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_media_scope.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Episodes tab of a show's details: the next episode to watch and the
/// user's progress through each season.
final class DiscoverySeriesEpisodes extends StatefulWidget {
  const DiscoverySeriesEpisodes({
    required this.candidate,
    required this.load,
    super.key,
  });

  final CatalogCandidate candidate;
  final SeriesProgressLoader load;

  @override
  State<DiscoverySeriesEpisodes> createState() =>
      _DiscoverySeriesEpisodesState();
}

final class _DiscoverySeriesEpisodesState
    extends State<DiscoverySeriesEpisodes> {
  late Future<CatalogSeriesProgress?> _progress;

  @override
  void initState() {
    super.initState();
    _progress = widget.load(widget.candidate);
  }

  void _retry() {
    final progress = widget.load(widget.candidate);
    setState(() {
      _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<CatalogSeriesProgress?>(
      future: _progress,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final progress = snapshot.data;
        if (progress == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: CandySpacing.compact,
              children: <Widget>[
                Text(l10n.discoveryLoadFailed),
                TextButton(
                  key: WidgetKeys.discoverySeasonsRetry,
                  onPressed: _retry,
                  child: Text(l10n.discoveryRetryLabel),
                ),
              ],
            ),
          );
        }
        final nextUp = progress.nextUp;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            CandySpacing.page,
            CandySpacing.page,
            CandySpacing.page,
            CandySpacing.section,
          ),
          children: <Widget>[
            if (nextUp != null) ...<Widget>[
              _NextUp(episode: nextUp),
              const SizedBox(height: CandySpacing.section),
            ],
            Text(
              l10n.discoverySeasonsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: CandySpacing.compact),
            if (progress.seasons.isEmpty)
              Text(l10n.discoveryNoSeasons)
            else
              for (final season in progress.seasons) _SeasonRow(season: season),
          ],
        );
      },
    );
  }
}

final class _NextUp extends StatelessWidget {
  const _NextUp({required this.episode});

  final CatalogEpisode episode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final season = episode.seasonNumber;
    final number = episode.episodeNumber;
    final runtime = episode.runtimeMinutes;
    final meta = <String>[
      if (season != null && number != null)
        l10n.discoveryEpisodeCode(season, number),
      if (runtime != null && runtime > 0) l10n.discoveryRuntimeMinutes(runtime),
    ].join('  ·  ');
    return DecoratedBox(
      key: WidgetKeys.discoveryNextUp,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(CandyShapes.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CandySpacing.cardGap),
        child: Row(
          spacing: CandySpacing.cardGap,
          children: <Widget>[
            Icon(Icons.play_circle_outline_rounded, color: scheme.primary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.discoveryNextUpTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    episode.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SeasonRow extends StatelessWidget {
  const _SeasonRow({required this.season});

  final CatalogSeason season;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = season.episodeCount;
    final played = season.playedEpisodeCount;
    final finished = total != null && total > 0 && played == total;
    return Padding(
      key: WidgetKeys.discoverySeason(season.id),
      padding: const EdgeInsets.symmetric(vertical: CandySpacing.compact / 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          Row(
            spacing: CandySpacing.compact,
            children: <Widget>[
              Expanded(
                child: Text(
                  season.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (finished)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              Text(
                played != null && total != null
                    ? l10n.discoverySeasonProgress(played, total)
                    : total != null
                    ? l10n.discoveryEpisodeCount(total)
                    : '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          if (played != null && total != null && total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(CandyShapes.pill),
              child: LinearProgressIndicator(
                value: played / total,
                minHeight: 4,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
        ],
      ),
    );
  }
}
