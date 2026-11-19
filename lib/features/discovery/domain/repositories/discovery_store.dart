import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';

abstract interface class DiscoveryStore {
  Future<DiscoverySnapshot?> read(String scope);

  Future<void> write(String scope, DiscoverySnapshot snapshot);

  Future<void> clear(String scope);
}

abstract interface class DiscoverySelector {
  String? select(List<String> candidateIds);

  /// A uniform roll in [0, 1), used to decide weighted choices.
  double nextChance();
}
