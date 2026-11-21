import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/application/browse_selection_cubit.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_bulk_playlist_sheet.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

/// Replaces the header while titles are selected: cancel, count, select all.
final class DiscoverySelectionHeader extends StatelessWidget {
  const DiscoverySelectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selection = context.watch<BrowseSelectionCubit>();
    final visibleIds = context.select(
      (DiscoveryCubit cubit) => cubit.state.filteredCandidates
          .map((candidate) => candidate.id)
          .toList(growable: false),
    );
    final count = selection.state.length;
    final allSelected = visibleIds.every(selection.state.contains);
    return Row(
      key: WidgetKeys.discoverySelectionHeader,
      spacing: CandySpacing.compact / 2,
      children: <Widget>[
        IconButton(
          key: WidgetKeys.discoverySelectionCancel,
          tooltip: l10n.discoverySelectionCancelLabel,
          onPressed: selection.clear,
          icon: const Icon(Icons.close_rounded),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.discoverySelectionCount(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: CandyTypography.display,
                fontWeight: CandyTypography.displayWeight,
              ),
            ),
          ),
        ),
        TextButton(
          key: WidgetKeys.discoverySelectAll,
          onPressed: allSelected ? null : () => selection.selectAll(visibleIds),
          child: Text(l10n.discoverySelectAllLabel),
        ),
      ],
    );
  }
}

/// Bulk actions for the selected titles, in place of the bottom navigation.
final class DiscoverySelectionActions extends StatefulWidget {
  const DiscoverySelectionActions({
    this.onToggleFavorite,
    this.onAddToPlaylist,
    super.key,
  });

  final FavoriteToggle? onToggleFavorite;
  final BulkPlaylistAdder? onAddToPlaylist;

  @override
  State<DiscoverySelectionActions> createState() =>
      _DiscoverySelectionActionsState();
}

