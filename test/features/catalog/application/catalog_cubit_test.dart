import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/catalog/application/catalog_cubit.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_filter.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_page.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_result.dart';
import 'package:jellyfilter/features/catalog/domain/failures/catalog_failure.dart';
import 'package:jellyfilter/features/catalog/domain/repositories/catalog_repository.dart';
import '../../../shared/fake_catalog_repository.dart';

void main() {
  test(
    'should progressively fill the catalog without load-more gestures',
    () async {
      final repository = PagingCatalogRepository(
        pages: {
          for (var start = 0; start < 2000; start += 50)
            start: _pageOf(start, hasMore: start + 50 < 2000),
        },
      );
      final cubit = CatalogCubit(repository);
      final sizes = <int>[];
      final subscription = cubit.stream.listen((state) {
        if (state is CatalogLoaded) sizes.add(state.candidates.length);
      });
      final fullyLoaded = cubit.stream.firstWhere(
        (state) =>
            state is CatalogLoaded &&
            state.candidates.length == 2000 &&
            !state.loadingMore,
      );
      await cubit.load(loadAllPages: true);
      await fullyLoaded;
      expect((cubit.state as CatalogLoaded).candidates, hasLength(2000));
      expect(repository.startIndexes, [for (var i = 0; i < 2000; i += 50) i]);
      expect(sizes, containsAllInOrder([50, 100, 2000]));
      expect((cubit.state as CatalogLoaded).hasMore, isFalse);
      await subscription.cancel();
      await cubit.close();
    },
  );

  test(
    'should stop automatic paging if the server repeats its offset',
    () async {
      final repository = PagingCatalogRepository(
        pages: {0: _pageOf(0, hasMore: true), 50: _pageOf(0, hasMore: true)},
      );
      final cubit = CatalogCubit(repository);
      await cubit.load(loadAllPages: true);
      final state = cubit.state as CatalogLoaded;
      expect(repository.startIndexes, [0, 50]);
      expect(state.candidates, hasLength(50));
      expect(state.hasMore, isFalse);
      expect(state.failure, isA<PartialCatalogFailure>());
      await cubit.close();
    },
  );

  test(
    'should retain the first page and stop automatic paging on failure',
    () async {
      final repository = PagingCatalogRepository(
        pages: {
          0: _pageOf(0, hasMore: true),
          50: const CatalogPage(
            candidates: [],
            hasMore: false,
            nextIndex: 50,
            total: 2000,
            failure: ServerCatalogFailure(),
          ),
        },
      );
      final cubit = CatalogCubit(repository);
      await cubit.load(loadAllPages: true);
      final state = cubit.state as CatalogLoaded;
      expect(repository.startIndexes, [0, 50]);
      expect(state.candidates, hasLength(50));
      expect(state.loadingMore, isFalse);
      expect(state.failure, isA<ServerCatalogFailure>());
      await cubit.close();
    },
  );

  test('should abandon automatic paging after a filter change', () async {
    final repository = ControlledCatalogRepository();
    final cubit = CatalogCubit(repository);
    final oldLoad = cubit.load(loadAllPages: true);
    repository.pageCompleters[0].complete(_pageOf(0, hasMore: true));
    await Future<void>.delayed(Duration.zero);
    expect(repository.pageCompleters, hasLength(2));
    final newLoad = cubit.load(
      filter: const CatalogFilter(searchTerm: 'new'),
      loadAllPages: true,
    );
    repository.pageCompleters[2].complete(_page('new'));
    await newLoad;
    repository.pageCompleters[1].complete(_pageOf(50, hasMore: true));
    await oldLoad;
    expect(repository.pageCompleters, hasLength(3));
    expect((cubit.state as CatalogLoaded).candidates.single.id, 'new');
    await cubit.close();
  });

  group('favorite freshness', () {
    CatalogCandidate movie(String id, {bool? favorite}) => CatalogCandidate(
      id: id,
      name: id,
      mediaType: CatalogMediaType.movie,
      favorite: favorite,
      poster: const CatalogImage.fallback(),
      backdrop: const CatalogImage.fallback(),
    );

    bool? favoriteOf(CatalogCubit cubit, String id) =>
        (cubit.state as CatalogLoaded).candidates
            .firstWhere((candidate) => candidate.id == id)
            .favorite;

    test(
      'should keep a confirmed favorite when the next page is merged',
      () async {
        final repository = PagingCatalogRepository(
          pages: <int, CatalogPage>{
            0: CatalogPage(
              candidates: <CatalogCandidate>[movie('movie-1', favorite: false)],
              hasMore: true,
              nextIndex: 1,
              total: 3,
            ),
            // A page fetched before the change still reports the old value.
            1: CatalogPage(
              candidates: <CatalogCandidate>[
                movie('movie-1', favorite: false),
                movie('movie-2', favorite: false),
              ],
              hasMore: false,
              nextIndex: 3,
              total: 3,
            ),
          },
        );
        final cubit = CatalogCubit(repository);
        await cubit.load();

        final more = cubit.loadMore();
        cubit.setFavorite('movie-1', true);
        await more;

        expect(favoriteOf(cubit, 'movie-1'), isTrue);
        expect(favoriteOf(cubit, 'movie-2'), isFalse);
        await cubit.close();
      },
    );

    test('should correct every loaded title from a Jellyfin sync', () async {
      final repository = PagingCatalogRepository(
        pages: <int, CatalogPage>{
          0: CatalogPage(
            candidates: <CatalogCandidate>[
              movie('movie-1', favorite: true),
              movie('movie-2', favorite: false),
              movie('movie-3', favorite: false),
            ],
            hasMore: false,
            nextIndex: 3,
            total: 3,
          ),
        },
      )..favoriteIds = <String>{'movie-2', 'movie-3'};
      final cubit = CatalogCubit(repository);
      await cubit.load();

      expect(await cubit.syncFavorites(), isTrue);

      expect(favoriteOf(cubit, 'movie-1'), isFalse);
      expect(favoriteOf(cubit, 'movie-2'), isTrue);
      expect(favoriteOf(cubit, 'movie-3'), isTrue);
      await cubit.close();
    });

    test('should leave titles untouched when a sync fails', () async {
      final repository = PagingCatalogRepository(
        pages: <int, CatalogPage>{
          0: CatalogPage(
            candidates: <CatalogCandidate>[movie('movie-1', favorite: true)],
            hasMore: false,
            nextIndex: 1,
            total: 1,
          ),
        },
      );
      final cubit = CatalogCubit(repository);
      await cubit.load();
      final before = cubit.state;

      expect(await cubit.syncFavorites(), isFalse);

      expect(cubit.state, same(before));
      await cubit.close();
    });

    test('should refresh list favorites from freshly loaded details', () async {
      final repository = PagingCatalogRepository(
        pages: <int, CatalogPage>{
          0: CatalogPage(
            candidates: <CatalogCandidate>[movie('movie-1', favorite: false)],
            hasMore: false,
            nextIndex: 1,
            total: 1,
          ),
        },
        details: movie('movie-1', favorite: true),
      );
      final cubit = CatalogCubit(repository);
      await cubit.load();

      await cubit.loadDetails('movie-1');

      expect(favoriteOf(cubit, 'movie-1'), isTrue);
      await cubit.close();
    });

    test('should not let a sync started earlier undo a newer toggle', () async {
      final repository =
          PagingCatalogRepository(
              pages: <int, CatalogPage>{
                0: CatalogPage(
                  candidates: <CatalogCandidate>[
                    movie('movie-1', favorite: false),
                    movie('movie-2', favorite: false),
                  ],
                  hasMore: false,
                  nextIndex: 2,
                  total: 2,
                ),
              },
            )
            // The server has not seen the toggle yet, but knows about movie-2.
            ..favoriteIds = <String>{'movie-2'}
            ..favoriteGate = Completer<void>();
      final cubit = CatalogCubit(repository);
      await cubit.load();

      final sync = cubit.syncFavorites();
      cubit.setFavorite('movie-1', true);
      repository.favoriteGate!.complete();
      await sync;

      expect(favoriteOf(cubit, 'movie-1'), isTrue);
      expect(favoriteOf(cubit, 'movie-2'), isTrue);
      expect(cubit.favoriteOf('movie-1'), isTrue);

      // A sync requested after the toggle is authoritative again.
      repository
        ..favoriteGate = null
        ..favoriteIds = <String>{};
      await cubit.syncFavorites();
      expect(favoriteOf(cubit, 'movie-1'), isFalse);
      await cubit.close();
    });

    test('should patch cached details when a favorite changes', () async {
      final repository = PagingCatalogRepository(
        pages: const <int, CatalogPage>{},
        details: movie('movie-1', favorite: false),
      );
      final cubit = CatalogCubit(repository);
      await cubit.loadDetails('movie-1');

      cubit.setFavorite('movie-1', true);

      expect((await cubit.loadDetails('movie-1')).value?.favorite, isTrue);
      expect(repository.detailCalls, 1);
      await cubit.close();
    });
  });

  test('should stop after one bounded page until more is requested', () async {
    final repository = PagingCatalogRepository(
      pages: <int, CatalogPage>{
        0: _pageOf(0, hasMore: true),
        50: _pageOf(50, hasMore: false),
      },
    );
    final cubit = CatalogCubit(repository);

    await cubit.load();

    final state = cubit.state as CatalogLoaded;
    expect(state.candidates, hasLength(50));
    expect(state.hasMore, isTrue);
    expect(state.loadingMore, isFalse);
    expect(repository.startIndexes, <int>[0]);
    await cubit.close();
  });

  test('should append the next bounded page when more is requested', () async {
    final repository = PagingCatalogRepository(
      pages: <int, CatalogPage>{
        0: _pageOf(0, hasMore: true),
        50: _pageOf(50, hasMore: false),
      },
    );
    final cubit = CatalogCubit(repository);

    await cubit.load();
    await cubit.loadMore();

    final state = cubit.state as CatalogLoaded;
    expect(state.candidates, hasLength(100));
    expect(state.hasMore, isFalse);
    expect(repository.startIndexes, <int>[0, 50]);
    await cubit.close();
  });

  test(
    'should expose Jellyfin libraries and facets with the first page',
    () async {
      const libraries = <CatalogLibrary>[
        CatalogLibrary(
          id: 'movies-id',
          name: 'Movies',
          collectionType: 'movies',
        ),
      ];
      const facets = CatalogFacets(
        genres: <String>['Drama'],
        years: <int>[2024],
        officialRatings: <String>['PG-13'],
      );
      final repository = PagingCatalogRepository(
        pages: <int, CatalogPage>{0: _page('movie-1')},
        libraries: libraries,
        facets: facets,
      );
      final cubit = CatalogCubit(repository);

      await cubit.load();

      final state = cubit.state as CatalogLoaded;
      expect(state.libraries, libraries);
      expect(state.facets, facets);
      await cubit.close();
    },
  );

  test(
    'should expose the first page before supporting metadata returns',
    () async {
      final repository = _DelayedMetadataCatalogRepository(_page('movie-1'));
      final cubit = CatalogCubit(repository);

      final loading = cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<CatalogLoaded>());
      expect((cubit.state as CatalogLoaded).candidates.single.id, 'movie-1');

      repository.libraries.complete(
        const CatalogResult<List<CatalogLibrary>>.success(<CatalogLibrary>[]),
      );
      repository.facets.complete(
        const CatalogResult<CatalogFacets>.success(CatalogFacets()),
      );
      await loading;
      await cubit.close();
    },
  );

  test('should share pending metadata across overlapping loads', () async {
    final repository = _DelayedMetadataCatalogRepository(_page('movie'));
    final cubit = CatalogCubit(repository);
    final first = cubit.load();
    final second = cubit.load();
    expect(repository.libraryCalls, 1);
    expect(repository.facetCalls, 1);
    repository.libraries.complete(
      const CatalogResult.success(<CatalogLibrary>[]),
    );
    repository.facets.complete(const CatalogResult.success(CatalogFacets()));
    await Future.wait([first, second]);
    await cubit.load();
    expect(repository.libraryCalls, 1);
    expect(repository.facetCalls, 1);
    await cubit.close();
  });

  test(
    'should cancel old generations and cancel the current one on close',
    () async {
      final repository = ControlledCatalogRepository();
      final cubit = CatalogCubit(repository);
      final first = cubit.load();
      final second = cubit.load();
      expect(repository.cancellations.first?.isCancelled, isTrue);
      expect(repository.cancellations.last?.isCancelled, isFalse);
      await cubit.close();
      expect(repository.cancellations.last?.isCancelled, isTrue);
      for (final page in repository.pageCompleters) {
        page.complete(_page('ignored'));
      }
      await Future.wait([first, second]);
    },
  );

  test('should share concurrent detail requests', () async {
    final repository = PagingCatalogRepository(
      pages: {},
      details: _page('movie').candidates.single,
    );
    final cubit = CatalogCubit(repository);
    final results = await Future.wait([
      cubit.loadDetails('movie'),
      cubit.loadDetails(' movie '),
    ]);
    expect(repository.detailCalls, 1);
    expect(results.map((result) => result.value?.id), ['movie', 'movie']);
    await cubit.close();
  });

  test('should cache lazily loaded item details by id', () async {
    final details = CatalogCandidate(
      id: 'movie-1',
      name: 'Detailed movie',
      mediaType: CatalogMediaType.movie,
      overview: 'Full synopsis',
      poster: const CatalogImage.fallback(),
      backdrop: const CatalogImage.fallback(),
    );
    final repository = PagingCatalogRepository(
      pages: <int, CatalogPage>{0: _page('movie-1')},
      details: details,
    );
    final cubit = CatalogCubit(repository);

    final first = await cubit.loadDetails('movie-1');
    final second = await cubit.loadDetails('movie-1');

    expect(first.value, same(details));
    expect(second.value, same(details));
    expect(first.failure, isNull);
    expect(repository.detailCalls, 1);
    await cubit.close();
  });

  test('should forward excluded decisions to a replacement batch', () async {
    final repository = PagingCatalogRepository(
      pages: <int, CatalogPage>{0: _page('movie-1')},
    );
    final cubit = CatalogCubit(repository);

    await cubit.load(excludedIds: const <String>{'seen-1', 'seen-2'});

    expect(repository.excludedIdSets.single, const <String>{
      'seen-1',
      'seen-2',
    });
    await cubit.close();
  });

  test('should expose the first catalog page when loading succeeds', () async {
    final cubit = CatalogCubit(
      FakeCatalogRepository(
        const CatalogPage(
          candidates: <CatalogCandidate>[
            CatalogCandidate(
              id: 'movie-1',
              name: 'Candy Movie',
              mediaType: CatalogMediaType.movie,
              poster: CatalogImage.fallback(),
              backdrop: CatalogImage.fallback(),
            ),
          ],
          hasMore: true,
          nextIndex: 50,
          total: 100,
        ),
      ),
    );

    await cubit.load();

    expect(cubit.state, isA<CatalogLoaded>());
    expect((cubit.state as CatalogLoaded).candidates, hasLength(1));
    await cubit.close();
  });

  test('should ignore a late page from an older overlapping load', () async {
    final repository = ControlledCatalogRepository();
    final cubit = CatalogCubit(repository);
    final firstLoad = cubit.load();
    await Future<void>.delayed(Duration.zero);
    final secondLoad = cubit.load();
    await Future<void>.delayed(Duration.zero);

    repository.pageCompleters[1].complete(_page('new'));
    await secondLoad;
    repository.pageCompleters[0].complete(_page('old'));
    await firstLoad;

    final state = cubit.state as CatalogLoaded;
    expect(state.candidates.single.id, 'new');
    await cubit.close();
  });

  test('should retain emitted candidates when a later page fails', () async {
    final cubit = CatalogCubit(
      PagingCatalogRepository(
        pages: <int, CatalogPage>{
          0: CatalogPage(
            candidates: _page('first').candidates,
            hasMore: true,
            nextIndex: 1,
            total: 2,
          ),
          1: const CatalogPage(
            candidates: <CatalogCandidate>[],
            hasMore: false,
            nextIndex: 1,
            total: 2,
            failure: ServerCatalogFailure(),
          ),
        },
      ),
    );

    await cubit.load();
    await cubit.loadMore();

    final state = cubit.state as CatalogLoaded;
    expect(state.candidates.single.id, 'first');
    expect(state.failure, isA<ServerCatalogFailure>());
    await cubit.close();
  });

  test('should deduplicate candidates accumulated across pages', () async {
    final first = CatalogPage(
      candidates: _page('same').candidates,
      hasMore: true,
      nextIndex: 1,
      total: 2,
    );
    final cubit = CatalogCubit(
      PagingCatalogRepository(
        pages: <int, CatalogPage>{0: first, 1: _page('same')},
      ),
    );

    await cubit.load();
    await cubit.loadMore();

    final state = cubit.state as CatalogLoaded;
    expect(state.candidates, hasLength(1));
    await cubit.close();
  });
}

