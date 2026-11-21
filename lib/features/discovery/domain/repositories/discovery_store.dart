import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';

abstract interface class DiscoveryStore {
  Future<DiscoverySnapshot?> read(String scope);

  Future<void> write(String scope, DiscoverySnapshot snapshot);

  Future<void> clear(String scope);

  /// Whether movies or shows were on screen last time in [scope]; null when
  /// never chosen.
  Future<CatalogMediaType?> readMediaType(String scope);

  Future<void> writeMediaType(String scope, CatalogMediaType mediaType);
}

abstract interface class DiscoverySelector {
  String? select(List<String> candidateIds);

  /// A uniform roll in [0, 1), used to decide weighted choices.
  double nextChance();
}