final class _DiscoverySelectionActionsState
    extends State<DiscoverySelectionActions> {
  bool _busy = false;

  List<CatalogCandidate> _selected() {
    final ids = context.read<BrowseSelectionCubit>().state;
    return context
        .read<DiscoveryCubit>()
        .state
        .filteredCandidates
        .where((candidate) => ids.contains(candidate.id))
        .toList(growable: false);
  }

  /// Runs [action] once at a time, then ends the selection if it worked.
  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(HapticFeedback.selectionClick());
    final selection = context.read<BrowseSelectionCubit>();
    final succeeded = await action();
    if (succeeded) {
      selection.clear();
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _shortlist(
    ShortlistCubit shortlist, {
    required bool remove,
  }) async {
    final l10n = AppLocalizations.of(context);
    final movies = _selected();
    final saved = remove
        ? await shortlist.removeAll(movies.map((movie) => movie.id).toSet())
        : await shortlist.addAll(movies);
    if (mounted) {
      _say(
        !saved
            ? l10n.discoveryShortlistSaveError
            : remove
            ? l10n.discoveryBulkShortlistRemoved(movies.length)
            : l10n.discoveryBulkShortlistAdded(movies.length),
      );
    }
    return saved;
  }

  /// Changes only the titles that differ, all at once.
  Future<bool> _favorite(FavoriteToggle toggle, {required bool remove}) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DiscoveryCubit>();
    final changing = _selected()
        .where((movie) => (movie.favorite == true) == remove)
        .toList(growable: false);
    final done = await Future.wait(
      changing.map(
        (movie) => applyDiscoveryFavoriteToggle(cubit, movie, toggle),
      ),
    );
    final failed = done.where((succeeded) => !succeeded).length;
    if (mounted) {
      _say(
        failed > 0
            ? l10n.discoveryBulkFavoriteFailed(failed)
            : remove
            ? l10n.discoveryBulkUnfavorited(changing.length)
            : l10n.discoveryBulkFavorited(changing.length),
      );
    }
    return failed == 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ids = context.watch<BrowseSelectionCubit>().state;
    final selected = context.select(
      (DiscoveryCubit cubit) => cubit.state.filteredCandidates
          .where((candidate) => ids.contains(candidate.id))
          .toList(growable: false),
    );
    final shortlist = context.read<ShortlistCubit?>();
    final allSaved = context.select(
      (ShortlistCubit? cubit) =>
          cubit != null &&
          selected.isNotEmpty &&
          selected.every((movie) => cubit.state.contains(movie.id)),
    );
    final allFavorite =
        selected.isNotEmpty &&
        selected.every((movie) => movie.favorite == true);
    final toggle = widget.onToggleFavorite;
    final addToPlaylist = widget.onAddToPlaylist;
    final enabled = !_busy && selected.isNotEmpty;
    return DecoratedBox(
      key: WidgetKeys.discoverySelectionActions,
      decoration: const BoxDecoration(
        color: CandyColors.background,
        border: Border(top: BorderSide(color: CandyColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CandySpacing.gutter,
            vertical: CandySpacing.compact / 2,
          ),
          child: Row(
            spacing: CandySpacing.compact / 2,
            children: <Widget>[
              if (shortlist != null)
                _BulkAction(
                  key: WidgetKeys.discoveryBulkShortlist,
                  icon: allSaved
                      ? Icons.bookmark_remove_outlined
                      : Icons.bookmark_add_outlined,
                  label: allSaved
                      ? l10n.discoveryBulkUnshortlistLabel
                      : l10n.discoveryBulkShortlistLabel,
                  tooltip: allSaved
                      ? l10n.discoveryBulkUnshortlistTooltip
                      : l10n.discoveryBulkShortlistTooltip,
                  onPressed: enabled
                      ? () =>
                            _run(() => _shortlist(shortlist, remove: allSaved))
                      : null,
                ),
              if (toggle != null)
                _BulkAction(
                  key: WidgetKeys.discoveryBulkFavorite,
                  icon: allFavorite
                      ? Icons.heart_broken_outlined
                      : Icons.favorite_border_rounded,
                  label: allFavorite
                      ? l10n.discoveryBulkUnfavoriteLabel
                      : l10n.discoveryBulkFavoriteLabel,
                  tooltip: allFavorite
                      ? l10n.discoveryBulkUnfavoriteTooltip
                      : l10n.discoveryBulkFavoriteTooltip,
                  onPressed: enabled
                      ? () => _run(() => _favorite(toggle, remove: allFavorite))
                      : null,
                ),
              if (addToPlaylist != null)
                _BulkAction(
                  key: WidgetKeys.discoveryBulkPlaylist,
                  icon: Icons.playlist_add_rounded,
                  label: l10n.discoveryBulkPlaylistLabel,
                  tooltip: l10n.discoveryBulkPlaylistTooltip,
                  onPressed: enabled
                      ? () => _run(() => addToPlaylist(context, _selected()))
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _BulkAction extends StatelessWidget {
  const _BulkAction({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onPressed == null
        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
        : theme.colorScheme.onSurface;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: onPressed != null,
          label: tooltip,
          excludeSemantics: true,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(CandyShapes.compact),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight:
                    CandySpacing.minimumTouchTarget + CandySpacing.compact,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 2,
                children: <Widget>[
                  Icon(icon, color: color),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: color),
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

/// The round tick on a title while Browse is selecting.
final class DiscoverySelectionMark extends StatelessWidget {
  const DiscoverySelectionMark({
    required this.id,
    required this.selected,
    super.key,
  });

  final String id;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedContainer(
        key: WidgetKeys.discoverySelectionMark(id),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : CandyMotion.quick,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? scheme.primary
              : CandyColors.background.withValues(alpha: 0.6),
          border: Border.all(
            color: selected ? scheme.primary : CandyColors.onDark,
            width: 2,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary)
            : null,
      ),
    );
  }
}
