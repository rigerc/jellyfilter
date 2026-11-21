import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/keys/widget_keys.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/core/media/entities/catalog_filter.dart';
import 'package:jellyfilter/core/media/entities/catalog_series_progress.dart';
import 'package:jellyfilter/core/theme/candy_theme.dart';
import 'package:jellyfilter/features/discovery/application/discovery_cubit.dart';
import 'package:jellyfilter/features/discovery/presentation/discovery_page.dart';
import 'package:jellyfilter/features/discovery/presentation/widgets/discovery_details_sheet.dart';
import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:jellyfilter/l10n/generated/app_localizations.dart';

import '../../../shared/favorite_repository_fake.dart';
import '../../../shared/fake_discovery_store.dart';

void main() {
  testWidgets('should show air years, seasons and episodes left on a show', (
    tester,
  ) async {
    final cubit = await _seriesCubit();

    await _pump(tester, cubit);

    expect(find.text('2019–  ·  3 seasons'), findsOneWidget);
    expect(find.text('10 left'), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoverySeriesProgress), findsOneWidget);
    expect(find.text('1 show'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('should leave the badge off shows not yet started', (
    tester,
  ) async {
    final cubit = await _seriesCubit(unplayed: 26);

    await _pump(tester, cubit);

    expect(find.byKey(WidgetKeys.discoverySeriesBadge), findsNothing);
    expect(find.byKey(WidgetKeys.discoverySeriesProgress), findsNothing);
    await cubit.close();
  });

  testWidgets('should offer the switch and name the kind on screen', (
    tester,
  ) async {
    final cubit = await _seriesCubit();
    final picks = <CatalogMediaType>[];

    await _pump(
      tester,
      cubit,
      mediaTypes: const <CatalogMediaType>{
        CatalogMediaType.movie,
        CatalogMediaType.series,
      },
      onMediaTypeChanged: picks.add,
    );

    expect(find.text('Shows'), findsOneWidget);
    expect(find.text('Jellyfilter'), findsNothing);
    await tester.tap(find.byKey(WidgetKeys.discoveryMediaTypeToggle));
    await tester.pump();
    expect(picks, <CatalogMediaType>[CatalogMediaType.movie]);
    await cubit.close();
  });

  testWidgets('should fit the switch on a phone without losing the title', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cubit = await _seriesCubit();
    final semantics = tester.ensureSemantics();

    await _pump(
      tester,
      cubit,
      mediaTypes: const <CatalogMediaType>{
        CatalogMediaType.movie,
        CatalogMediaType.series,
      },
      onMediaTypeChanged: (_) {},
    );

    // As much room as the brand header gives its title today.
    expect(tester.getSize(find.text('Shows')).width, greaterThanOrEqualTo(64));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.byKey(WidgetKeys.discoveryMediaTypeToggle)),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        label: 'Shows\n1 show',
        hint: 'Discover movies',
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
    await cubit.close();
  });

  testWidgets('should list next up and season progress in details', (
    tester,
  ) async {
    final cubit = await _seriesCubit();
    var loads = 0;

    await _pump(
      tester,
      cubit,
      onLoadSeriesProgress: (series) async {
        loads++;
        return CatalogSeriesProgress(
          seasons: const <CatalogSeason>[
            CatalogSeason(
              id: 'season-1',
              name: 'Season 1',
              number: 1,
              episodeCount: 10,
              unplayedEpisodeCount: 0,
            ),
            CatalogSeason(
              id: 'season-2',
              name: 'Season 2',
              number: 2,
              episodeCount: 8,
              unplayedEpisodeCount: 4,
            ),
          ],
          nextUp: const CatalogEpisode(
            id: 'episode-5',
            name: 'The Long Tide',
            seasonNumber: 2,
            episodeNumber: 5,
            runtimeMinutes: 48,
          ),
        );
      },
    );
    await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('series-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryDetailsTab(1)));
    await tester.pumpAndSettle();

    expect(find.text('Episodes'), findsWidgets);
    expect(find.byKey(WidgetKeys.discoveryNextUp), findsOneWidget);
    expect(find.text('The Long Tide'), findsOneWidget);
    expect(find.text('S2 · E5  ·  48 min'), findsOneWidget);
    expect(find.text('10 of 10 watched'), findsOneWidget);
    expect(find.text('4 of 8 watched'), findsOneWidget);
    expect(loads, 1);
    await cubit.close();
  });

  testWidgets('should retry seasons that failed to load', (tester) async {
    final cubit = await _seriesCubit();
    var loads = 0;

    await _pump(
      tester,
      cubit,
      onLoadSeriesProgress: (series) async =>
          ++loads == 1 ? null : CatalogSeriesProgress(),
    );
    await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('series-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryDetailsTab(1)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoverySeasonsRetry));
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('Jellyfin has no seasons for this show yet.'), findsOne);
    await cubit.close();
  });

  testWidgets('should filter shows by status, length and progress', (
    tester,
  ) async {
    final cubit = await _seriesCubit();

    await _pump(tester, cubit);
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryInProgressFilter));
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterTab(1)));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        WidgetKeys.discoverySeriesStatus(CatalogSeriesStatus.continuing.name),
      ),
    );
    await tester.tap(
      find.byKey(
        WidgetKeys.discoverySeriesLength(CatalogSeriesLength.short.name),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(WidgetKeys.discoveryApplyFilters));
    await tester.pumpAndSettle();

    final filter = cubit.state.filter;
    expect(filter.seriesStatuses, {CatalogSeriesStatus.continuing});
    expect(filter.seriesLengths, {CatalogSeriesLength.short});
    expect(filter.watchProgress, {CatalogWatchProgress.inProgress});
    expect(cubit.state.filteredCandidates, hasLength(1));
    expect(find.text('Continuing'), findsOneWidget);
    expect(find.text('2–4 seasons'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('should offer TV orders in the sort menu', (tester) async {
    final cubit = await _seriesCubit();

    await _pump(tester, cubit);
    await tester.tap(find.byKey(WidgetKeys.discoverySortButton));
    await tester.pumpAndSettle();

    expect(find.text('New episodes'), findsOneWidget);
    expect(find.text('First aired'), findsOneWidget);
    expect(find.text('Runtime'), findsNothing);
    await tester.tap(
      find.byKey(WidgetKeys.discoverySortChoice(CatalogSort.newEpisodes.name)),
    );
    await tester.pumpAndSettle();
    expect(cubit.state.filter.sort, CatalogSort.newEpisodes);
    await cubit.close();
  });

  testWidgets('should give shows tags but no playlists', (tester) async {
    final cubit = await _seriesCubit();
    final actions = LibraryActionsFake(tags: const <String>['cozy']);

    await _pump(tester, cubit, libraryActions: actions);
    await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('series-1')));
    await tester.pumpAndSettle();
    expect(find.text('Playlists & tags'), findsNothing);
    await tester.ensureVisible(find.byKey(WidgetKeys.discoveryOrganizeButton));
    await tester.tap(find.byKey(WidgetKeys.discoveryOrganizeButton));
    await tester.pumpAndSettle();

    expect(find.byKey(WidgetKeys.discoveryOrganizerTab(0)), findsNothing);
    expect(find.byKey(WidgetKeys.discoveryOrganizerTab(1)), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoveryTag('cozy')), findsOneWidget);
    await cubit.close();
  });
}

