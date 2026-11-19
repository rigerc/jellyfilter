import 'dart:async';

import 'package:jellyfilter/features/catalog/domain/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_filter.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_page.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_result.dart';

abstract interface class CatalogRepository {
  Future<CatalogPage> loadPage({
    CatalogFilter filter = const CatalogFilter(),
    int startIndex = 0,
    CatalogRequestCancellation? cancellation,
    Set<String> excludedIds = const <String>{},
    Set<String> includedIds = const <String>{},
  });

  Future<CatalogResult<List<CatalogLibrary>>> loadLibraries();

  Future<CatalogResult<CatalogFacets>> loadFacets({String? parentId});

  Future<CatalogResult<CatalogCandidate>> loadDetails(String itemId);

  /// The ids of every movie the user has marked as a Jellyfin favorite.
  Future<CatalogResult<Set<String>>> loadFavoriteIds();

  Stream<CatalogPage> streamPages({
    CatalogFilter filter = const CatalogFilter(),
  });
}

/// Cancels one catalog generation without closing the shared HTTP client.
final class CatalogRequestCancellation {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!isCancelled) {
      _cancelled.complete();
    }
  }
}
