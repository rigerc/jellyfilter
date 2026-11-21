import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Overview tab: synopsis, genres, and cast, each under its own heading.
final class DiscoveryDetailsOverview extends StatelessWidget {
  const DiscoveryDetailsOverview({required this.candidate, super.key});

  final CatalogCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final overview = candidate.overview?.trim();
    final genres = discoveryGenreNames(candidate);
    final cast = candidate.cast.take(12).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CandySpacing.page,
        CandySpacing.page,
        CandySpacing.page,
        CandySpacing.section,
      ),
      children: <Widget>[
        _Section(
          title: l10n.discoverySynopsisTitle,
          child: Text(
            overview == null || overview.isEmpty
                ? l10n.discoveryUnknownValue
                : overview,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        if (genres.isNotEmpty)
          _Section(
            title: l10n.discoveryGenresTitle,
            child: Wrap(
              spacing: CandySpacing.compact / 1.5,
              runSpacing: CandySpacing.compact / 1.5,
              children: <Widget>[
                for (final genre in genres) _Tag(label: genre),
              ],
            ),
          ),
        if (cast.isNotEmpty)
          _Section(
            title: l10n.discoveryCastTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: CandySpacing.compact / 1.5,
              children: <Widget>[
                for (final person in cast)
                  Row(
                    spacing: CandySpacing.compact,
                    children: <Widget>[
                      Icon(
                        Icons.person_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      Expanded(
                        child: Text(person, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Details tab: the facts as an aligned label / value list.
final class DiscoveryDetailsFacts extends StatelessWidget {
  const DiscoveryDetailsFacts({required this.candidate, super.key});

  final CatalogCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unknown = l10n.discoveryUnknownValue;
    final runtime = candidate.runtimeMinutes;
    final added = candidate.dateCreated;
    final series = candidate.series;
    final seasons = series?.seasonCount;
    final episodes = series?.episodeCount;
    final facts = <(String, String)>[
      if (series == null)
        (l10n.discoveryYearTitle, candidate.year?.toString() ?? unknown)
      else ...[
        (
          l10n.discoveryAiredTitle,
          discoveryAiredYears(l10n, candidate) ?? unknown,
        ),
        (l10n.discoverySeasonsTitle, seasons == null ? unknown : '$seasons'),
        (l10n.discoveryTabEpisodes, episodes == null ? unknown : '$episodes'),
      ],
      (
        series == null
            ? l10n.discoveryRuntimeTitle
            : l10n.discoveryEpisodeLengthTitle,
        runtime == null ? unknown : l10n.discoveryRuntimeMinutes(runtime),
      ),
      (
        l10n.discoveryCommunityTitle,
        candidate.communityRating?.toStringAsFixed(1) ?? unknown,
      ),
      (
        l10n.discoveryCriticTitle,
        candidate.criticRating?.toStringAsFixed(0) ?? unknown,
      ),
      (l10n.discoveryContentRatingTitle, candidate.officialRating ?? unknown),
      (l10n.discoveryStatusTitle, candidate.status ?? unknown),
      if (added != null)
        (
          l10n.discoveryAddedTitle,
          DateFormat.yMMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(added.toLocal()),
        ),
    ];
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: CandySpacing.page,
        vertical: CandySpacing.compact,
      ),
      itemCount: facts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final (label, value) = facts[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: CandySpacing.compact),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CandySpacing.cardGap,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CandySpacing.section - 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CandySpacing.compact,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        child,
      ],
    ),
  );
}

final class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CandyShapes.pill),
        border: Border.all(color: CandyColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(label, style: theme.textTheme.labelLarge),
      ),
    );
  }
}

/// Genre names as shown to people: capitalized and in alphabetical order.
List<String> discoveryGenreNames(CatalogCandidate candidate) =>
    candidate.genres.map(_titleCase).toList()..sort();

String _titleCase(String value) => value.isEmpty
    ? value
    : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
