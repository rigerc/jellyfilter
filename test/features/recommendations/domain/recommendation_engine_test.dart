import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/media/entities/media_affinity.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/recommendation_engine.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20);

  test('should rank by community rating when there is no taste yet', () {
    final candidates = <TasteItem>[
      TasteItem(id: 'ok', name: 'Ok', communityRating: 6),
      TasteItem(id: 'great', name: 'Great', communityRating: 9),
    ];
    final result = RecommendationEngine.rank(
      candidates: candidates,
      evidence: candidates,
      choices: LocalTasteChoices.none,
      now: now,
    );
    expect(result.affinity.hasTaste, isFalse);
    expect(result.affinity.rankedIds, <String>['great', 'ok']);
    expect(result.affinity.reasonsFor('great'), isEmpty);
  });

  test('should rank shared traits first and explain them', () {
    final watched = TasteItem(
      id: 'watched',
      name: 'Watched',
      genres: const <String>['Sci-Fi'],
      played: true,
      playCount: 1,
    );
    final candidates = <TasteItem>[
      TasteItem(
        id: 'drama',
        name: 'Drama',
        genres: const <String>['Drama'],
        communityRating: 9,
      ),
      TasteItem(
        id: 'space',
        name: 'Space',
        genres: const <String>['sci-fi'],
        communityRating: 6,
      ),
      watched,
    ];
    final result = RecommendationEngine.rank(
      candidates: candidates,
      evidence: candidates,
      choices: LocalTasteChoices.none,
      now: now,
    );
    expect(result.affinity.hasTaste, isTrue);
    expect(result.affinity.rankedIds, <String>['space', 'drama']);
    expect(result.affinity.reasonsFor('space'), const <AffinityReason>[
      AffinityReason(kind: AffinityReasonKind.genre, label: 'Sci-Fi'),
    ]);
  });

  test('should leave watched, rated, disliked, and rejected titles out', () {
    final candidates = <TasteItem>[
      TasteItem(id: 'watched', name: 'W', played: true),
      TasteItem(id: 'rated', name: 'R', rating: 6),
      TasteItem(id: 'disliked', name: 'D', likes: false),
      TasteItem(id: 'rejected', name: 'X'),
      TasteItem(id: 'fresh', name: 'F'),
    ];
    final result = RecommendationEngine.rank(
      candidates: candidates,
      evidence: candidates,
      choices: LocalTasteChoices(rejectedIds: const <String>{'rejected'}),
      now: now,
    );
    expect(result.affinity.rankedIds, <String>['fresh']);
  });

  test('should match candidates through people in the profile', () {
    const director = TastePerson(
      id: 'd1',
      name: 'Greta Gerwig',
      role: TasteRole.director,
    );
    final evidence = <TasteItem>[
      TasteItem(
        id: 'seen',
        name: 'Seen',
        favorite: true,
        people: const <TastePerson>[director],
      ),
    ];
    final candidates = <TasteItem>[
      TasteItem(id: 'other', name: 'Other', communityRating: 9),
      TasteItem(id: 'hers', name: 'Hers', communityRating: 5),
    ];
    final result = RecommendationEngine.rank(
      candidates: candidates,
      evidence: <TasteItem>[...evidence, ...candidates],
      choices: LocalTasteChoices.none,
      now: now,
      personMovies: const <String, Set<String>>{
        'pd:d1': <String>{'seen', 'hers'},
      },
    );
    expect(result.affinity.rankedIds, <String>['hers', 'other']);
    expect(result.affinity.reasonsFor('hers'), const <AffinityReason>[
      AffinityReason(kind: AffinityReasonKind.person, label: 'Greta Gerwig'),
    ]);
    expect(result.strongestPeople(5), <TastePersonRef>[
      (id: 'd1', role: TasteRole.director),
    ]);
  });

  test('should learn from swipes on unwatched titles', () {
    final candidates = <TasteItem>[
      TasteItem(id: 'liked', name: 'Liked', genres: const <String>['Comedy']),
      TasteItem(
        id: 'rejected',
        name: 'Rejected',
        genres: const <String>['Horror'],
      ),
      TasteItem(id: 'scary', name: 'Scary', genres: const <String>['Horror']),
      TasteItem(id: 'funny', name: 'Funny', genres: const <String>['Comedy']),
      TasteItem(id: 'plain', name: 'Plain'),
    ];
    final result = RecommendationEngine.rank(
      candidates: candidates,
      evidence: candidates,
      choices: LocalTasteChoices(
        likedIds: const <String>{'liked'},
        rejectedIds: const <String>{'rejected'},
      ),
      now: now,
    );
    expect(result.affinity.rankedIds, <String>[
      'funny',
      'liked',
      'plain',
      'scary',
    ]);
    expect(result.strongestEvidenceIds(1), <String>['liked']);
  });
}
