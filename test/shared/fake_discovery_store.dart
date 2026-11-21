import 'dart:async';

import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';

import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/discovery_store.dart';

final class FakeDiscoveryStore implements DiscoveryStore {
  DiscoverySnapshot? snapshot;
  String? lastScope;
  int clearCount = 0;
  Duration readDelay = Duration.zero;
  Duration writeDelay = Duration.zero;
  Duration clearDelay = Duration.zero;

  @override
  Future<DiscoverySnapshot?> read(String scope) async {
    lastScope = scope;
    await Future<void>.delayed(readDelay);
    return snapshot;
  }

  int writeCount = 0;

  @override
  Future<void> write(String scope, DiscoverySnapshot value) async {
    writeCount++;
    lastScope = scope;
    await Future<void>.delayed(writeDelay);
    snapshot = value;
  }

  @override
  Future<void> clear(String scope) async {
    lastScope = scope;
    await Future<void>.delayed(clearDelay);
    clearCount++;
    snapshot = null;
  }

  CatalogMediaType? mediaType;

  @override
  Future<CatalogMediaType?> readMediaType(String scope) async => mediaType;

  @override
  Future<void> writeMediaType(String scope, CatalogMediaType value) async {
    mediaType = value;
  }
}

/// Answers at once. [snapshot] holds the movie scope; other scopes, such as
/// the shows one, live in [others].
final class ImmediateDiscoveryStore implements DiscoveryStore {
  DiscoverySnapshot? snapshot;
  final Map<String, DiscoverySnapshot> others = <String, DiscoverySnapshot>{};
  CatalogMediaType? mediaType;

  static bool _isPrimary(String scope) => !scope.contains('|');

  @override
  Future<void> clear(String scope) async =>
      _isPrimary(scope) ? snapshot = null : others.remove(scope);

  @override
  Future<DiscoverySnapshot?> read(String scope) async =>
      _isPrimary(scope) ? snapshot : others[scope];

  @override
  Future<void> write(String scope, DiscoverySnapshot value) async {
    if (_isPrimary(scope)) {
      snapshot = value;
    } else {
      others[scope] = value;
    }
  }

  @override
  Future<CatalogMediaType?> readMediaType(String scope) async => mediaType;

  @override
  Future<void> writeMediaType(String scope, CatalogMediaType value) async {
    mediaType = value;
  }
}

final class ControlledDiscoveryStore implements DiscoveryStore {
  final readCompleter = Completer<DiscoverySnapshot?>();
  final clearCompleter = Completer<void>();
  DiscoverySnapshot? snapshot;

  @override
  Future<DiscoverySnapshot?> read(String scope) => readCompleter.future;

  @override
  Future<void> write(String scope, DiscoverySnapshot value) {
    snapshot = value;
    return Future<void>.value();
  }

  @override
  Future<void> clear(String scope) => clearCompleter.future;

  @override
  Future<CatalogMediaType?> readMediaType(String scope) async => null;

  @override
  Future<void> writeMediaType(String scope, CatalogMediaType value) async {}
}

final class FakeDiscoverySelector implements DiscoverySelector {
  FakeDiscoverySelector(this.selectedId);

  final String? selectedId;
  List<String?> choices = <String?>[];
  List<String> receivedIds = <String>[];
  List<List<String>> receivedCalls = <List<String>>[];

  @override
  String? select(List<String> candidateIds) {
    receivedIds = List<String>.of(candidateIds);
    receivedCalls.add(List<String>.of(candidateIds));
    return choices.isEmpty ? selectedId : choices.removeAt(0);
  }

  /// The roll returned to weighted choices; 0.5 unless a test sets it.
  double chance = 0.5;

  @override
  double nextChance() => chance;
}
