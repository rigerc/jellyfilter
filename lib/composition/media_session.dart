import 'dart:async';

import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/catalog/application/catalog_cubit.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/recommendations/application/recommendation_cubit.dart';

/// Everything one kind of title needs to be discovered: its catalog, the
/// user's filters and decisions, a shortlist, and recommendations.
///
/// Movies and shows each get one, so switching between them never mixes
/// their filters, decisions, or shortlists.
final class MediaSession {
  MediaSession({
    required this.mediaType,
    required this.catalog,
    required this.discovery,
    required this.shortlist,
    required this.recommendations,
  });

  final CatalogMediaType mediaType;
  final CatalogCubit catalog;
  final DiscoveryCubit discovery;
  final ShortlistCubit shortlist;
  final RecommendationCubit recommendations;

  /// Subscriptions that wire the cubits together; cancelled on [close].
  final List<StreamSubscription<Object?>> subscriptions =
      <StreamSubscription<Object?>>[];

  /// Completes once saved discovery state has been read.
  Future<void>? hydration;

  /// Whether filter changes reload the catalog yet.
  bool listening = false;
  String? loadedFilterFingerprint;
  DiscoveryMode? lastMode;
  DateTime? lastHistoryRefresh;

  Future<void> close() async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await catalog.close();
    await discovery.close();
    await shortlist.close();
    await recommendations.close();
  }
}
