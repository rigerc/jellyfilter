import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/media_affinity.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_metadata.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_series.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_media_scope.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Opens the playlists & tags sheet for a title.
typedef CandidateOrganizer =
    Future<void> Function(BuildContext context, CatalogCandidate candidate);

/// Makes the playlists & tags action available to every view below it.
final class DiscoveryOrganizerScope extends InheritedWidget {
  const DiscoveryOrganizerScope({
    required this.organize,
    required super.child,
    super.key,
  });

  final CandidateOrganizer? organize;

  static CandidateOrganizer? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DiscoveryOrganizerScope>()
      ?.organize;

  @override
  bool updateShouldNotify(DiscoveryOrganizerScope oldWidget) =>
      oldWidget.organize != organize;
}

Future<void> showDiscoveryDetails(
  BuildContext context,
  CatalogCandidate candidate, {
  CandidateDetailsLoader? onLoadDetails,
  TrailerLauncher? onOpenTrailer,
  Map<String, String> imageHeaders = const <String, String>{},
}) {
  // Modal routes sit above the page, so hand the page's actions across.
  final organize = DiscoveryOrganizerScope.maybeOf(context);
  final loadSeriesProgress = DiscoveryMediaScope.maybeOf(
    context,
  )?.loadSeriesProgress;
  final shortlist = context.read<ShortlistCubit?>();
  final reasons =
      context.read<DiscoveryCubit?>()?.state.affinity.reasonsFor(
        candidate.id,
      ) ??
      const <AffinityReason>[];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final sheet = DiscoveryDetailsSheet(
        candidate: candidate,
        reasons: reasons,
        onLoadDetails: onLoadDetails,
        onOpenTrailer: onOpenTrailer,
        imageHeaders: imageHeaders,
        onLoadSeriesProgress: loadSeriesProgress,
        onOrganize: organize == null
            ? null
            : (current) => organize(sheetContext, current),
      );
      return shortlist == null
          ? sheet
          : BlocProvider.value(value: shortlist, child: sheet);
    },
  );
}

final class DiscoveryDetailsSheet extends StatefulWidget {
  const DiscoveryDetailsSheet({
    required this.candidate,
    this.reasons = const <AffinityReason>[],
    this.onLoadDetails,
    this.onOpenTrailer,
    this.onOrganize,
    this.onLoadSeriesProgress,
    this.imageHeaders = const <String, String>{},
    super.key,
  });

  final Map<String, String> imageHeaders;
  final CatalogCandidate candidate;

  /// Why this title is a personal match; empty hides the line.
  final List<AffinityReason> reasons;
  final CandidateDetailsLoader? onLoadDetails;

  /// Loads a show's seasons for the Episodes tab; null hides the tab.
  final SeriesProgressLoader? onLoadSeriesProgress;
  final TrailerLauncher? onOpenTrailer;
  final ValueChanged<CatalogCandidate>? onOrganize;

  @override
  State<DiscoveryDetailsSheet> createState() => _DiscoveryDetailsSheetState();
}

final class _DiscoveryDetailsSheetState extends State<DiscoveryDetailsSheet> {
  late final Future<CatalogCandidate?>? _details;

  @override
  void initState() {
    super.initState();
    _details = widget.onLoadDetails?.call(widget.candidate);
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null) {
      return _DetailsLayout(
        candidate: widget.candidate,
        reasons: widget.reasons,
        loading: false,
        imageHeaders: widget.imageHeaders,
        onOpenTrailer: widget.onOpenTrailer,
        onOrganize: widget.onOrganize,
        onLoadSeriesProgress: widget.onLoadSeriesProgress,
      );
    }
    return FutureBuilder<CatalogCandidate?>(
      future: details,
      builder: (context, snapshot) => _DetailsLayout(
        candidate: snapshot.data ?? widget.candidate,
        reasons: widget.reasons,
        loading: snapshot.connectionState != ConnectionState.done,
        imageHeaders: widget.imageHeaders,
        onOpenTrailer: widget.onOpenTrailer,
        onOrganize: widget.onOrganize,
        onLoadSeriesProgress: widget.onLoadSeriesProgress,
      ),
    );
  }
}

final class _DetailsLayout extends StatelessWidget {
  const _DetailsLayout({
    required this.candidate,
    required this.reasons,
    required this.loading,
    required this.onOpenTrailer,
    required this.onOrganize,
    required this.imageHeaders,
    required this.onLoadSeriesProgress,
  });