Future<DiscoveryCubit> _seriesCubit({int unplayed = 10}) async {
  final cubit = DiscoveryCubit(
    store: ImmediateDiscoveryStore(),
    scopeKey: 'server/user|series',
    selector: FakeDiscoverySelector('series-1'),
    mediaType: CatalogMediaType.series,
  );
  await cubit.hydrate();
  await cubit.replaceCandidates(<CatalogCandidate>[
    CatalogCandidate(
      id: 'series-1',
      name: 'Harbor Lights',
      mediaType: CatalogMediaType.series,
      year: 2019,
      status: 'Continuing',
      runtimeMinutes: 48,
      genres: const <String>{'mystery'},
      series: CatalogSeriesFacts(
        seasonCount: 3,
        episodeCount: 26,
        unplayedEpisodeCount: unplayed,
      ),
      favorite: false,
      poster: const CatalogImage.fallback(),
      backdrop: const CatalogImage.fallback(),
    ),
  ]);
  return cubit;
}

Future<void> _pump(
  WidgetTester tester,
  DiscoveryCubit cubit, {
  Set<CatalogMediaType> mediaTypes = const <CatalogMediaType>{},
  ValueChanged<CatalogMediaType>? onMediaTypeChanged,
  Future<CatalogSeriesProgress?> Function(CatalogCandidate series)?
  onLoadSeriesProgress,
  LibraryActionsRepository? libraryActions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCandyTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DiscoveryPage(
        cubit: cubit,
        mediaTypes: mediaTypes,
        onMediaTypeChanged: onMediaTypeChanged,
        onLoadSeriesProgress: onLoadSeriesProgress,
        onOrganize: libraryActions == null
            ? null
            : (context, candidate) => showDiscoveryOrganizer(
                context,
                candidate,
                repository: libraryActions,
              ),
      ),
    ),
  );
  await tester.pump();
}
