import 'dart:math' as math;

import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_profile.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/taste_features.dart';

/// A candidate with its score and the traits that earned it.
final class ScoredTitle {
  const ScoredTitle({
    required this.item,
    required this.score,
    this.reasons = const <TasteFeature>[],
  });

  final TasteItem item;
  final double score;

  /// Positive traits, strongest first.
  final List<TasteFeature> reasons;
}

/// Scores candidates by how much of the taste profile they share.
abstract final class RecommendationScorer {
  /// Breaks ties between otherwise equal candidates.
  static const communityRatingTieBreak = 0.02;
  static const maxReasons = 3;

  /// Scores [candidate] against [profile].
  ///
  /// [people] are the candidate's matches among the profile's strongest
  /// people. When the candidate is itself evidence ([own]), its own
  /// contribution is taken out first so it cannot recommend itself.
  static ScoredTitle score(
    TasteItem candidate,
    TasteProfile profile, {
    Iterable<TasteFeature> people = const <TasteFeature>[],
    TasteSignal? own,
  }) {
    final ownWeights = own == null
        ? const <String, double>{}
        : <String, double>{
            for (final feature in TasteFeatures.of(own.item))
              feature.key:
                  own.weight * TasteFeatures.profileFactor(feature.kind),
          };
    final content = TasteFeatures.of(candidate).where(
      (feature) =>
          feature.kind != TasteFeatureKind.director &&
          feature.kind != TasteFeatureKind.actor,
    );
    var total = 0.0;
    var contentCount = 0;
    final contributions = <(TasteFeature, double)>[];
    void add(TasteFeature feature) {
      final weight =
          profile.weightOf(feature.key) - (ownWeights[feature.key] ?? 0);
      final contribution = weight * TasteFeatures.scoreFactor(feature.kind);
      total += contribution;
      if (contribution > 0 && feature.kind != TasteFeatureKind.decade) {
        contributions.add((
          profile.features[feature.key] ?? feature,
          contribution,
        ));
      }
    }

    for (final feature in content) {
      contentCount++;
      add(feature);
    }
    final seenPeople = <String>{};
    for (final feature in people) {
      if (seenPeople.add(feature.key)) {
        add(feature);
      }
    }
    // Normalizing by trait count keeps heavily tagged titles from winning on
    // tag volume alone; the square root keeps the effect gentle.
    final count = contentCount + TasteFeatures.personSlots;
    final normalized =
        total / math.sqrt(count) +
        (candidate.communityRating ?? 0) * communityRatingTieBreak;
    contributions.sort((left, right) => right.$2.compareTo(left.$2));
    return ScoredTitle(
      item: candidate,
      score: normalized,
      reasons: contributions
          .take(maxReasons)
          .map((entry) => entry.$1)
          .toList(growable: false),
    );
  }

  /// Ranks by community rating alone, for users with no taste yet.
  static ScoredTitle coldStart(TasteItem candidate) =>
      ScoredTitle(item: candidate, score: candidate.communityRating ?? 0);
}
