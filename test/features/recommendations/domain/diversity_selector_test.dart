import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/diversity_selector.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/recommendation_scorer.dart';

void main() {
  ScoredTitle title(
    String id,
    double score, {
    String? studio,
    double? rating,
  }) => ScoredTitle(
    item: TasteItem(
      id: id,
      name: id,
      studios: studio == null ? const <String>[] : <String>[studio],
      communityRating: rating,
    ),
    score: score,
  );

  List<String> ids(List<ScoredTitle> titles) =>
      titles.map((title) => title.item.id).toList();

  test('should cap one studio in the window and keep the rest after', () {
    final ordered = DiversitySelector.order(
      <ScoredTitle>[
        title('a1', 9, studio: 'A'),
        title('a2', 8, studio: 'a'),
        title('a3', 7, studio: 'A'),
        title('b1', 6, studio: 'B'),
        title('none', 5),
      ],
      window: 3,
      capPerStudio: 2,
    );
    expect(ids(ordered), <String>['a1', 'a2', 'b1', 'a3', 'none']);
  });

  test('should backfill the window when the cap leaves it short', () {
    final ordered = DiversitySelector.order(
      <ScoredTitle>[
        title('a1', 9, studio: 'A'),
        title('a2', 8, studio: 'A'),
        title('a3', 7, studio: 'A'),
      ],
      window: 3,
      capPerStudio: 1,
    );
    expect(ids(ordered), <String>['a1', 'a2', 'a3']);
  });

  test('should never cap titles without a studio', () {
    final ordered = DiversitySelector.order(
      <ScoredTitle>[
        for (var index = 0; index < 5; index++) title('n$index', 10.0 - index),
      ],
      window: 5,
      capPerStudio: 1,
    );
    expect(ids(ordered), <String>['n0', 'n1', 'n2', 'n3', 'n4']);
  });

  test('should break score ties by rating, then name', () {
    final ordered = DiversitySelector.order(<ScoredTitle>[
      title('b', 1, rating: 7),
      title('c', 1, rating: 8),
      title('a', 1, rating: 7),
    ]);
    expect(ids(ordered), <String>['c', 'a', 'b']);
  });
}
