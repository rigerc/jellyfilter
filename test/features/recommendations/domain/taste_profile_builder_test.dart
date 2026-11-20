import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/taste_profile_builder.dart';

void main() {
  final now = DateTime.utc(2026, 11, 20);

  TasteItem item({
    String id = 'movie',
    bool played = true,
    int playCount = 1,
    bool favorite = false,
    bool? likes,
    double? rating,
    DateTime? lastPlayed,
    List<String> genres = const <String>['Drama'],
    List<TastePerson> people = const <TastePerson>[],
    int? year,
    List<String> studios = const <String>[],
  }) => TasteItem(
    id: id,
    name: id,
    genres: genres,
    studios: studios,
    people: people,
    year: year,
    played: played,
    playCount: playCount,
    favorite: favorite,
    likes: likes,
    rating: rating,
    lastPlayed: lastPlayed,
  );

  group('Jellyfin weight', () {
    test('should count a plain recent watch once', () {
      expect(TasteProfileBuilder.jellyfinWeight(item(), now), 1.0);
    });

    test('should add likes, favorites, and capped repeat plays', () {
      expect(
        TasteProfileBuilder.jellyfinWeight(
          item(likes: true, favorite: true, playCount: 9),
          now,
        ),
        4.0,
      );
    });

    test('should turn a dislike into a negative weight', () {
      expect(TasteProfileBuilder.jellyfinWeight(item(likes: false), now), -1.0);
    });

    test('should let an explicit rating replace the like weight', () {
      expect(
        TasteProfileBuilder.jellyfinWeight(item(rating: 10, likes: true), now),
        3.5,
      );
      expect(TasteProfileBuilder.jellyfinWeight(item(rating: 2), now), -3.0);
    });

    test('should treat a zero rating as no rating', () {
      expect(TasteProfileBuilder.jellyfinWeight(item(rating: 0), now), 1.0);
    });

    test('should interpolate between rating levels', () {
      expect(TasteProfileBuilder.ratingWeight(7), closeTo(1.25, 1e-9));
      expect(TasteProfileBuilder.ratingWeight(0.5), -3.0);
    });

    test('should halve after the half-life and never drop below the floor', () {
      expect(
        TasteProfileBuilder.jellyfinWeight(
          item(lastPlayed: now.subtract(const Duration(days: 180))),
          now,
        ),
        closeTo(0.5, 1e-9),
      );
      expect(
        TasteProfileBuilder.jellyfinWeight(
          item(lastPlayed: now.subtract(const Duration(days: 3650))),
          now,
        ),
        TasteProfileBuilder.minimumDecay,
      );
    });
  });

  group('collect', () {
    test('should skip titles with no interaction or choice', () {
      final signals = TasteProfileBuilder.collect(
        <TasteItem>[item(id: 'unseen', played: false, playCount: 0)],
        LocalTasteChoices.none,
        now,
      );
      expect(signals, isEmpty);
    });

    test('should count swipes and saves on unwatched titles', () {
      final unseen = <TasteItem>[
        for (final id in <String>['liked', 'saved', 'both', 'rejected'])
          item(id: id, played: false, playCount: 0),
      ];
      final signals = TasteProfileBuilder.collect(
        unseen,
        LocalTasteChoices(
          likedIds: const <String>{'liked', 'both'},
          shortlistedIds: const <String>{'saved', 'both'},
          rejectedIds: const <String>{'rejected'},
        ),
        now,
      );
      expect(
        <String, double>{
          for (final signal in signals) signal.item.id: signal.weight,
        },
        <String, double>{
          'liked': 0.75,
          'saved': 0.75,
          'both': 1.0,
          'rejected': -0.5,
        },
      );
    });

    test('should add a local choice to Jellyfin evidence', () {
      final signals = TasteProfileBuilder.collect(
        <TasteItem>[item(id: 'seen')],
        LocalTasteChoices(rejectedIds: const <String>{'seen'}),
        now,
      );
      expect(signals.single.weight, 0.5);
    });
  });

  test('should weigh each trait kind by its profile factor', () {
    final profile = TasteProfileBuilder.build(
      TasteProfileBuilder.collect(
        <TasteItem>[
          item(
            genres: const <String>['Sci-Fi'],
            studios: const <String>['A24'],
            year: 1994,
            people: const <TastePerson>[
              TastePerson(id: 'd1', name: 'Director', role: TasteRole.director),
              TastePerson(id: 'a1', name: 'Actor', role: TasteRole.actor),
            ],
          ),
        ],
        LocalTasteChoices.none,
        now,
      ),
    );
    expect(profile.weights, <String, double>{
      'g:sci-fi': 1.0,
      's:a24': 0.5,
      'd:1990': 0.5,
      'pd:d1': 1.2,
      'pa:a1': 0.8,
    });
    expect(profile.features['pd:d1']?.label, 'Director');
  });

  test('should only count the top-billed actors', () {
    final profile = TasteProfileBuilder.build(
      TasteProfileBuilder.collect(
        <TasteItem>[
          item(
            genres: const <String>[],
            people: <TastePerson>[
              for (var index = 0; index < 8; index++)
                TastePerson(
                  id: 'a$index',
                  name: 'Actor $index',
                  role: TasteRole.actor,
                ),
            ],
          ),
        ],
        LocalTasteChoices.none,
        now,
      ),
    );
    expect(profile.weights.keys, <String>[
      'pa:a0',
      'pa:a1',
      'pa:a2',
      'pa:a3',
      'pa:a4',
    ]);
  });
}
