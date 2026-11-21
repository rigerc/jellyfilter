import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_candidate_card.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

final class DiscoveryShortlistStrip extends StatelessWidget {
  const DiscoveryShortlistStrip({required this.imageHeaders, super.key});

  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final entries = context.select(
      (ShortlistCubit? cubit) => cubit?.state.entries,
    );
    if (entries == null || entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = entries.length == 1
        ? entries.first.title
        : l10n.discoveryShortlistPreviewPair(
            entries.first.title,
            entries[1].title,
          );
    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(
        CandySpacing.gutter,
        0,
        CandySpacing.gutter,
        CandySpacing.compact / 2,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CandyLayout.contentMaxWidth,
        ),
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(CandyShapes.compact),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            hint: l10n.discoveryShortlistViewLabel,
            child: InkWell(
              key: WidgetKeys.discoveryViewShortlist,
              onTap: () => unawaited(
                _showDiscoveryShortlist(context, imageHeaders: imageHeaders),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CandySpacing.minimumTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CandySpacing.compact,
                    vertical: CandySpacing.compact / 2,
                  ),
                  child: Row(
                    spacing: CandySpacing.compact,
                    children: [
                      Icon(
                        Icons.bookmark_rounded,
                        color: scheme.primary,
                        size: 20,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.discoveryShortlistCount(
                                entries.length,
                                context.read<ShortlistCubit>().mediaType.name,
                              ),
                              style: theme.textTheme.labelLarge,
                            ),
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showDiscoveryShortlist(
  BuildContext context, {
  required Map<String, String> imageHeaders,
}) {
  final cubit = context.read<ShortlistCubit>();
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final state = cubit.state;
  if (state.lookup != ShortlistLookup.loading &&
      (!state.useShortlist || state.lookup == ShortlistLookup.idle)) {
    unawaited(cubit.refresh());
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: reduceMotion ? AnimationStyle.noAnimation : null,
    constraints: const BoxConstraints(maxWidth: CandyLayout.contentMaxWidth),
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _ShortlistSheet(imageHeaders: imageHeaders),
    ),
  );
}

final class _ShortlistSheet extends StatefulWidget {
  const _ShortlistSheet({required this.imageHeaders});

  final Map<String, String> imageHeaders;

  @override
  State<_ShortlistSheet> createState() => _ShortlistSheetState();
}

final class _ShortlistSheetState extends State<_ShortlistSheet> {
  ({ShortlistEntry entry, int index})? _removed;
  bool _showSaveError = false;

  Future<void> _remove(ShortlistEntry entry, int index) async {
    final success = await context.read<ShortlistCubit>().remove(entry.id);
    if (mounted) {
      setState(() {
        _showSaveError = !success;
        if (success) {
          _removed = (entry: entry, index: index);
        }
      });
    }
  }

  Future<void> _undo(ShortlistEntry entry, int index) async {
    final success = await context.read<ShortlistCubit>().restore(entry, index);
    if (mounted) {
      setState(() {
        _showSaveError = !success;
        if (success && _removed == (entry: entry, index: index)) {
          _removed = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShortlistCubit>().state;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          key: WidgetKeys.discoveryShortlistSheet,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CandySpacing.gutter,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.discoveryShortlistLabel,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    key: WidgetKeys.discoveryShortlistClose,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (state.entries.isNotEmpty &&
                state.lookup == ShortlistLookup.loading)
              LinearProgressIndicator(
                semanticsLabel: l10n.discoveryShortlistLoading,
              ),
            if (state.entries.isNotEmpty &&
                state.lookup == ShortlistLookup.failed)
              ListTile(
                title: Semantics(
                  liveRegion: true,
                  child: Text(l10n.discoveryShortlistLookupError),
                ),
                trailing: TextButton(
                  key: WidgetKeys.discoveryShortlistSheetRetry,
                  onPressed: context.read<ShortlistCubit>().refresh,
                  child: Text(l10n.discoveryRetryLabel),
                ),
              ),
            Flexible(
              child: state.entries.isEmpty
                  ? Center(
                      heightFactor: 1,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(CandySpacing.page),
                        child: Text(switch ((state.isHydrated, state.lookup)) {
                          (false, ShortlistLookup.failed) =>
                            l10n.discoveryShortlistLookupError,
                          (false, _) => l10n.discoveryShortlistLoading,
                          _ => l10n.discoveryShortlistEmpty(
                            context.read<ShortlistCubit>().mediaType.name,
                          ),
                        }, textAlign: TextAlign.center),
                      ),
                    )
                  : ListView.builder(
                      primary: false,
                      shrinkWrap: true,
                      itemCount: state.entries.length,
                      itemBuilder: (context, index) {
                        final entry = state.entries[index];
                        final movie = state.movies[entry.id];
                        final unavailable =
                            state.lookup == ShortlistLookup.ready &&
                            movie == null;
                        return ListTile(
                          leading: _ShortlistPoster(
                            movie: movie,
                            imageHeaders: widget.imageHeaders,
                          ),
                          title: Text(movie?.name ?? entry.title),
                          subtitle: unavailable
                              ? Text(l10n.discoveryShortlistUnavailable)
                              : null,
                          trailing: IconButton(
                            key: WidgetKeys.discoveryShortlistRemove(entry.id),
                            tooltip: l10n.discoveryShortlistRemoveLabel(
                              movie?.name ?? entry.title,
                            ),
                            onPressed: () => unawaited(_remove(entry, index)),
                            icon: const Icon(Icons.bookmark_remove_outlined),
                          ),
                        );
                      },
                    ),
            ),
            if (_showSaveError)
              Padding(
                padding: const EdgeInsets.all(CandySpacing.compact),
                child: Semantics(
                  liveRegion: true,
                  child: Text(l10n.discoveryShortlistSaveError),
                ),
              ),
            if (_removed case (entry: final entry, index: final index))
              ListTile(
                title: Semantics(
                  liveRegion: true,
                  child: Text(l10n.discoveryShortlistRemoved(entry.title)),
                ),
                trailing: TextButton(
                  key: WidgetKeys.discoveryShortlistUndo,
                  onPressed: () => unawaited(_undo(entry, index)),
                  child: Text(l10n.discoveryShortlistUndoLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _ShortlistPoster extends StatelessWidget {
  const _ShortlistPoster({required this.movie, required this.imageHeaders});

  final CatalogCandidate? movie;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(CandyShapes.compact / 2),
    child: SizedBox(
      width: 32,
      height: 48,
      child: switch (movie) {
        final candidate? => DiscoveryPoster(
          candidate: candidate,
          headers: imageHeaders,
          fit: BoxFit.cover,
          networkWidth: 96,
          cacheWidth: 96,
        ),
        null => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.movie_outlined, size: 18),
        ),
      },
    ),
  );
}
