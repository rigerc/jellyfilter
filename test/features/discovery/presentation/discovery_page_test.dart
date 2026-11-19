import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/discovery/domain/entities/shuffle_duration.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_header.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_facets.dart';
import 'package:jellyfilter/features/catalog/domain/entities/catalog_library.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../../../shared/discovery_robot.dart';
import '../../../shared/favorite_repository_fake.dart';
import '../../../shared/fake_discovery_store.dart';

void main() {
  testWidgets('should scope discovery with Jellyfin libraries and facets', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(
      tester,
      cubit,
      libraries: const <CatalogLibrary>[
        CatalogLibrary(
          id: 'movies-id',
          name: 'Movies',
          collectionType: 'movies',
        ),
      ],
      facets: const CatalogFacets(
        genres: <String>['Server Drama'],
        years: <int>[1997],
        officialRatings: <String>['R'],
      ),
    );
    await robot.openQuickFilters();

    robot.expectLibrarySelectorVisible();
    await robot.expectServerFacetsVisible(
      genre: 'Server Drama',
      decade: 1990,
      rating: 'R',
    );
    await robot.selectLibraryAndApply('Movies');

    expect(cubit.state.filter.libraryId, 'movies-id');
    await cubit.close();
  });

  testWidgets('should clear a saved library that is no longer accessible', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.updateFilter(const CatalogFilter(libraryId: 'removed-id'));
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(
      tester,
      cubit,
      libraries: const <CatalogLibrary>[
        CatalogLibrary(
          id: 'movies-id',
          name: 'Movies',
          collectionType: 'movies',
        ),
      ],
    );
    await robot.openQuickFilters();

    final field = tester.widget<DropdownButtonFormField<String?>>(
      find.byKey(WidgetKeys.discoveryLibraryField),
    );
    expect(field.initialValue, isNull);
    await cubit.close();
  });

  testWidgets('should lazily replace summary data when details open', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(overview: null),
    ]);
    final details = Completer<CatalogCandidate?>();
    final robot = DiscoveryRobot(tester);
    var calls = 0;

    await _pumpPage(
      tester,
      cubit,
      onLoadDetails: (candidate) {
        calls++;
        return details.future;
      },
    );
    await robot.openFirstDetails();

    robot.expectDetailsLoading();
    details.complete(_candidate(overview: 'Loaded from Jellyfin.'));
    await tester.pumpAndSettle();

    robot.expectDetailsSynopsis('Loaded from Jellyfin.');
    robot.expectTrailersNotVisible();
    expect(calls, 1);
    await cubit.close();
  });

  testWidgets('should open a Jellyfin trailer from loaded movie details', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(overview: null),
    ]);
    final trailerUri = Uri.parse('https://trailers.example/movie-1');
    final robot = DiscoveryRobot(tester);
    Uri? launchedUri;

    await _pumpPage(
      tester,
      cubit,
      onLoadDetails: (candidate) async => _candidate(
        trailers: <CatalogTrailer>[
          CatalogTrailer(name: 'Official trailer', uri: trailerUri),
        ],
      ),
      onOpenTrailer: (uri) async {
        launchedUri = uri;
        return true;
      },
    );
    await robot.openFirstDetails();
    await tester.pumpAndSettle();

    await robot.expectTrailerVisible(0, 'Official trailer');
    await robot.playTrailer(0);

    expect(launchedUri, trailerUri);
    await cubit.close();
  });

  testWidgets('should request another bounded page near the grid end', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(
      List<CatalogCandidate>.generate(
        20,
        (index) => _candidate(id: 'movie-$index', name: 'Movie $index'),
      ),
    );
    final robot = DiscoveryRobot(tester);
    var calls = 0;

    await _pumpPage(
      tester,
      cubit,
      onLoadMore: () async {
        calls++;
      },
    );
    await robot.scrollGridToBottom();
    await tester.pump();

    expect(calls, 1);
    await cubit.close();
  });

  testWidgets('should render Jellyfin blurhash without a preview request', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(
        poster: _networkPoster(blurHash: 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH'),
      ),
    ]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);

    robot.expectPosterBlurHashVisible('movie-1');
    robot.expectNoPosterPreviewRequest();
    await cubit.close();
  });

  testWidgets('should preserve the shared session across all peer modes', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    robot.expectPeerModesVisible();
    robot.expectGridVisible();
    await robot.openSwipe();
    robot.expectSwipeVisible();
    robot.expectCandidateVisible('Candy Comet');
    await robot.openShuffle();
    robot.expectShuffleVisible();
    await robot.reveal();
    robot.expectCandidateVisible('Candy Comet');

    expect(cubit.state.candidates.single.id, 'movie-1');
    await cubit.close();
  });

  testWidgets('should keep mode navigation persistent across peer modes', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    expect(find.byType(NavigationBar), findsOneWidget);

    await robot.openSwipe();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await cubit.close();
  });

  testWidgets('should present a compact task-focused discovery header', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    final header = find.ancestor(
      of: find.byKey(WidgetKeys.discoveryFilterButton),
      matching: find.byType(DiscoveryHeader),
    );

    expect(
      tester.getSize(header).height,
      lessThanOrEqualTo(CandySpacing.minimumTouchTarget * 2),
    );
    robot.expectCompactDiscoveryHeader(candidateCount: 1);
    expect(find.byType(PopupMenuButton<void>), findsOneWidget);
    await cubit.close();
  });

  testWidgets('should open clear discovery from the compact overflow', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);

    await _pumpPage(tester, cubit);
    await tester.tap(find.byKey(WidgetKeys.discoveryMoreButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryClearButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await cubit.close();
  });

  testWidgets(
    'should fill the usable viewport when the grid has multiple rows',
    (tester) async {
      tester.view.physicalSize = const Size(360, 808);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = _cubit();
      await cubit.replaceCandidates(
        List<CatalogCandidate>.generate(
          20,
          (index) => _candidate(id: 'movie-$index', name: 'Movie $index'),
        ),
      );
      final robot = DiscoveryRobot(tester);

      await _pumpPage(
        tester,
        cubit,
        topInset: CandySpacing.page,
        bottomInset: CandySpacing.page,
        bottomViewInset: 120,
      );

      robot.expectGridMeetsModeNavigation();
      await cubit.close();
    },
  );

  testWidgets('should fill a tall Android viewport without a keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 923);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = _cubit();
    await cubit.replaceCandidates(
      List<CatalogCandidate>.generate(
        200,
        (index) => _candidate(id: 'movie-$index', name: 'Movie $index'),
      ),
    );
    final robot = DiscoveryRobot(tester);

    await _pumpPage(
      tester,
      cubit,
      topInset: CandySpacing.page,
      bottomInset: CandySpacing.page,
    );

    robot.expectGridMeetsModeNavigation();
    await cubit.close();
  });

  testWidgets(
    'should fill the screenshot-sized Android viewport without a keyboard inset',
    (tester) async {
      tester.view.physicalSize = const Size(393, 881);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = _cubit();
      await cubit.replaceCandidates(
        List<CatalogCandidate>.generate(
          20,
          (index) => _candidate(id: 'movie-$index', name: 'Movie $index'),
        ),
      );
      final robot = DiscoveryRobot(tester);

      await _pumpPage(
        tester,
        cubit,
        topInset: CandySpacing.page,
        bottomInset: CandySpacing.page,
      );

      robot.expectGridMeetsModeNavigation();
      await cubit.close();
    },
  );

  testWidgets('should reach the final row when the tall-phone grid scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 808);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = _cubit();
    await cubit.replaceCandidates(
      List<CatalogCandidate>.generate(
        20,
        (index) => _candidate(id: 'movie-$index', name: 'Movie $index'),
      ),
    );
    final robot = DiscoveryRobot(tester);

    await _pumpPage(
      tester,
      cubit,
      topInset: CandySpacing.page,
      bottomInset: CandySpacing.page,
      bottomViewInset: 120,
    );
    await robot.scrollGridToBottom();

    robot.expectGridCandidateVisible('movie-19');
    await cubit.close();
  });

  testWidgets('should show balanced localized details when a title opens', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openFirstDetails();

    await tester.pumpAndSettle();
    await robot.expectDetailsVisible();
    robot.expectNoBlankAreaBelowDetails();
    await cubit.close();
  });

  testWidgets(
    'should avoid blank details space with a bottom inset in dark mode',
    (tester) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);

      await _pumpPage(
        tester,
        cubit,
        brightness: Brightness.dark,
        bottomInset: CandySpacing.page,
      );
      await robot.openFirstDetails();

      robot.expectNoBlankAreaBelowDetails(bottomInset: CandySpacing.page);
      await cubit.close();
    },
  );

  testWidgets('should keep long details scrollable on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(overview: List<String>.filled(20, 'Long synopsis.').join(' ')),
    ]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openFirstDetails();

    robot.expectDetailsScrollable();
    await robot.scrollDetailsToBottom();
    robot.expectNoBlankAreaBelowDetails();
    await cubit.close();
  });

  testWidgets('should synchronize a favorite without changing decisions', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);
    var calls = 0;

    await _pumpPage(
      tester,
      cubit,
      onToggleFavorite: (candidate) async {
        calls++;
        return true;
      },
    );
    await robot.toggleFirstFavorite();

    expect(calls, 1);
    expect(cubit.state.candidates.single.favorite, isTrue);
    expect(cubit.state.likedIds, isEmpty);
    expect(cubit.state.rejectedIds, isEmpty);
    await cubit.close();
  });

  testWidgets('should not expose media type or series filters', (tester) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();

    expect(find.byKey(WidgetKeys.discoveryMovieFilter), findsNothing);
    expect(find.byKey(WidgetKeys.discoverySeriesFilter), findsNothing);
    expect(find.text('Series status'), findsNothing);
    await cubit.close();
  });

  testWidgets('should expose quick filters and active filter state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    robot.expectQuickFiltersHiddenFromDiscovery();
    robot.expectFiltersInactive();
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
    robot.expectQuickFiltersVisibleInSheet();
    expect(
      tester.getSemantics(find.byKey(WidgetKeys.discoveryRecentFilter)).label,
      contains('Added in last 30 days'),
    );
    expect(
      tester
          .getSemantics(find.byKey(WidgetKeys.discoveryUnwatchedFilter))
          .label,
      contains('Unwatched'),
    );
    expect(
      tester
          .getSemantics(find.byKey(WidgetKeys.discoveryFavoritesFilter))
          .label,
      contains('Favorites'),
    );
    await tester.tap(find.byKey(WidgetKeys.discoveryRecentFilter));
    await tester.pump();
    await tester.tap(find.byKey(WidgetKeys.discoveryUnwatchedFilter));
    await tester.pump();
    await tester.tap(find.byKey(WidgetKeys.discoveryFavoritesFilter));
    await tester.pump();
    await robot.applyOpenFilters();

    expect(cubit.state.filter.isActive, isTrue);
    expect(cubit.state.filter.addedWithin, CatalogAddedWindow.thirtyDays);
    expect(cubit.state.filter.watched, isFalse);
    expect(cubit.state.filter.favorite, isTrue);
    robot.expectFiltersActive();
    semantics.dispose();
    await cubit.close();
  });

  testWidgets('should combine search, recent, and metadata filters', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.applyAdvancedFilters();

    expect(cubit.state.filter.searchTerm, 'Candy');
    expect(cubit.state.filter.sort, CatalogSort.recentlyAdded);
    expect(cubit.state.filter.addedWithin, CatalogAddedWindow.thirtyDays);
    expect(cubit.state.filter.genres, <String>{'mystery'});
    expect(cubit.state.filter.decades, <int>{2020});
    expect(cubit.state.filter.officialRatings, <String>{'PG-13'});
    expect(cubit.state.filter.seriesStatuses, isEmpty);
    await cubit.close();
  });

  testWidgets('should show supplied search artwork in the filter sheet', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();

    robot.expectSearchArtworkVisible();
    await cubit.close();
  });

  testWidgets('should preserve restored maximum ratings when reapplied', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.updateFilter(
      const CatalogFilter(maximumCommunityRating: 9, maximumCriticRating: 95),
    );
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);

    await _pumpPage(tester, cubit);
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryApplyFilters));
    await tester.pumpAndSettle();

    expect(cubit.state.filter.maximumCommunityRating, 9);
    expect(cubit.state.filter.maximumCriticRating, 95);
    await cubit.close();
  });

  testWidgets('should meet mobile accessibility guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);

    await _pumpPage(tester, cubit);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
    await cubit.close();
  });

  testWidgets('should save a named filter preset locally', (tester) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.savePreset('Movie night');

    expect(cubit.state.presets.keys, contains('Movie night'));
    await cubit.close();
  });

  testWidgets('should save the filters edited in the sheet as a preset', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();
    await tester.tap(find.byKey(WidgetKeys.discoveryUnwatchedFilter));
    await tester.pump();
    await robot.openFilterTab(3);
    final saveButton = find.byKey(WidgetKeys.discoverySavePreset);
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(WidgetKeys.discoveryFilterSheet),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(WidgetKeys.discoveryPresetName),
      'Fresh picks',
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(cubit.state.presets['Fresh picks']?.watched, isFalse);
    expect(cubit.state.filter.watched, isNull);
    await cubit.close();
  });

  testWidgets('should show suggested presets when no saved presets exist', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();
    await robot.openFilterTab(3);

    for (final id in <String>[
      'unwatched',
      'favorites',
      'new_and_unseen',
      'unwatched_gems',
      'short_gems',
      'critics_picks',
    ]) {
      expect(
        find.byKey(WidgetKeys.discoverySuggestedPreset(id)),
        findsOneWidget,
      );
    }
    expect(find.text('Suggested presets'), findsOneWidget);
    expect(cubit.state.presets, isEmpty);
    await cubit.close();
  });

  testWidgets('should apply a suggested preset filter', (tester) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();
    await robot.openFilterTab(3);
    await tester.tap(
      find.byKey(WidgetKeys.discoverySuggestedPreset('unwatched_gems')),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.filter.watched, isFalse);
    expect(cubit.state.filter.minimumCommunityRating, 7.5);
    expect(find.byKey(WidgetKeys.discoveryFilterSheet), findsNothing);
    await cubit.close();
  });

  testWidgets('should delete a saved preset from the presets tab', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.savePreset('Movie night');
    await tester.tap(find.byKey(WidgetKeys.discoveryApplyFilters));
    await tester.pumpAndSettle();
    await robot.openQuickFilters();
    await robot.openFilterTab(3);
    await tester.scrollUntilVisible(
      find.byKey(WidgetKeys.discoveryPreset('Movie night')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(WidgetKeys.discoveryFilterSheet),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .last,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(WidgetKeys.discoveryPreset('Movie night')),
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.presets.containsKey('Movie night'), isFalse);
    expect(find.byKey(WidgetKeys.discoveryPreset('Movie night')), findsNothing);
    await cubit.close();
  });

  testWidgets('should apply an advanced suggested preset filter', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();
    await robot.openFilterTab(3);
    await tester.tap(
      find.byKey(WidgetKeys.discoverySuggestedPreset('new_and_unseen')),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.filter.watched, isFalse);
    expect(cubit.state.filter.addedWithin, CatalogAddedWindow.thirtyDays);
    expect(find.byKey(WidgetKeys.discoveryFilterSheet), findsNothing);
    await cubit.close();
  });

  testWidgets('should keep suggested presets after reset and clear', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();
    await robot.openFilterTab(3);
    await tester.tap(
      find.byKey(WidgetKeys.discoverySuggestedPreset('unwatched')),
    );
    await tester.pumpAndSettle();
    expect(cubit.state.filter.watched, isFalse);

    await cubit.resetFilters();
    await tester.pumpAndSettle();
    await robot.openQuickFilters();
    await robot.openFilterTab(3);
    expect(
      find.byKey(WidgetKeys.discoverySuggestedPreset('unwatched')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(WidgetKeys.discoveryApplyFilters));
    await tester.pumpAndSettle();

    await cubit.clearDiscovery();
    await tester.pumpAndSettle();
    await robot.openQuickFilters();
    await robot.openFilterTab(3);
    expect(
      find.byKey(WidgetKeys.discoverySuggestedPreset('favorites')),
      findsOneWidget,
    );
    await cubit.close();
  });

  testWidgets('should badge filter tabs with their active choice count', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openQuickFilters();
    final basicsTab = find.byKey(WidgetKeys.discoveryFilterTab(0));
    expect(
      find.descendant(of: basicsTab, matching: find.text('2')),
      findsNothing,
    );

    await tester.tap(find.byKey(WidgetKeys.discoveryUnwatchedFilter));
    await tester.tap(find.byKey(WidgetKeys.discoveryFavoritesFilter));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: basicsTab, matching: find.text('2')),
      findsOneWidget,
    );
    expect(find.text('2 active'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('should hide the active filter strip when nothing is filtered', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);

    await _pumpPage(tester, cubit);

    expect(find.byKey(WidgetKeys.discoveryActiveFilters), findsNothing);
    await cubit.close();
  });

  testWidgets('should list active filters above the titles in every mode', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    await cubit.updateFilter(
      const CatalogFilter(
        watched: false,
        genres: <String>{'mystery'},
        minimumCommunityRating: 7,
        sort: CatalogSort.title,
      ),
    );
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await tester.pumpAndSettle();

    for (final id in <String>[
      'watched',
      'genre-mystery',
      'community',
      'sort',
    ]) {
      expect(
        find.byKey(WidgetKeys.discoveryActiveFilterChip(id)),
        findsOneWidget,
      );
    }
    expect(find.text('Unwatched'), findsOneWidget);
    expect(find.text('Mystery'), findsOneWidget);
    expect(find.text('Community 7.0+'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(WidgetKeys.discoveryActiveFilters)).dy,
      lessThanOrEqualTo(
        tester.getTopLeft(find.byKey(WidgetKeys.discoveryGrid)).dy,
      ),
    );

    await robot.openSwipe();
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.discoveryActiveFilters), findsOneWidget);

    await robot.openShuffle();
    await tester.pumpAndSettle();
    expect(find.byKey(WidgetKeys.discoveryActiveFilters), findsOneWidget);
    // Shuffle always draws at random, so the sort choice is not shown there.
    expect(
      find.byKey(WidgetKeys.discoveryActiveFilterChip('sort')),
      findsNothing,
    );
    await cubit.close();
  });

  testWidgets('should remove a single filter from its chip', (tester) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    await cubit.updateFilter(
      const CatalogFilter(watched: false, genres: <String>{'mystery'}),
    );

    await _pumpPage(tester, cubit);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(WidgetKeys.discoveryActiveFilterChip('watched')),
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(cubit.state.filter.watched, isNull);
    expect(cubit.state.filter.genres, <String>{'mystery'});
    expect(
      find.byKey(WidgetKeys.discoveryActiveFilterChip('watched')),
      findsNothing,
    );
    await cubit.close();
  });

  testWidgets('should clear every active filter from the strip', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    await cubit.updateFilter(
      const CatalogFilter(watched: false, favorite: true),
    );

    await _pumpPage(tester, cubit);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryActiveFiltersClear));
    await tester.pumpAndSettle();

    expect(cubit.state.filter.isActive, isFalse);
    expect(find.byKey(WidgetKeys.discoveryActiveFilters), findsNothing);
    await cubit.close();
  });

  testWidgets('should keep active filter chips accessible', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    await cubit.updateFilter(const CatalogFilter(watched: false));

    await _pumpPage(tester, cubit);
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
    await cubit.close();
  });

  group('main view sorting and watched fade', () {
    testWidgets('should sort from the header outside Shuffle', (tester) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);

      await _pumpPage(tester, cubit);
      await tester.tap(find.byKey(WidgetKeys.discoverySortButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(WidgetKeys.discoverySortChoice(CatalogSort.title.name)),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.filter.sort, CatalogSort.title);
      await robot.openShuffle();
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.discoverySortButton), findsNothing);
      await cubit.close();
    });

    testWidgets('should fade watched titles when the option is on', (
      tester,
    ) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[
        _candidate(watched: true),
        _candidate(id: 'movie-2', name: 'Velvet Static'),
      ]);

      await _pumpPage(tester, cubit);
      expect(
        find.byKey(WidgetKeys.discoveryWatchedBadge('movie-1')),
        findsNothing,
      );

      await tester.tap(find.byKey(WidgetKeys.discoveryMoreButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.discoveryFadeWatchedToggle));
      await tester.pumpAndSettle();

      expect(cubit.state.fadeWatched, isTrue);
      expect(
        find.byKey(WidgetKeys.discoveryWatchedBadge('movie-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(WidgetKeys.discoveryWatchedBadge('movie-2')),
        findsNothing,
      );
      await cubit.close();
    });
  });

  group('tags, exclusions, and reverse sort', () {
    testWidgets('should require a tag and exclude a genre from the chips', (
      tester,
    ) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);

      await _pumpPage(
        tester,
        cubit,
        facets: const CatalogFacets(
          genres: <String>['horror', 'mystery'],
          tags: <String>['cozy'],
        ),
      );
      await robot.openQuickFilters();
      await robot.openFilterTab(1);

      await tester.tap(find.byKey(WidgetKeys.discoveryTagFilter('cozy')));
      await tester.pump();
      final horror = find.byKey(WidgetKeys.discoveryGenre('horror'));
      await tester.tap(horror);
      await tester.pump();
      await tester.tap(horror);
      await tester.pumpAndSettle();
      expect(find.text('1 required'), findsOneWidget);
      expect(find.text('1 excluded'), findsOneWidget);
      await robot.applyOpenFilters();

      expect(cubit.state.filter.tags, <String>{'cozy'});
      expect(cubit.state.filter.excludedGenres, <String>{'horror'});
      expect(cubit.state.filter.genres, isEmpty);
      expect(find.text('Not Horror'), findsOneWidget);
      expect(find.text('Tag: cozy'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('should cap tag chips and find the rest by search', (
      tester,
    ) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);
      final tags = <String>[for (var i = 0; i < 500; i++) 'keyword $i'];

      await _pumpPage(tester, cubit, facets: CatalogFacets(tags: tags));
      await robot.openQuickFilters();
      await robot.openFilterTab(1);

      Finder tagChips() => find.byWidgetPredicate(
        (widget) =>
            widget is FilterChip &&
            '${widget.key}'.contains('discovery-tag-filter-'),
      );
      expect(tagChips(), findsNWidgets(30));
      expect(
        find.byKey(WidgetKeys.discoveryTagFilter('keyword 499')),
        findsNothing,
      );

      await tester.enterText(find.byKey(WidgetKeys.discoveryTagSearch), '499');
      await tester.pump();
      await tester.tap(
        find.byKey(WidgetKeys.discoveryTagFilter('keyword 499')),
      );
      await tester.pump();
      await tester.enterText(find.byKey(WidgetKeys.discoveryTagSearch), '');
      await tester.pump();

      // A chosen tag stays visible even outside the most-used set.
      expect(
        find.byKey(WidgetKeys.discoveryTagFilter('keyword 499')),
        findsOneWidget,
      );
      await robot.applyOpenFilters();
      expect(cubit.state.filter.tags, <String>{'keyword 499'});
      await cubit.close();
    });

    testWidgets('should clear a chip on its third tap', (tester) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);

      await _pumpPage(
        tester,
        cubit,
        facets: const CatalogFacets(genres: <String>['horror']),
      );
      await robot.openQuickFilters();
      await robot.openFilterTab(1);
      final horror = find.byKey(WidgetKeys.discoveryGenre('horror'));
      for (var tap = 0; tap < 3; tap++) {
        await tester.tap(horror);
        await tester.pump();
      }
      await robot.applyOpenFilters();

      expect(cubit.state.filter.genres, isEmpty);
      expect(cubit.state.filter.excludedGenres, isEmpty);
      await cubit.close();
    });

    testWidgets('should reverse a directional sort from the filter sheet', (
      tester,
    ) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);

      await _pumpPage(tester, cubit);
      await robot.openQuickFilters();
      final reverse = find.byKey(WidgetKeys.discoveryReverseSort);
      expect(tester.widget<IconButton>(reverse).onPressed, isNull);

      await robot.selectSort('Title');
      await tester.tap(reverse);
      await tester.pump();
      await robot.applyOpenFilters();

      expect(cubit.state.filter.sort, CatalogSort.title);
      expect(cubit.state.filter.sortReversed, isTrue);
      expect(find.text('Sorted by title, reversed'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('should reverse the order from the header sort menu', (
      tester,
    ) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      await cubit.updateFilter(const CatalogFilter(sort: CatalogSort.runtime));

      await _pumpPage(tester, cubit);
      await tester.tap(find.byKey(WidgetKeys.discoverySortButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.discoveryReverseSortToggle));
      await tester.pumpAndSettle();
      expect(cubit.state.filter.sortReversed, isTrue);

      // Picking another order starts it in its natural direction.
      await tester.tap(find.byKey(WidgetKeys.discoverySortButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(WidgetKeys.discoverySortChoice(CatalogSort.title.name)),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.filter.sort, CatalogSort.title);
      expect(cubit.state.filter.sortReversed, isFalse);
      await cubit.close();
    });
  });

  group('playlists and tags', () {
    Future<(DiscoveryCubit, LibraryActionsFake)> openOrganizer(
      WidgetTester tester, {
      LibraryActionsFake? actions,
    }) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final fake =
          actions ??
          LibraryActionsFake(
            playlists: const <LibraryPlaylist>[
              LibraryPlaylist(id: 'p1', name: 'Movie night'),
            ],
            tags: const <String>['cozy'],
          );
      await _pumpPage(
        tester,
        cubit,
        libraryActions: fake,
        facets: const CatalogFacets(tags: <String>['cozy', 'rainy day']),
      );
      await tester.longPress(
        find.byKey(WidgetKeys.discoveryCandidate('movie-1')),
      );
      await tester.pumpAndSettle();
      return (cubit, fake);
    }

    testWidgets('should add a long-pressed title to a playlist once', (
      tester,
    ) async {
      final (cubit, actions) = await openOrganizer(tester);
      expect(find.byKey(WidgetKeys.discoveryOrganizer), findsOneWidget);

      await tester.tap(find.byKey(WidgetKeys.discoveryPlaylist('p1')));
      await tester.pumpAndSettle();

      expect(actions.members['p1'], <String>['movie-1']);
      expect(find.text('Added'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('should create a playlist that starts with the title', (
      tester,
    ) async {
      final (cubit, actions) = await openOrganizer(tester);

      await tester.enterText(
        find.byKey(WidgetKeys.discoveryNewPlaylistField),
        'Cozy picks',
      );
      await tester.tap(find.byKey(WidgetKeys.discoveryCreatePlaylist));
      await tester.pumpAndSettle();

      expect(
        actions.playlists.map((playlist) => playlist.name),
        contains('Cozy picks'),
      );
      expect(find.text('Cozy picks'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('should add a suggested tag and remove an existing one', (
      tester,
    ) async {
      final (cubit, actions) = await openOrganizer(tester);
      await tester.tap(find.byKey(WidgetKeys.discoveryOrganizerTab(1)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(WidgetKeys.discoverySuggestedTag('cozy')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(WidgetKeys.discoverySuggestedTag('rainy day')),
      );
      await tester.pumpAndSettle();
      expect(actions.tags, <String>['cozy', 'rainy day']);

      await tester.tap(
        find.descendant(
          of: find.byKey(WidgetKeys.discoveryTag('cozy')),
          matching: find.byIcon(Icons.clear),
        ),
      );
      await tester.pumpAndSettle();
      expect(actions.tags, <String>['rainy day']);
      await cubit.close();
    });

    testWidgets('should roll back a tag and explain admin-only edits', (
      tester,
    ) async {
      final (cubit, actions) = await openOrganizer(
        tester,
        actions: LibraryActionsFake(tags: const <String>[])
          ..tagFailure = LibraryActionFailure.notAllowed,
      );
      await tester.tap(find.byKey(WidgetKeys.discoveryOrganizerTab(1)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(WidgetKeys.discoveryTagField), 'cozy');
      await tester.tap(find.byKey(WidgetKeys.discoveryAddTag));
      await tester.pumpAndSettle();

      expect(find.byKey(WidgetKeys.discoveryTag('cozy')), findsNothing);
      expect(
        find.text('Only Jellyfin administrators can change tags.'),
        findsOneWidget,
      );
      expect(actions.savedTags, isEmpty);
      await cubit.close();
    });

    testWidgets('should offer playlists and tags from Swipe and Shuffle', (
      tester,
    ) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);
      await _pumpPage(tester, cubit, libraryActions: LibraryActionsFake());

      await robot.openSwipe();
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.discoveryOrganizeButton), findsOneWidget);

      await robot.openShuffle();
      await tester.pumpAndSettle();
      await robot.reveal();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(WidgetKeys.discoveryOrganizeButton));
      await tester.pumpAndSettle();
      expect(find.byKey(WidgetKeys.discoveryOrganizer), findsOneWidget);
      await cubit.close();
    });
  });

  testWidgets('should adapt at large text in both phone orientations', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpPage(tester, cubit, textScaler: const TextScaler.linear(2));
    robot.expectNoLayoutException();

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    robot.expectNoLayoutException();
    await cubit.close();
  });

  testWidgets('should apply swipe decisions without motion when reduced', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(),
      _candidate(id: 'movie-2', name: 'Velvet Static'),
    ]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit, disableAnimations: true);
    await robot.openSwipe();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(WidgetKeys.discoveryCandidate('movie-1'))),
    );
    // The first move only clears the touch slop.
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(300, 0));
    await tester.pump();

    final tilts = tester.widgetList<Transform>(
      find.ancestor(
        of: find.byKey(WidgetKeys.discoveryCandidate('movie-1')),
        matching: find.byType(Transform),
      ),
    );
    expect(
      tilts.every(
        (transform) => transform.transform.getRotation().isIdentity(),
      ),
      isTrue,
    );
    await gesture.up();
    await tester.pump();

    expect(cubit.state.likedIds, contains('movie-1'));
    await cubit.close();
  });

  group('dating-style swipe deck', () {
    Future<DiscoveryCubit> pumpDeck(WidgetTester tester) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[
        _candidate(),
        _candidate(id: 'movie-2', name: 'Velvet Static'),
        _candidate(id: 'movie-3', name: 'Harbor Lights'),
      ]);
      await _pumpPage(tester, cubit);
      await DiscoveryRobot(tester).openSwipe();
      await tester.pumpAndSettle();
      return cubit;
    }

    Finder topCard() => find.byKey(WidgetKeys.discoveryCandidate('movie-1'));

    testWidgets('should stamp LIKE while dragging right and like on release', (
      tester,
    ) async {
      final cubit = await pumpDeck(tester);
      final gesture = await tester.startGesture(tester.getCenter(topCard()));
      // The first move only clears the touch slop.
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(120, 0));
      await gesture.moveBy(const Offset(180, -20));
      await tester.pump();

      expect(find.text('LIKE'), findsOneWidget);
      expect(find.text('NOPE'), findsNothing);
      expect(cubit.state.likedIds, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(cubit.state.likedIds, contains('movie-1'));
      expect(topCard(), findsNothing);
      expect(
        find.byKey(WidgetKeys.discoveryCandidate('movie-2')),
        findsWidgets,
      );
      await cubit.close();
    });

    testWidgets('should spring back from a short drag without deciding', (
      tester,
    ) async {
      final cubit = await pumpDeck(tester);
      final start = tester.getCenter(topCard());
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(find.text('NOPE'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(cubit.state.likedIds, isEmpty);
      expect(cubit.state.rejectedIds, isEmpty);
      expect(tester.getCenter(topCard()), start);
      await cubit.close();
    });

    testWidgets('should reject a short but fast flick to the left', (
      tester,
    ) async {
      final cubit = await pumpDeck(tester);

      await tester.fling(topCard(), const Offset(-90, 0), 2000);
      await tester.pumpAndSettle();

      expect(cubit.state.rejectedIds, contains('movie-1'));
      await cubit.close();
    });

    testWidgets('should fly the card out before a button decision lands', (
      tester,
    ) async {
      final cubit = await pumpDeck(tester);
      final start = tester.getCenter(topCard());

      await tester.tap(find.byKey(WidgetKeys.discoverySwipeLike));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(cubit.state.likedIds, isEmpty);
      expect(tester.getCenter(topCard()).dx, greaterThan(start.dx));

      await tester.pumpAndSettle();
      expect(cubit.state.likedIds, contains('movie-1'));

      await tester.tap(find.byKey(WidgetKeys.discoverySwipeReject));
      await tester.pumpAndSettle();
      expect(cubit.state.rejectedIds, contains('movie-2'));
      await cubit.close();
    });
  });

  testWidgets('should animate discovery mode changes when motion is enabled', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);

    robot.expectModeTransitionDuration(CandyMotion.standard);
    await cubit.close();
  });

  testWidgets('should remove mode animation when reduced motion is active', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit, disableAnimations: true);

    robot.expectModeTransitionDuration(Duration.zero);
    await cubit.close();
  });

  testWidgets('should animate a newly revealed shuffle candidate', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openShuffle();

    robot.expectRevealTransitionDuration(CandyMotion.standard);
    await cubit.close();
  });

  testWidgets('should give discovery cards tactile press feedback', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);

    robot.expectCandidateUsesPressBounce('movie-1');
    await cubit.close();
  });

  testWidgets('should keep discovery controls in an unboxed header', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);

    robot.expectUnboxedHeader();
    await cubit.close();
  });

  testWidgets('should retain Jellyfilter identity in the compact header', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);

    robot.expectCompactDiscoveryHeader(candidateCount: 1);
    await cubit.close();
  });

  testWidgets('should separate filter select fields clearly', (tester) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit, textScaler: const TextScaler.linear(2));
    await robot.openFiltersAtSelects();

    robot.expectFilterSelectSpacing(CandySpacing.compact);
    await cubit.close();
  });

  testWidgets('should progressively load bounded blurred poster previews', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(poster: _networkPoster()),
    ]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);

    robot.expectProgressivePoster('movie-1');
    robot.expectGridPosterFit('movie-1', BoxFit.cover);
    await cubit.close();
  });

  testWidgets('should show the complete poster in swipe mode', (tester) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(poster: _networkPoster()),
    ]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openSwipe();

    robot.expectSwipePosterFit('movie-1', BoxFit.contain);
    await cubit.close();
  });

  testWidgets(
    'should configure spin duration and apply it to subsequent spins',
    (tester) async {
      final cubit = _cubit();
      await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
      final robot = DiscoveryRobot(tester);
      await _pumpPage(tester, cubit);
      await robot.openShuffle();
      await tester.pumpAndSettle();
      for (final duration in [
        ShuffleDuration.oneSecond,
        ShuffleDuration.sixSeconds,
      ]) {
        await tester.tap(find.byKey(WidgetKeys.discoveryShuffleDuration));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(WidgetKeys.discoveryShuffleDurationChoice(duration.name)),
        );
        await tester.pumpAndSettle();
        expect(cubit.state.shuffleDuration, duration);
        await robot.startSpin();
        expect(
          tester
              .widget<PopupMenuButton<ShuffleDuration>>(
                find.byKey(WidgetKeys.discoveryShuffleDuration),
              )
              .enabled,
          isFalse,
        );
        await tester.pump(duration.duration ~/ 2);
        robot.expectRevealButtonEnabled(enabled: false);
        await tester.pump(duration.duration ~/ 2);
        await tester.pump(const Duration(milliseconds: 20));
        robot.expectRevealButtonEnabled(enabled: true);
        expect(
          find.byKey(WidgetKeys.discoveryShuffleCandidate('movie-1')),
          findsOneWidget,
        );
      }
      await cubit.close();
    },
  );

  testWidgets('should reveal instantly when Instant is selected', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);
    await _pumpPage(tester, cubit);
    await robot.openShuffle();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryShuffleDuration));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(WidgetKeys.discoveryShuffleDurationChoice('instant')),
    );
    await tester.pumpAndSettle();
    await robot.startSpin();
    await tester.pump();
    robot.expectRevealButtonEnabled(enabled: true);
    expect(
      find.byKey(WidgetKeys.discoveryShuffleCandidate('movie-1')),
      findsOneWidget,
    );
    await cubit.close();
  });

  testWidgets('should spin the reel before landing on the selected pick', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(),
      _candidate(id: 'movie-2', name: 'Velvet Static'),
      _candidate(id: 'movie-3', name: 'Harbor Lights'),
    ]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openShuffle();
    await tester.pumpAndSettle();
    await robot.startSpin();

    expect(cubit.state.currentRevealId, 'movie-1');
    robot.expectRevealButtonEnabled(enabled: false);
    expect(find.text('Spinning…'), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoveryCandidate('movie-1')), findsNothing);

    await tester.pump(CandyMotion.reelSpin);
    await tester.pump(CandyMotion.reelSettle);

    robot.expectRevealButtonEnabled(enabled: true);
    expect(find.text('Spin again'), findsOneWidget);
    expect(
      find.byKey(WidgetKeys.discoveryShuffleCandidate('movie-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(WidgetKeys.discoveryCandidate('movie-1')),
      findsOneWidget,
    );
    await cubit.close();
  });

  testWidgets('should land immediately without a reel when motion is reduced', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    await cubit.setShuffleDuration(ShuffleDuration.sixSeconds);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit, disableAnimations: true);
    await robot.openShuffle();
    await robot.startSpin();
    await tester.pump();

    robot.expectRevealButtonEnabled(enabled: true);
    expect(
      find.byKey(WidgetKeys.discoveryShuffleCandidate('movie-1')),
      findsOneWidget,
    );
    await cubit.close();
  });

  testWidgets('should stop the reel when the pick is cleared mid-spin', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openShuffle();
    await tester.pumpAndSettle();
    await robot.startSpin();
    await cubit.reject('movie-1');
    await tester.pump();

    robot.expectRevealButtonEnabled(enabled: true);
    expect(find.byKey(WidgetKeys.discoveryShufflePlaceholder), findsOneWidget);
    await tester.pump(CandyMotion.reelSpin);
    await cubit.close();
  });

  testWidgets('should tune the favorite bias from the shuffle screen', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[_candidate()]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openShuffle();
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);

    final slider = find.byKey(WidgetKeys.discoveryFavoriteBias);
    await tester.tapAt(tester.getCenter(slider));
    await tester.pumpAndSettle();

    expect(cubit.state.favoriteBias, 0.5);
    expect(find.text('50%'), findsOneWidget);
    // The candidate here is not a favorite, so the control says so.
    expect(find.text('No favorites here'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('should show the complete poster in shuffle mode', (
    tester,
  ) async {
    final cubit = _cubit();
    await cubit.replaceCandidates(<CatalogCandidate>[
      _candidate(poster: _networkPoster()),
    ]);
    final robot = DiscoveryRobot(tester);

    await _pumpPage(tester, cubit);
    await robot.openShuffle();
    await robot.reveal();

    robot.expectShufflePosterFit('movie-1', BoxFit.contain);
    await cubit.close();
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  DiscoveryCubit cubit, {
  Future<bool> Function(CatalogCandidate candidate)? onToggleFavorite,
  Future<CatalogCandidate?> Function(CatalogCandidate candidate)? onLoadDetails,
  Future<bool> Function(Uri uri)? onOpenTrailer,
  Future<void> Function()? onLoadMore,
  List<CatalogLibrary> libraries = const <CatalogLibrary>[],
  CatalogFacets facets = const CatalogFacets(),
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  double topInset = 0,
  double bottomInset = 0,
  double bottomViewInset = 0,
  LibraryActionsRepository? libraryActions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCandyTheme(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
          padding: EdgeInsets.only(top: topInset, bottom: bottomInset),
          viewPadding: EdgeInsets.only(top: topInset, bottom: bottomInset),
          viewInsets: EdgeInsets.only(bottom: bottomViewInset),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: DiscoveryPage(
        cubit: cubit,
        onToggleFavorite: onToggleFavorite,
        onLoadDetails: onLoadDetails,
        onOpenTrailer: onOpenTrailer,
        onLoadMore: onLoadMore,
        libraries: libraries,
        facets: facets,
        onOrganize: libraryActions == null
            ? null
            : (context, candidate) => showDiscoveryOrganizer(
                context,
                candidate,
                repository: libraryActions,
                knownTags: facets.tags,
              ),
      ),
    ),
  );
  await tester.pump();
}

DiscoveryCubit _cubit() => DiscoveryCubit(
  store: ImmediateDiscoveryStore(),
  scopeKey: 'server/user',
  selector: FakeDiscoverySelector('movie-1'),
);

CatalogCandidate _candidate({
  String id = 'movie-1',
  String name = 'Candy Comet',
  CatalogImage? poster,
  String? overview = 'A warm mystery in space.',
  List<CatalogTrailer> trailers = const <CatalogTrailer>[],
  bool watched = false,
}) => CatalogCandidate(
  id: id,
  name: name,
  mediaType: CatalogMediaType.movie,
  year: 2024,
  runtimeMinutes: 112,
  genres: const <String>{'mystery', 'science fiction'},
  communityRating: 8.4,
  criticRating: 91,
  officialRating: 'PG-13',
  status: 'Released',
  overview: overview,
  cast: const <String>['Ava Actor', 'Sam Star'],
  trailers: trailers,
  watched: watched,
  favorite: false,
  poster: poster ?? const CatalogImage.fallback(),
  backdrop: const CatalogImage.fallback(),
);

CatalogImage _networkPoster({String? blurHash}) => CatalogImage(
  uri: Uri.parse(
    'https://example.test/Items/movie-1/Images/Primary?tag=poster',
  ),
  isFallback: false,
  aspectRatio: 0.67,
  blurHash: blurHash,
);
