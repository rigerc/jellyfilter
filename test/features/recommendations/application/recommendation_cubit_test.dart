import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/recommendations/application/recommendation_cubit.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';

import '../../../shared/fake_taste_repository.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20);

  CatalogCandidate movie(
    String id, {
    Set<String> genres = const <String>{},
    double? rating,
    bool watched = false,
  }) => CatalogCandidate(
    id: id,
    name: id,
    mediaType: CatalogMediaType.movie,
    poster: const CatalogImage.fallback(),
    backdrop: const CatalogImage.fallback(),
    genres: genres,
    communityRating: rating,
    watched: watched,
  );

  const director = TastePerson(
    id: 'd1',
    name: 'Agnès Varda',
    role: TasteRole.director,
  );

  test('should fetch nothing until activated', () async {
    final repository = FakeTasteRepository();
    final cubit = RecommendationCubit(repository: repository, now: () => now);

    await cubit.update(
      candidates: <CatalogCandidate>[movie('a')],
      choices: LocalTasteChoices.none,
    );

    expect(repository.historyLoads, 0);
    expect(cubit.state.affinity.isEmpty, isTrue);
    await cubit.close();
  });

  test('should learn from history, people, and their movies', () async {
    final repository = FakeTasteRepository(
      history: <TasteItem>[
        TasteItem(id: 'seen', name: 'Seen', played: true, playCount: 1),
      ],
      items: <String, TasteItem>{
        'seen': TasteItem(
          id: 'seen',
          name: 'Seen',
          people: const <TastePerson>[director],
        ),
      },
      personMovies: <String, Set<String>>{
        'd1': <String>{'seen', 'hers'},
      },
    );
    final cubit = RecommendationCubit(repository: repository, now: () => now);
    final candidates = <CatalogCandidate>[
      movie('popular', rating: 9),
      movie('hers', rating: 5),
    ];
    await cubit.update(candidates: candidates, choices: LocalTasteChoices.none);

    await cubit.activate();

    expect(repository.historyLoads, 1);
    expect(repository.peopleRequests, <Set<String>>[
      <String>{'seen'},
    ]);
    expect(repository.personRequests, <String>['d1']);
    expect(cubit.state.isLearning, isFalse);
    expect(cubit.state.affinity.rankedIds, <String>['hers', 'popular']);
    expect(cubit.state.affinity.reasonsFor('hers').single.label, 'Agnès Varda');
    await cubit.close();
  });

  test('should look up chosen titles that are not in the catalog', () async {
    final repository = FakeTasteRepository(
      items: <String, TasteItem>{
        'elsewhere': TasteItem(
          id: 'elsewhere',
          name: 'Elsewhere',
          genres: const <String>['Comedy'],
        ),
      },
    );
    final cubit = RecommendationCubit(repository: repository, now: () => now);
    await cubit.activate();

    await cubit.update(
      candidates: <CatalogCandidate>[
        movie('serious', genres: const <String>{'drama'}, rating: 9),
        movie('funny', genres: const <String>{'comedy'}),
      ],
      choices: LocalTasteChoices(likedIds: const <String>{'elsewhere'}),
    );

    expect(repository.itemRequests, <Set<String>>[
      <String>{'elsewhere'},
    ]);
    expect(cubit.state.affinity.rankedIds.first, 'funny');
    expect(cubit.state.affinity.hasTaste, isTrue);
    await cubit.close();
  });

  test('should rank from the catalog when history fails', () async {
    final repository = FakeTasteRepository(failHistory: true);
    final cubit = RecommendationCubit(repository: repository, now: () => now);
    await cubit.update(
      candidates: <CatalogCandidate>[
        movie('seen', genres: const <String>{'drama'}, watched: true),
        movie('other', rating: 9),
        movie('drama', genres: const <String>{'drama'}, rating: 5),
      ],
      choices: LocalTasteChoices.none,
    );

    await cubit.activate();

    expect(cubit.state.affinity.rankedIds, <String>['drama', 'other']);

    repository.failHistory = false;
    await cubit.refreshHistory();
    expect(repository.historyLoads, 2);
    await cubit.close();
  });

  test('should skip unchanged input', () async {
    final repository = FakeTasteRepository();
    final cubit = RecommendationCubit(repository: repository, now: () => now);
    final candidates = <CatalogCandidate>[movie('a')];
    await cubit.activate();
    await cubit.update(candidates: candidates, choices: LocalTasteChoices.none);
    final affinity = cubit.state.affinity;

    await cubit.update(candidates: candidates, choices: LocalTasteChoices());

    expect(identical(cubit.state.affinity, affinity), isTrue);
    await cubit.close();
  });
}
