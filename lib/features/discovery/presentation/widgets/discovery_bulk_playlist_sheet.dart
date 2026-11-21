import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Adds several movies to a playlist from Browse; null hides that action.
/// Resolves to whether any movie was added.
typedef BulkPlaylistAdder =
    Future<bool> Function(BuildContext context, List<CatalogCandidate> movies);

/// Opens the playlist picker for [movies] and reports whether any were added.
Future<bool> showDiscoveryBulkPlaylist(
  BuildContext context,
  List<CatalogCandidate> movies, {
  required LibraryActionsRepository repository,
}) async {
  var added = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DiscoveryBulkPlaylistSheet(
      movies: movies,
      repository: repository,
      onAdded: () => added = true,
    ),
  );
  return added;
}

/// Picks or creates a Jellyfin playlist and adds every selected movie to it.
final class DiscoveryBulkPlaylistSheet extends StatefulWidget {
  const DiscoveryBulkPlaylistSheet({
    required this.movies,
    required this.repository,
    this.onAdded,
    super.key,
  });

  final List<CatalogCandidate> movies;
  final LibraryActionsRepository repository;

  /// Called once a playlist gains at least one of the movies.
  final VoidCallback? onAdded;

  @override
  State<DiscoveryBulkPlaylistSheet> createState() =>
      _DiscoveryBulkPlaylistSheetState();
}

sealed class _RowStatus {
  const _RowStatus();
}

final class _Saving extends _RowStatus {
  const _Saving();
}

/// [added] movies are new to the playlist; the rest were already there.
final class _Done extends _RowStatus {
  const _Done(this.added);

  final int added;
}

final class _DiscoveryBulkPlaylistSheetState
    extends State<DiscoveryBulkPlaylistSheet> {
  final _playlistName = TextEditingController();
  List<LibraryPlaylist>? _playlists;
  bool _playlistsFailed = false;
  bool _creating = false;
  String? _message;
  final Map<String, _RowStatus> _status = <String, _RowStatus>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadPlaylists());
  }

  @override
  void dispose() {
    _playlistName.dispose();
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

  /// Adds each movie in turn; Jellyfin reports duplicates as already there.
  Future<({int added, int failed, LibraryActionFailure? failure})> _addAll(
    String playlistId,
    Iterable<CatalogCandidate> movies,
  ) async {
    var added = 0;
    var failed = 0;
    LibraryActionFailure? failure;
    for (final movie in movies) {
      final result = await widget.repository.addToPlaylist(
        playlistId: playlistId,
        itemId: movie.id,
      );
      switch (result.value) {
        case true:
          added++;
        case false:
          break;
        case null:
          failed++;
          failure ??= result.failure;
      }
    }
    return (added: added, failed: failed, failure: failure);
  }

  Future<void> _add(LibraryPlaylist playlist) async {
    if (_status[playlist.id] is _Saving) return;
    setState(() {
      _status[playlist.id] = const _Saving();
      _message = null;
    });
    final result = await _addAll(playlist.id, widget.movies);
    if (!mounted) return;
    _finish(playlist.id, result);
  }

  Future<void> _create() async {
    final name = _playlistName.text.trim();
    final first = widget.movies.firstOrNull;
    if (name.isEmpty || _creating || first == null) return;
    setState(() {
      _creating = true;
      _message = null;
    });
    final created = await widget.repository.createPlaylist(
      name: name,
      itemId: first.id,
    );
    final playlist = created.value;
    if (playlist == null) {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _message = _failureMessage(created.failure);
      });
      return;
    }
    if (mounted) {
      setState(() {
        _playlistName.clear();
        _playlists = <LibraryPlaylist>[playlist, ...?_playlists];
        _status[playlist.id] = const _Saving();
      });
    }
    final rest = await _addAll(playlist.id, widget.movies.skip(1));
    if (!mounted) return;
    setState(() => _creating = false);
    _finish(playlist.id, (
      added: rest.added + 1,
      failed: rest.failed,
      failure: rest.failure,
    ));
  }

  void _finish(
    String playlistId,
    ({int added, int failed, LibraryActionFailure? failure}) result,
  ) {
    final l10n = AppLocalizations.of(context);
    if (result.added > 0) {
      widget.onAdded?.call();
    }
    setState(() {
      if (result.failed == widget.movies.length) {
        _status.remove(playlistId);
        _message = _failureMessage(result.failure);
        return;
      }
      _status[playlistId] = _Done(result.added);
      _message = result.failed > 0
          ? result.failure == LibraryActionFailure.expiredSession
                ? l10n.discoveryActionExpired
                : l10n.discoveryBulkPlaylistPartial(result.failed)
          : null;
    });
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
    return SizedBox(
      key: WidgetKeys.discoveryBulkPlaylistSheet,
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
                l10n.discoveryBulkPlaylistTitle(widget.movies.length),
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
                  key: WidgetKeys.discoveryBulkPlaylistMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: CandySpacing.compact),
            const Divider(height: 1),
            Expanded(child: _playlistList(l10n)),
            _createRow(l10n),
          ],
        ),
      ),
    );
  }

  Widget _playlistList(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final playlists = _playlists;
    if (playlists == null) {
      if (!_playlistsFailed) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: CandySpacing.compact,
          children: <Widget>[
            Text(l10n.discoveryLoadFailed),
            OutlinedButton(
              onPressed: _loadPlaylists,
              child: Text(l10n.discoveryRetryLabel),
            ),
          ],
        ),
      );
    }
    if (playlists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(CandySpacing.page),
        child: Text(
          l10n.discoveryBulkNoPlaylists,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: CandySpacing.compact),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final status = _status[playlist.id];
        return ListTile(
          key: WidgetKeys.discoveryBulkPlaylistRow(playlist.id),
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
            _Saving() => const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            _Done(added: 0) => _StatusLabel(
              icon: Icons.check_rounded,
              text: l10n.discoveryAlreadyInPlaylist,
            ),
            _Done(:final added) => _StatusLabel(
              icon: Icons.check_circle_rounded,
              text: l10n.discoveryBulkPlaylistAdded(added),
              highlight: true,
            ),
          },
        );
      },
    );
  }

  Widget _createRow(AppLocalizations l10n) {
    return DecoratedBox(
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
                  key: WidgetKeys.discoveryBulkNewPlaylistField,
                  controller: _playlistName,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  decoration: InputDecoration(
                    hintText: l10n.discoveryNewPlaylistHint,
                  ),
                ),
              ),
              IconButton.filled(
                key: WidgetKeys.discoveryBulkCreatePlaylist,
                tooltip: l10n.discoveryBulkCreatePlaylistLabel,
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
