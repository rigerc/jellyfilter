import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_profile.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/recommendation_scorer.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/taste_features.dart';

void main() {
  const director = TasteFeature(
    key: 'pd:d1',
    kind: TasteFeatureKind.director,
    label: 'Denis Villeneuve',
  );

  TasteProfile profile(Map<String, double> weights) => TasteProfile(
    weights: weights,
    features: <String, TasteFeature>{
      'g:sci-fi': const TasteFeature(
        key: 'g:sci-fi',
        kind: TasteFeatureKind.genre,
        label: 'sci-fi',
      ),
      director.key: director,
    },
  );

  test('should normalize by trait count including person slots', () {
    final scored = RecommendationScorer.score(
      TasteItem(id: 'c', name: 'C', genres: const <String>['Sci-Fi']),
      profile(<String, double>{'g:sci-fi': 2.0}),
    );
    expect(
      scored.score,
      closeTo(2.0 / math.sqrt(1 + TasteFeatures.personSlots), 1e-9),
    );
  });

  test('should boost directors and damp decades', () {
    final scored = RecommendationScorer.score(
      TasteItem(id: 'c', name: 'C', year: 1999),
      profile(<String, double>{'pd:d1': 1.0, 'd:1990': 1.0}),
      people: const <TasteFeature>[director],
    );
    expect(
      scored.score,
      closeTo((1.2 + 0.3) / math.sqrt(1 + TasteFeatures.personSlots), 1e-9),
    );
    expect(scored.reasons.map((reason) => reason.label), <String>[
      'Denis Villeneuve',
    ]);
  });

  test('should push titles with avoided traits down', () {
    final scored = RecommendationScorer.score(
      TasteItem(id: 'c', name: 'C', genres: const <String>['Horror']),
      profile(<String, double>{'g:horror': -2.0}),
    );
    expect(scored.score, lessThan(0));
    expect(scored.reasons, isEmpty);
  });

  test('should break ties with community rating', () {
    final weights = profile(<String, double>{'g:sci-fi': 1.0});
    final better = RecommendationScorer.score(
      TasteItem(
        id: 'a',
        name: 'A',
        genres: const <String>['Sci-Fi'],
        communityRating: 8,
      ),
      weights,
    );
    final worse = RecommendationScorer.score(
      TasteItem(
        id: 'b',
        name: 'B',
        genres: const <String>['Sci-Fi'],
        communityRating: 6,
      ),
      weights,
    );
    expect(better.score - worse.score, closeTo(0.04, 1e-9));
  });

  test('should not let a liked title recommend itself', () {
    final liked = TasteItem(
      id: 'liked',
      name: 'Liked',
      genres: const <String>['Sci-Fi'],
    );
    final scored = RecommendationScorer.score(
      liked,
      profile(<String, double>{'g:sci-fi': 0.75}),
      own: TasteSignal(item: liked, weight: 0.75),
    );
    expect(scored.score, closeTo(0, 1e-9));
    expect(scored.reasons, isEmpty);
  });
}
