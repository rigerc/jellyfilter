import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/discovery/domain/entities/browse_layout.dart';
import 'package:jellyfilter/features/discovery/domain/entities/shuffle_duration.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_snapshot.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_state.dart';
import 'package:jellyfilter/features/discovery/domain/entities/discovery_mode.dart';
import 'package:jellyfilter/features/discovery/domain/serialization/catalog_filter_codec.dart';

void main() {
  test('should round-trip the For you sort without a direction', () {
    const filter = CatalogFilter(sort: CatalogSort.forYou, sortReversed: true);
    final decoded = CatalogFilterCodec.decode(
      CatalogFilterCodec.encode(filter),
    );
    expect(decoded?.sort, CatalogSort.forYou);
    expect(filter.canReverseSort, isFalse);
  });

  test(
    'should round-trip each shuffle duration and include it in snapshot equality',
    () {
      for (final duration in ShuffleDuration.values) {
        final snapshot = DiscoverySnapshot(shuffleDuration: duration);
        final decoded = DiscoverySnapshot.fromJson(snapshot.toJson());
        expect(decoded?.shuffleDuration, duration);
        expect(decoded, snapshot);
        expect(decoded.hashCode, snapshot.hashCode);
        if (duration != ShuffleDuration.standard) {
          expect(snapshot, isNot(const DiscoverySnapshot()));
        }
      }
    },
  );

  test(
    'should restore the standard spin duration for missing or invalid saved settings',
    () {
      final json = const DiscoverySnapshot().toJson();
      expect(
        DiscoverySnapshot.fromJson(
          {...json}..remove('shuffleDuration'),
        )?.shuffleDuration,
        ShuffleDuration.standard,
      );
      for (final value in [null, 'unknown', 123, <String>[]]) {
        expect(
          DiscoverySnapshot.fromJson({
            ...json,
            'shuffleDuration': value,
          })?.shuffleDuration,
          ShuffleDuration.standard,
        );
      }
    },
  );

  test('should round-trip the Browse layout and include it in equality', () {
    for (final layout in BrowseLayout.values) {
      final snapshot = DiscoverySnapshot(browseLayout: layout);
      final decoded = DiscoverySnapshot.fromJson(snapshot.toJson());
      expect(decoded?.browseLayout, layout);
      expect(decoded, snapshot);
      expect(decoded.hashCode, snapshot.hashCode);
    }
    expect(
      const DiscoverySnapshot(browseLayout: BrowseLayout.list),
      isNot(const DiscoverySnapshot()),
    );
  });

  test('should open Browse as a grid for older or invalid saved layouts', () {
    final json = const DiscoverySnapshot(
      browseLayout: BrowseLayout.list,
    ).toJson();
    expect(
      DiscoverySnapshot.fromJson(
        {...json}..remove('browseLayout'),
      )?.browseLayout,
      BrowseLayout.grid,
    );
    for (final value in [null, 'table', 1, <String>[]]) {
      expect(
        DiscoverySnapshot.fromJson({
          ...json,
          'browseLayout': value,
        })?.browseLayout,
        BrowseLayout.grid,
      );
    }
  });

  group('tags, exclusions, and reversed sort', () {
    CatalogCandidate movie({
      Set<String> genres = const <String>{},
      Set<String> tags = const <String>{},
      int? year,
      String? rating,
    }) => CatalogCandidate(
      id: 'movie',
      name: 'Movie',
      mediaType: CatalogMediaType.movie,
      genres: genres,
      tags: tags,
      year: year,
      officialRating: rating,
      poster: const CatalogImage.fallback(),
      backdrop: const CatalogImage.fallback(),
    );

    test('should require every selected tag, ignoring case', () {
      const filter = CatalogFilter(tags: <String>{'Cozy', 'rainy day'});

      expect(filter.isActive, isTrue);
      expect(filter.matches(movie(tags: {'cozy', 'Rainy Day', 'x'})), isTrue);
      expect(filter.matches(movie(tags: {'cozy'})), isFalse);
    });

    test('should reject titles carrying any excluded value', () {
      const filter = CatalogFilter(
        excludedGenres: <String>{'horror'},
        excludedTags: <String>{'Seen it'},
        excludedDecades: <int>{1980},
        excludedOfficialRatings: <String>{'R'},
      );

      expect(filter.isActive, isTrue);
      expect(filter.needsLocalRefinement, isTrue);
      expect(filter.matches(movie(genres: {'Drama'}, year: 1995)), isTrue);
      expect(filter.matches(movie(genres: {'Horror'})), isFalse);
      expect(filter.matches(movie(tags: {'seen it'})), isFalse);
      expect(filter.matches(movie(year: 1987)), isFalse);
      expect(filter.matches(movie(rating: 'r')), isFalse);
    });

    test('should match identically when filters and titles are reused', () {
      final filter = CatalogFilter(
        tags: const <String>{'Cozy'},
        excludedTags: const <String>{'seen it'},
      );
      final yes = movie(tags: const {'cozy'});
      final no = movie(tags: const {'cozy', 'Seen  It'});

      for (var pass = 0; pass < 3; pass++) {
        expect(filter.matches(yes), isTrue);
        expect(filter.matches(no), isFalse);
      }
      expect(
        filter.copyWith(excludedTags: const <String>{}).matches(no),
        isTrue,
      );
    });

    test('should only reverse sorts that have a direction', () {
      expect(
        const CatalogFilter(sort: CatalogSort.title).canReverseSort,
        isTrue,
      );
      expect(const CatalogFilter().canReverseSort, isFalse);
      expect(
        const CatalogFilter(sort: CatalogSort.random).canReverseSort,
        isFalse,
      );
    });

    test('should round trip new fields and default them in older saves', () {
      const filter = CatalogFilter(
        sort: CatalogSort.title,
        sortReversed: true,
        tags: <String>{'cozy'},
        excludedGenres: <String>{'horror'},
        excludedTags: <String>{'seen it'},
        excludedDecades: <int>{1980},
        excludedOfficialRatings: <String>{'R'},
      );
      final encoded = CatalogFilterCodec.encode(filter);

      expect(
        CatalogFilterCodec.encode(CatalogFilterCodec.decode(encoded)!),
        encoded,
      );

      final legacy = <String, Object?>{...encoded}
        ..remove('sortReversed')
        ..remove('tags')
        ..remove('excludedGenres')
        ..remove('excludedTags')
        ..remove('excludedDecades')
        ..remove('excludedOfficialRatings');
      final restored = CatalogFilterCodec.decode(legacy)!;
      expect(restored.sortReversed, isFalse);
      expect(restored.tags, isEmpty);
      expect(restored.hasExclusions, isFalse);

      expect(
        CatalogFilterCodec.decode(<String, Object?>{
          ...encoded,
          'tags': <Object?>[''],
        }),
        isNull,
      );
    });
  });

  test('should round trip every catalog filter field', () {
    const filter = CatalogFilter(
      mediaTypes: <CatalogMediaType>{CatalogMediaType.movie},
      minimumRuntimeMinutes: 10,
      maximumRuntimeMinutes: 180,
      minimumCommunityRating: 6.5,
      maximumCommunityRating: 9.5,
      minimumCriticRating: 5.5,
      maximumCriticRating: 8.5,
      genres: <String>{'Drama', 'Comedy'},
      decades: <int>{1980, 2020},
      watched: true,
      favorite: false,
      searchTerm: ' candy ',
      addedWithin: CatalogAddedWindow.ninetyDays,
      sort: CatalogSort.recentlyAdded,
      officialRatings: <String>{'PG-13'},
    );

    final encoded = CatalogFilterCodec.encode(filter);
    final decoded = CatalogFilterCodec.decode(encoded);

    expect(CatalogFilterCodec.encode(decoded!), encoded);
  });

  test('should discard legacy TV constraints while restoring movies', () {
    final decoded = CatalogFilterCodec.decode(<String, Object?>{
      'mediaTypes': <String>['movie', 'series'],
      'minimumRuntimeMinutes': null,
      'maximumRuntimeMinutes': null,
      'minimumCommunityRating': null,
      'maximumCommunityRating': null,
      'minimumCriticRating': null,
      'maximumCriticRating': null,
      'genres': <String>[],
      'decades': <int>[],
      'seriesStatuses': <String>['continuing'],
      'watched': null,
      'favorite': null,
    });

    expect(decoded?.mediaTypes, <CatalogMediaType>{CatalogMediaType.movie});
    expect(decoded?.seriesStatuses, isEmpty);
  });

  test('should restore old filter snapshots with new defaults', () {
    final decoded = CatalogFilterCodec.decode(<String, Object?>{
      'mediaTypes': <String>[],
      'minimumRuntimeMinutes': null,
      'maximumRuntimeMinutes': null,
      'minimumCommunityRating': null,
      'maximumCommunityRating': null,
      'minimumCriticRating': null,
      'maximumCriticRating': null,
      'genres': <String>[],
      'decades': <int>[],
      'watched': null,
      'favorite': null,
    });

    expect(decoded?.searchTerm, isEmpty);
    expect(decoded?.addedWithin, isNull);
    expect(decoded?.sort, CatalogSort.defaultOrder);
    expect(decoded?.officialRatings, isEmpty);
    expect(decoded?.seriesStatuses, isEmpty);
  });

  test('should accept critic ratings up to one hundred', () {
    final decoded = CatalogFilterCodec.decode(<String, Object?>{
      'mediaTypes': <String>[],
      'minimumRuntimeMinutes': null,
      'maximumRuntimeMinutes': null,
      'minimumCommunityRating': null,
      'maximumCommunityRating': null,
      'minimumCriticRating': 100,
      'maximumCriticRating': 100,
      'genres': <String>[],
      'decades': <int>[],
      'watched': null,
      'favorite': null,
    });

    expect(decoded?.maximumCriticRating, 100);
  });

  test('should reject malformed filter data without throwing', () {
    final decoded = CatalogFilterCodec.decode(<String, Object?>{
      'mediaTypes': <Object?>['unknown'],
    });

    expect(decoded, isNull);
  });

  test('should serialize continuity without catalog media payloads', () {
    const snapshot = DiscoverySnapshot(
      filter: CatalogFilter(
        mediaTypes: <CatalogMediaType>{CatalogMediaType.movie},
      ),
      presets: <String, CatalogFilter>{
        'Favorites': CatalogFilter(favorite: true),
      },
      likedIds: <String>{'liked'},
      rejectedIds: <String>{'rejected'},
      recentPickIds: <String>['liked'],
      mode: DiscoveryMode.shuffle,
      position: 4,
      currentRevealId: 'liked',
      currentPickId: 'liked',
    );

    final json = snapshot.toJson();
    final restored = DiscoverySnapshot.fromJson(json);

    expect(restored, snapshot);
    expect(json.toString(), isNot(contains('poster')));
    expect(json.toString(), isNot(contains('token')));
  });

  test('should preserve hash equality after a snapshot round trip', () {
    const snapshot = DiscoverySnapshot(
      filter: CatalogFilter(favorite: true),
      presets: <String, CatalogFilter>{
        'Movies': CatalogFilter(
          mediaTypes: <CatalogMediaType>{CatalogMediaType.movie},
        ),
      },
      likedIds: <String>{'liked'},
      rejectedIds: <String>{'rejected'},
      recentPickIds: <String>['liked'],
    );

    final restored = DiscoverySnapshot.fromJson(snapshot.toJson());

    expect(restored.hashCode, snapshot.hashCode);
  });

  test('should recover from unsupported snapshot versions', () {
    final restored = DiscoverySnapshot.fromJson(<String, Object?>{
      'version': 999,
    });

    expect(restored, isNull);
  });

  test('should normalize overlapping and invalid decision IDs', () {
    final restored = DiscoverySnapshot.fromJson(<String, Object?>{
      'version': 1,
      'filter': CatalogFilterCodec.encode(const CatalogFilter()),
      'presets': <String, Object?>{},
      'likedIds': <String>['liked', 'shared', ''],
      'rejectedIds': <String>['shared', 'rejected', ''],
      'recentPickIds': <String>['liked', 'shared', ''],
      'mode': 'grid',
      'position': 0,
      'currentRevealId': '',
      'currentPickId': '',
    });

    expect(restored?.likedIds, <String>{'liked'});
    expect(restored?.rejectedIds, <String>{'shared', 'rejected'});
    expect(restored?.recentPickIds, <String>['liked']);
    expect(restored?.currentRevealId, isNull);
    expect(restored?.currentPickId, isNull);
  });

  test('should reject oversized and invalid snapshot collections', () {
    final presets = <String, Object?>{
      for (var index = 0; index < 21; index++)
        'Preset $index': CatalogFilterCodec.encode(const CatalogFilter()),
    };
    final restored = DiscoverySnapshot.fromJson(<String, Object?>{
      'version': 1,
      'filter': CatalogFilterCodec.encode(const CatalogFilter()),
      'presets': presets,
      'likedIds': List<String>.generate(101, (index) => 'liked-$index'),
      'rejectedIds': <String>[],
      'recentPickIds': <String>[],
      'mode': 'grid',
      'position': 0,
    });

    expect(restored, isNull);
  });

  test(
    'should normalize valid preset names and reject invalid filter ranges',
    () {
      final restored = DiscoverySnapshot.fromJson(<String, Object?>{
        'version': 1,
        'filter': <String, Object?>{
          'mediaTypes': <String>[],
          'minimumRuntimeMinutes': 90,
          'maximumRuntimeMinutes': 10,
          'minimumCommunityRating': null,
          'maximumCommunityRating': null,
          'minimumCriticRating': null,
          'maximumCriticRating': null,
          'genres': <String>[],
          'decades': <int>[2020],
          'watched': null,
          'favorite': null,
        },
        'presets': <String, Object?>{
          '  Saved  ': CatalogFilterCodec.encode(const CatalogFilter()),
        },
        'likedIds': <String>[],
        'rejectedIds': <String>[],
        'recentPickIds': <String>[],
        'mode': 'grid',
        'position': 0,
      });

      expect(restored, isNull);
    },
  );

  test('should keep unliked matches eligible after browsing decisions', () {
    const movie = CatalogCandidate(
      id: 'movie',
      name: 'Movie',
      mediaType: CatalogMediaType.movie,
      poster: CatalogImage.fallback(),
      backdrop: CatalogImage.fallback(),
    );
    const series = CatalogCandidate(
      id: 'series',
      name: 'Series',
      mediaType: CatalogMediaType.series,
      poster: CatalogImage.fallback(),
      backdrop: CatalogImage.fallback(),
    );
    final state = DiscoveryState(
      candidates: <CatalogCandidate>[movie, _candidate('fresh'), series],
      likedIds: <String>{'movie'},
      rejectedIds: <String>{'series'},
    );

    expect(state.undecidedCandidates.single.id, 'fresh');
    expect(state.eligibleCandidates.map((candidate) => candidate.id), <String>[
      'movie',
      'fresh',
    ]);
  });

  test('should let rejected decisions win over likes', () {
    final state = DiscoveryState(
      candidates: <CatalogCandidate>[_candidate('shared'), _candidate('liked')],
      likedIds: <String>{'shared', 'liked'},
      rejectedIds: <String>{'shared'},
    );

    expect(state.eligibleCandidates.map((item) => item.id), <String>['liked']);
  });

  test('should defensively copy mutable discovery collections', () {
    final candidates = <CatalogCandidate>[_candidate('movie')];
    final likedIds = <String>{'movie'};
    final presets = <String, CatalogFilter>{
      'Saved': const CatalogFilter(favorite: true),
    };
    final state = DiscoveryState(
      candidates: candidates,
      likedIds: likedIds,
      presets: presets,
    );
    candidates.clear();
    likedIds.clear();
    presets.clear();

    expect(state.candidates, hasLength(1));
    expect(state.likedIds, contains('movie'));
    expect(state.presets, contains('Saved'));
  });

  test('should prevent nested candidate and filter mutation', () {
    final state = DiscoveryState(
      candidates: <CatalogCandidate>[
        CatalogCandidate(
          id: 'movie',
          name: 'movie',
          mediaType: CatalogMediaType.movie,
          genres: <String>{'Drama'},
          cast: <String>['Actor'],
          poster: const CatalogImage.fallback(),
          backdrop: const CatalogImage.fallback(),
        ),
      ],
      filter: const CatalogFilter(genres: <String>{'Drama'}),
      presets: const <String, CatalogFilter>{
        'Saved': CatalogFilter(genres: <String>{'Drama'}),
      },
    );

    expect(
      () => state.candidates.single.genres.add('Comedy'),
      throwsUnsupportedError,
    );
    expect(
      () => state.candidates.single.cast.add('Actor 2'),
      throwsUnsupportedError,
    );
    expect(() => state.filter.genres.add('Comedy'), throwsUnsupportedError);
    final saved = state.presets['Saved'];
    expect(saved, isNotNull);
    if (saved != null) {
      expect(() => saved.genres.add('Comedy'), throwsUnsupportedError);
    }
  });
}

CatalogCandidate _candidate(String id) => CatalogCandidate(
  id: id,
  name: id,
  mediaType: CatalogMediaType.movie,
  poster: const CatalogImage.fallback(),
  backdrop: const CatalogImage.fallback(),
);