CatalogPage _page(String id) => CatalogPage(
  candidates: <CatalogCandidate>[
    CatalogCandidate(
      id: id,
      name: id,
      mediaType: CatalogMediaType.movie,
      poster: const CatalogImage.fallback(),
      backdrop: const CatalogImage.fallback(),
    ),
  ],
  hasMore: false,
  nextIndex: 1,
  total: 1,
);

CatalogPage _pageOf(int start, {required bool hasMore}) => CatalogPage(
  candidates: List<CatalogCandidate>.generate(
    50,
    (offset) => CatalogCandidate(
      id: 'movie-${start + offset}',
      name: 'Movie ${start + offset}',
      mediaType: CatalogMediaType.movie,
      poster: const CatalogImage.fallback(),
      backdrop: const CatalogImage.fallback(),
    ),
  ),
  hasMore: hasMore,
  nextIndex: start + 50,
  total: 2000,
);

final class _DelayedMetadataCatalogRepository
    extends CatalogRepositoryFakeBase {
  _DelayedMetadataCatalogRepository(this.page);

  final CatalogPage page;
  int libraryCalls = 0;
  int facetCalls = 0;
  final libraries = Completer<CatalogResult<List<CatalogLibrary>>>();
  final facets = Completer<CatalogResult<CatalogFacets>>();

  @override
  Future<CatalogPage> loadPage({
    CatalogFilter filter = const CatalogFilter(),
    int startIndex = 0,
    CatalogRequestCancellation? cancellation,
    Set<String> excludedIds = const <String>{},
    Set<String> includedIds = const <String>{},
  }) async => page;

  @override
  Future<CatalogResult<List<CatalogLibrary>>> loadLibraries() {
    libraryCalls++;
    return libraries.future;
  }

  @override
  Future<CatalogResult<CatalogFacets>> loadFacets({String? parentId}) {
    facetCalls++;
    return facets.future;
  }

  @override
  Stream<CatalogPage> streamPages({
    CatalogFilter filter = const CatalogFilter(),
  }) => const Stream<CatalogPage>.empty();
}
