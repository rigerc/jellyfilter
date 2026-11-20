import 'dart:math' as math;

import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_profile.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/taste_features.dart';

/// Builds a weighted taste profile from what the user watched and chose.
abstract final class TasteProfileBuilder {
  /// Activity this many days old counts half as much as today's.
  static const recencyHalfLifeDays = 180.0;

  /// Old activity never fades below this share of its weight.
  static const minimumDecay = 0.15;

  /// Weights for Jellyfin's five rating levels (0–10 halved): Terrible, Bad,
  /// Okay, Good, Amazing. A rating replaces the plain-watch weight.
  static const ratingLevelWeights = <double>[-3.0, -1.5, 0.5, 2.0, 3.5];

  /// Evidence from every item the user interacted with, in Jellyfin or
  /// through [choices]. Items without either are skipped.
  static List<TasteSignal> collect(
    Iterable<TasteItem> items,
    LocalTasteChoices choices,
    DateTime now,
  ) {
    final signals = <TasteSignal>[];
    for (final item in items) {
      final local = choices.weightOf(item.id);
      if (!item.hasInteraction && local == null) {
        continue;
      }
      final weight =
          (item.hasInteraction ? jellyfinWeight(item, now) : 0.0) +
          (local ?? 0.0);
      if (weight == 0 || !weight.isFinite) {
        continue;
      }
      signals.add(TasteSignal(item: item, weight: weight));
    }
    return signals;
  }

  static TasteProfile build(Iterable<TasteSignal> signals) {
    final weights = <String, double>{};
    final features = <String, TasteFeature>{};
    for (final signal in signals) {
      for (final feature in TasteFeatures.of(signal.item)) {
        weights[feature.key] =
            (weights[feature.key] ?? 0) +
            signal.weight * TasteFeatures.profileFactor(feature.kind);
        features.putIfAbsent(feature.key, () => feature);
      }
    }
    return TasteProfile(weights: weights, features: features);
  }

  /// How strongly one Jellyfin item counts: an explicit rating, else a
  /// like or dislike, plus favorite and repeat-play boosts, all fading with
  /// time since the last play.
  static double jellyfinWeight(TasteItem item, DateTime now) {
    var weight = 1.0;
    final rating = item.rating;
    if (rating != null && rating > 0) {
      weight = ratingWeight(rating);
    } else if (item.likes == true) {
      weight += 1.0;
    } else if (item.likes == false) {
      weight -= 2.0;
    }
    if (item.favorite) {
      weight += 1.0;
    }
    if (item.playCount > 1) {
      weight += math.min(1.0, (item.playCount - 1) * 0.25);
    }
    return weight * decay(item.lastPlayed, now);
  }

  static double decay(DateTime? lastPlayed, DateTime now) {
    if (lastPlayed == null) {
      return 1.0;
    }
    final ageDays = math.max(
      0,
      now.toUtc().difference(lastPlayed.toUtc()).inSeconds /
          Duration.secondsPerDay,
    );
    return math.max(
      minimumDecay,
      math.pow(0.5, ageDays / recencyHalfLifeDays).toDouble(),
    );
  }

  /// Interpolates between the rating levels so any 0–10 value lands
  /// sensibly, including ratings set by other apps.
  static double ratingWeight(double rating) {
    final level = (rating / 2).clamp(1.0, 5.0) - 1.0;
    final lower = level.floor();
    final upper = math.min(lower + 1, ratingLevelWeights.length - 1);
    final low = ratingLevelWeights[lower];
    return low + (ratingLevelWeights[upper] - low) * (level - lower);
  }
}
