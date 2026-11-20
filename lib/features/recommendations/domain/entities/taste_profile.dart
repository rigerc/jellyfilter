import 'dart:collection';

import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';

enum TasteFeatureKind { genre, studio, tag, decade, director, actor }

/// One trait of a movie, keyed so equal traits from different movies match.
final class TasteFeature {
  const TasteFeature({
    required this.key,
    required this.kind,
    required this.label,
  });

  final String key;
  final TasteFeatureKind kind;
  final String label;

  /// The Jellyfin person id behind a director or actor feature.
  String? get personId => switch (kind) {
    TasteFeatureKind.director || TasteFeatureKind.actor => key.substring(3),
    _ => null,
  };

  TasteRole? get role => switch (kind) {
    TasteFeatureKind.director => TasteRole.director,
    TasteFeatureKind.actor => TasteRole.actor,
    _ => null,
  };
}

/// One piece of evidence about the user's taste and how much it counts.
/// Negative weights mean the user turned similar titles down.
final class TasteSignal {
  const TasteSignal({required this.item, required this.weight});

  final TasteItem item;
  final double weight;
}

/// Accumulated weight per trait. Positive weights mark traits the user
/// enjoys; negative weights mark traits they avoid.
final class TasteProfile {
  TasteProfile({
    Map<String, double> weights = const <String, double>{},
    Map<String, TasteFeature> features = const <String, TasteFeature>{},
  }) : weights = UnmodifiableMapView<String, double>(weights),
       features = UnmodifiableMapView<String, TasteFeature>(features);

  final Map<String, double> weights;

  /// The feature behind each weight key, for labels and person lookups.
  final Map<String, TasteFeature> features;

  bool get hasSignal => weights.values.any((weight) => weight != 0);

  double weightOf(String key) => weights[key] ?? 0;
}