  final Map<String, String> imageHeaders;
  final CatalogCandidate candidate;
  final List<AffinityReason> reasons;
  final SeriesProgressLoader? onLoadSeriesProgress;
  final bool loading;
  final TrailerLauncher? onOpenTrailer;
  final ValueChanged<CatalogCandidate>? onOrganize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final height = math.max(
      0.0,
      math.min(media.size.height * 0.88, media.size.height - media.padding.top),
    );
    final trailers = candidate.trailers;
    final organize = onOrganize;
    final series = candidate.mediaType == CatalogMediaType.series;
    final loadSeries = series ? onLoadSeriesProgress : null;
    final tabs = <String>[
      l10n.discoveryTabOverview,
      if (loadSeries != null) l10n.discoveryTabEpisodes,
      l10n.discoveryTabDetails,
      if (trailers.isNotEmpty) l10n.discoveryTrailersLabel,
    ];
    return DefaultTabController(
      length: tabs.length,
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 2,
              child: loading
                  ? const LinearProgressIndicator(
                      key: WidgetKeys.discoveryDetailsLoading,
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CandySpacing.page,
                CandySpacing.compact,
                CandySpacing.page,
                0,
              ),
              child: _DetailsHeader(
                candidate: candidate,
                imageHeaders: imageHeaders,
              ),
            ),
            if (reasons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CandySpacing.page,
                  CandySpacing.cardGap,
                  CandySpacing.page,
                  0,
                ),
                child: _RecommendationReason(reasons: reasons),
              ),
            if (trailers.isNotEmpty || organize != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CandySpacing.page,
                  CandySpacing.cardGap,
                  CandySpacing.page,
                  0,
                ),
                child: Row(
                  spacing: CandySpacing.compact,
                  children: <Widget>[
                    if (trailers.isNotEmpty)
                      Expanded(
                        child: FilledButton.icon(
                          key: WidgetKeys.discoveryPlayTrailer,
                          onPressed: onOpenTrailer == null
                              ? null
                              : () => openDiscoveryTrailer(
                                  context,
                                  trailers.first.uri,
                                  onOpenTrailer,
                                ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(l10n.discoveryPlayTrailerLabel),
                        ),
                      ),
                    if (organize != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          key: WidgetKeys.discoveryOrganizeButton,
                          onPressed: () => organize(candidate),
                          icon: Icon(
                            series
                                ? Icons.sell_outlined
                                : Icons.playlist_add_rounded,
                          ),
                          label: Text(
                            // Shows only get tags: a playlist would take
                            // every episode.
                            series
                                ? l10n.discoveryTagsTab
                                : l10n.discoveryOrganizeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: CandySpacing.compact),
            TabBar(
              dividerColor: CandyColors.outline,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              tabs: <Widget>[
                for (final (index, label) in tabs.indexed)
                  Tab(key: WidgetKeys.discoveryDetailsTab(index), text: label),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  DiscoveryDetailsOverview(
                    key: WidgetKeys.discoveryDetails,
                    candidate: candidate,
                  ),
                  if (loadSeries != null)
                    DiscoverySeriesEpisodes(
                      candidate: candidate,
                      load: loadSeries,
                    ),
                  DiscoveryDetailsFacts(candidate: candidate),
                  if (trailers.isNotEmpty)
                    _TrailerList(
                      trailers: trailers,
                      onOpenTrailer: onOpenTrailer,
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

final class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({required this.candidate, required this.imageHeaders});

  final CatalogCandidate candidate;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final meta = <String>[
      discoveryMetaLine(l10n, candidate),
      ?candidate.officialRating,
    ].where((part) => part.isNotEmpty).join('  ·  ');
    final community = candidate.communityRating;
    final critic = candidate.criticRating;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: CandySpacing.cardGap,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(CandyShapes.compact),
          child: SizedBox(
            width: 84,
            height: 126,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: DiscoveryPoster(
                candidate: candidate,
                headers: imageHeaders,
                fit: BoxFit.cover,
                networkWidth: 240,
                cacheWidth: 240,
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CandySpacing.compact / 2,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      candidate.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        height: 1.15,
                      ),
                    ),
                  ),
                  DiscoveryShortlistButton(candidate: candidate),
                ],
              ),
              if (meta.isNotEmpty)
                Text(
                  meta,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (community != null || critic != null)
                Padding(
                  padding: const EdgeInsets.only(top: CandySpacing.compact / 2),
                  child: Wrap(
                    spacing: CandySpacing.compact / 1.5,
                    runSpacing: CandySpacing.compact / 1.5,
                    children: <Widget>[
                      if (community != null)
                        _ScorePill(
                          icon: Icons.star_rounded,
                          value: community.toStringAsFixed(1),
                          label: l10n.discoveryCommunityShort,
                        ),
                      if (critic != null)
                        _ScorePill(
                          icon: Icons.rate_review_outlined,
                          value: critic.toStringAsFixed(0),
                          label: l10n.discoveryCriticsShort,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(CandyShapes.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: <Widget>[
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openDiscoveryTrailer(
  BuildContext context,
  Uri uri,
  TrailerLauncher? onOpenTrailer,
) async {
  final succeeded = await onOpenTrailer?.call(uri) ?? false;
  if (!succeeded && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).discoveryTrailerLaunchError),
      ),
    );
  }
}

final class _TrailerList extends StatelessWidget {
  const _TrailerList({required this.trailers, required this.onOpenTrailer});

  final List<CatalogTrailer> trailers;
  final TrailerLauncher? onOpenTrailer;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(CandySpacing.page),
      itemCount: trailers.length,
      separatorBuilder: (_, _) => const SizedBox(height: CandySpacing.compact),
      itemBuilder: (context, index) {
        final trailer = trailers[index];
        final name = trailer.name?.trim();
        return OutlinedButton.icon(
          key: WidgetKeys.discoveryTrailer(index),
          onPressed: onOpenTrailer == null
              ? null
              : () => openDiscoveryTrailer(context, trailer.uri, onOpenTrailer),
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: Text(
            name == null || name.isEmpty
                ? localization.discoveryPlayTrailerLabel
                : name,
          ),
        );
      },
    );
  }
}

/// Opens the playlists & tags sheet backed by [repository].
Future<void> showDiscoveryOrganizer(
  BuildContext context,
  CatalogCandidate candidate, {
  required LibraryActionsRepository repository,
  List<String> knownTags = const <String>[],
  List<String>? initialTags,
  void Function(String itemId, List<String> tags)? onTagsSaved,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DiscoveryOrganizerSheet(
    candidate: candidate,
    repository: repository,
    knownTags: knownTags,
    initialTags: initialTags,
    onTagsSaved: onTagsSaved,
  ),
);

/// Quick playlist and tag edits for one title, saved straight to Jellyfin.
final class DiscoveryOrganizerSheet extends StatefulWidget {
  const DiscoveryOrganizerSheet({
    required this.candidate,
    required this.repository,
    this.knownTags = const <String>[],
    this.initialTags,
    this.onTagsSaved,
    super.key,
  });

  /// Lets the host refresh its copy of the title after a tag save.
  final void Function(String itemId, List<String> tags)? onTagsSaved;

  final CatalogCandidate candidate;
  final LibraryActionsRepository repository;
  final List<String> knownTags;
  final List<String>? initialTags;

  @override
  State<DiscoveryOrganizerSheet> createState() =>
      _DiscoveryOrganizerSheetState();
}

enum _PlaylistStatus { saving, added, alreadyThere }

final class _DiscoveryOrganizerSheetState
    extends State<DiscoveryOrganizerSheet> {
  final _playlistName = TextEditingController();
  final _tagText = TextEditingController();
  List<LibraryPlaylist>? _playlists;
  List<String>? _tags;
  bool _playlistsFailed = false;
  bool _tagsFailed = false;
  bool _creating = false;
  bool _savingTags = false;
  String? _message;
  final Map<String, _PlaylistStatus> _status = <String, _PlaylistStatus>{};

  String get _itemId => widget.candidate.id;

  /// Shows get tags only: Jellyfin would add every episode to a playlist.
  bool get _tagsOnly => widget.candidate.mediaType == CatalogMediaType.series;

  @override
  void initState() {
    super.initState();
    if (!_tagsOnly) {
      unawaited(_loadPlaylists());
    }
    final initialTags = widget.initialTags;
    if (initialTags == null) {
      unawaited(_loadTags());
    } else {
      _tags = List<String>.of(initialTags);
    }
  }

  @override
  void dispose() {
    _playlistName.dispose();
    _tagText.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylists() async {
    setState(() => _playlistsFailed = false);
    final result = await widget.repository.loadPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = result.value;
      _playlistsFailed = result.value == null;
    });
  }

  Future<void> _loadTags() async {
    setState(() => _tagsFailed = false);
    final result = await widget.repository.loadTags(_itemId);
    if (!mounted) return;
    setState(() {
      _tags = result.value;
      _tagsFailed = result.value == null;
    });
  }

  Future<void> _add(LibraryPlaylist playlist) async {
    if (_status[playlist.id] != null) return;
    setState(() => _status[playlist.id] = _PlaylistStatus.saving);
    final result = await widget.repository.addToPlaylist(
      playlistId: playlist.id,
      itemId: _itemId,
    );
    if (!mounted) return;
    setState(() {
      switch (result.value) {
        case true:
          _status[playlist.id] = _PlaylistStatus.added;
        case false:
          _status[playlist.id] = _PlaylistStatus.alreadyThere;
        case null:
          _status.remove(playlist.id);
          _message = _failureMessage(result.failure);
      }
    });
  }

  Future<void> _create() async {
    final name = _playlistName.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    final result = await widget.repository.createPlaylist(
      name: name,
      itemId: _itemId,
    );
    if (!mounted) return;
    setState(() {
      _creating = false;
      final created = result.value;
      if (created == null) {
        _message = _failureMessage(result.failure);
        return;
      }
      _playlistName.clear();
      _playlists = <LibraryPlaylist>[created, ...?_playlists];
      _status[created.id] = _PlaylistStatus.added;
      _message = null;
    });
  }

  /// Applies a tag change right away and rolls it back if Jellyfin refuses.
  Future<void> _saveTags(List<String> next) async {
    final previous = _tags;
    if (previous == null || _savingTags) return;
    setState(() {
      _tags = next;
      _savingTags = true;
      _message = null;
    });
    final result = await widget.repository.setTags(itemId: _itemId, tags: next);
    if (!mounted) return;
    setState(() {
      _savingTags = false;
      final saved = result.value;
      if (saved == null) {
        _tags = previous;
        _message = result.failure == LibraryActionFailure.notAllowed
            ? AppLocalizations.of(context).discoveryTagsAdminOnly
            : _failureMessage(result.failure);
      } else {
        _tags = saved;
        widget.onTagsSaved?.call(_itemId, saved);
      }
    });
  }

  void _addTag(String raw) {
    final tag = raw.trim();
    final tags = _tags;
    if (tag.isEmpty || tags == null) return;
    _tagText.clear();
    if (tags.any((existing) => existing.toLowerCase() == tag.toLowerCase())) {
      return;
    }
    unawaited(_saveTags(<String>[...tags, tag]));
  }

  String _failureMessage(LibraryActionFailure? failure) {
    final l10n = AppLocalizations.of(context);
    return failure == LibraryActionFailure.expiredSession
        ? l10n.discoveryActionExpired
        : l10n.discoveryActionFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final height = math.max(
      0.0,
      math.min(media.size.height * 0.7, media.size.height - media.padding.top),
    );
    final message = _message;
    return DefaultTabController(
      length: _tagsOnly ? 1 : 2,
      child: SizedBox(
        key: WidgetKeys.discoveryOrganizer,
        height: height,
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CandySpacing.page,
                ),
                child: Text(
                  l10n.discoveryOrganizeTitle(widget.candidate.name),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: CandyTypography.display,
                    fontWeight: CandyTypography.displayWeight,
                  ),
                ),
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CandySpacing.page,
                    CandySpacing.compact,
                    CandySpacing.page,
                    0,
                  ),
                  child: Text(
                    message,
                    key: WidgetKeys.discoveryOrganizerMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: CandySpacing.compact),
              TabBar(
                dividerColor: CandyColors.outline,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                tabs: <Widget>[
                  if (!_tagsOnly)
                    Tab(
                      key: WidgetKeys.discoveryOrganizerTab(0),
                      text: l10n.discoveryPlaylistsTab,
                    ),
                  Tab(
                    key: WidgetKeys.discoveryOrganizerTab(1),
                    text: l10n.discoveryTagsTab,
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    if (!_tagsOnly) _playlistTab(l10n),
                    _tagTab(l10n),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playlistTab(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final playlists = _playlists;
    final Widget list;
    if (playlists == null) {
      list = _playlistsFailed
          ? _RetryRow(onRetry: _loadPlaylists)
          : const Center(child: CircularProgressIndicator());
    } else if (playlists.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.all(CandySpacing.page),
        child: Text(
          l10n.discoveryNoPlaylists,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      list = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: CandySpacing.compact),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final status = _status[playlist.id];
          return ListTile(
            key: WidgetKeys.discoveryPlaylist(playlist.id),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: CandySpacing.page,
            ),
            leading: const Icon(Icons.playlist_play_rounded),
            title: Text(playlist.name),
            onTap: status == null ? () => _add(playlist) : null,
            trailing: switch (status) {
              null => Icon(
                Icons.add_circle_outline_rounded,
                semanticLabel: l10n.discoveryAddToPlaylistLabel(playlist.name),
              ),
              _PlaylistStatus.saving => const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              _PlaylistStatus.added => _StatusLabel(
                icon: Icons.check_circle_rounded,
                text: l10n.discoveryAddedToPlaylist,
                highlight: true,
              ),
              _PlaylistStatus.alreadyThere => _StatusLabel(
                icon: Icons.check_rounded,
                text: l10n.discoveryAlreadyInPlaylist,
              ),
            },
          );
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: list),
        DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: CandyColors.outline)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CandySpacing.page,
                CandySpacing.compact,
                CandySpacing.compact,
                CandySpacing.compact,
              ),
              child: Row(
                spacing: CandySpacing.compact,
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: WidgetKeys.discoveryNewPlaylistField,
                      controller: _playlistName,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _create(),
                      decoration: InputDecoration(
                        hintText: l10n.discoveryNewPlaylistHint,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    key: WidgetKeys.discoveryCreatePlaylist,
                    tooltip: l10n.discoveryCreatePlaylistLabel,
                    onPressed: _creating ? null : _create,
                    icon: _creating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tagTab(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final tags = _tags;
    if (tags == null) {
      return _tagsFailed
          ? _RetryRow(onRetry: _loadTags)
          : const Center(child: CircularProgressIndicator());
    }
    final lower = tags.map((tag) => tag.toLowerCase()).toSet();
    final suggestions = widget.knownTags
        .where((tag) => !lower.contains(tag.toLowerCase()))
        .take(24)
        .toList(growable: false);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final heading = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return ListView(
      padding: const EdgeInsets.all(CandySpacing.page),
      children: <Widget>[
        Row(
          spacing: CandySpacing.compact,
          children: <Widget>[
            Expanded(
              child: TextField(
                key: WidgetKeys.discoveryTagField,
                controller: _tagText,
                enabled: !_savingTags,
                textInputAction: TextInputAction.done,
                onSubmitted: _addTag,
                decoration: InputDecoration(hintText: l10n.discoveryAddTagHint),
              ),
            ),
            IconButton.filled(
              key: WidgetKeys.discoveryAddTag,
              tooltip: l10n.discoveryAddTagLabel,
              onPressed: _savingTags ? null : () => _addTag(_tagText.text),
              icon: _savingTags
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sell_outlined),
            ),
          ],
        ),
        const SizedBox(height: CandySpacing.section - 4),
        Text(l10n.discoveryCurrentTagsTitle, style: heading),
        const SizedBox(height: CandySpacing.compact),
        if (tags.isEmpty)
          Text(l10n.discoveryNoTags, style: muted)
        else
          Wrap(
            spacing: CandySpacing.compact / 1.5,
            runSpacing: CandySpacing.compact / 1.5,
            children: <Widget>[
              for (final tag in tags)
                InputChip(
                  key: WidgetKeys.discoveryTag(tag),
                  label: Text(tag),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  side: BorderSide.none,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  deleteButtonTooltipMessage: l10n.discoveryRemoveTagLabel(tag),
                  deleteIconColor: theme.colorScheme.onPrimaryContainer,
                  onDeleted: _savingTags
                      ? null
                      : () => _saveTags(
                          tags.where((value) => value != tag).toList(),
                        ),
                ),
            ],
          ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: CandySpacing.section - 4),
          Text(l10n.discoverySuggestedTagsTitle, style: heading),
          const SizedBox(height: CandySpacing.compact),
          Wrap(
            spacing: CandySpacing.compact / 1.5,
            runSpacing: CandySpacing.compact / 1.5,
            children: <Widget>[
              for (final tag in suggestions)
                ActionChip(
                  key: WidgetKeys.discoverySuggestedTag(tag),
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tag),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: _savingTags ? null : () => _addTag(tag),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

final class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        Text(text, style: theme.textTheme.labelLarge?.copyWith(color: color)),
      ],
    );
  }
}

final class _RetryRow extends StatelessWidget {
  const _RetryRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: CandySpacing.compact,
        children: <Widget>[
          Text(l10n.discoveryLoadFailed),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(l10n.discoveryRetryLabel),
          ),
        ],
      ),
    );
  }
}

/// One line naming the traits a title shares with the user's taste.
final class _RecommendationReason extends StatelessWidget {
  const _RecommendationReason({required this.reasons});

  final List<AffinityReason> reasons;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final labels = reasons
        .map(
          (reason) => reason.kind == AffinityReasonKind.genre
              ? _capitalized(reason.label)
              : reason.label,
        )
        .join(', ');
    return Row(
      key: WidgetKeys.discoveryRecommendationReason,
      spacing: CandySpacing.compact,
      children: <Widget>[
        Icon(
          Icons.auto_awesome_rounded,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        Expanded(
          child: Text(
            l10n.discoveryRecommendationReason(labels),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  static String _capitalized(String value) => value
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
