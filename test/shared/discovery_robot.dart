import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_picker/core/keys/widget_keys.dart';
import 'package:jellyfin_picker/core/theme/candy_theme.dart';
import 'package:jellyfin_picker/core/widgets/candy_bounce.dart';

final class DiscoveryRobot {
  const DiscoveryRobot(this.tester);

  final WidgetTester tester;

  void expectPeerModesVisible() {
    expect(find.byKey(WidgetKeys.discoveryGridMode), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoverySwipeMode), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoveryShuffleMode), findsOneWidget);
  }

  void expectGridVisible() {
    expect(find.byKey(WidgetKeys.discoveryGrid), findsOneWidget);
  }

  void expectGridMeetsModeNavigation() {
    final gridBottom = tester
        .getBottomLeft(find.byKey(WidgetKeys.discoveryGrid))
        .dy;
    final navigationTop = tester
        .getTopLeft(find.byKey(WidgetKeys.discoveryModeNavigation))
        .dy;

    expect(navigationTop - gridBottom, closeTo(CandySpacing.compact, 0.01));
  }

  Future<void> scrollGridToBottom() async {
    final position = _gridScrollableState.position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }

  void expectGridCandidateVisible(String id) {
    final gridRect = tester.getRect(find.byKey(WidgetKeys.discoveryGrid));
    final candidateRect = tester.getRect(
      find.byKey(WidgetKeys.discoveryCandidate(id)),
    );

    expect(candidateRect.overlaps(gridRect), isTrue);
  }

  void expectQuickFiltersHiddenFromDiscovery() {
    expect(find.byKey(WidgetKeys.discoveryRecentFilter), findsNothing);
    expect(find.byKey(WidgetKeys.discoveryUnwatchedFilter), findsNothing);
    expect(find.byKey(WidgetKeys.discoveryFavoritesFilter), findsNothing);
  }

  void expectQuickFiltersVisibleInSheet() {
    final sheet = find.byKey(WidgetKeys.discoveryFilterSheet);
    expect(find.byKey(WidgetKeys.discoveryRecentFilter), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoveryUnwatchedFilter), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoveryFavoritesFilter), findsOneWidget);
    for (final key in <Key>[
      WidgetKeys.discoveryRecentFilter,
      WidgetKeys.discoveryUnwatchedFilter,
      WidgetKeys.discoveryFavoritesFilter,
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.byKey(key)),
        findsOneWidget,
      );
    }
  }

  void expectFiltersInactive() {
    expect(find.byKey(WidgetKeys.discoveryActiveFilterIndicator), findsNothing);
  }

  void expectFiltersActive() {
    expect(
      find.byKey(WidgetKeys.discoveryActiveFilterIndicator),
      findsOneWidget,
    );
  }

  void expectLibrarySelectorVisible() {
    expect(find.byKey(WidgetKeys.discoveryLibraryField), findsOneWidget);
  }

  Future<void> expectServerFacetsVisible({
    required String genre,
    required int decade,
    required String rating,
  }) async {
    await openFilterTab(1);
    expect(find.byKey(WidgetKeys.discoveryGenre(genre)), findsOneWidget);
    expect(find.byKey(WidgetKeys.discoveryDecade(decade)), findsOneWidget);
    expect(
      find.byKey(WidgetKeys.discoveryOfficialRating(rating)),
      findsOneWidget,
    );
  }

  Future<void> selectSort(String label) async {
    await openFilterTab(0);
    await _selectDropdownValue(WidgetKeys.discoverySortField, label);
  }

  Future<void> selectLibraryAndApply(String label) async {
    await openFilterTab(0);
    await _selectDropdownValue(WidgetKeys.discoveryLibraryField, label);
    await applyOpenFilters();
  }

  void expectDetailsLoading() {
    expect(find.byKey(WidgetKeys.discoveryDetailsLoading), findsOneWidget);
  }

  void expectDetailsSynopsis(String synopsis) {
    expect(find.text(synopsis), findsOneWidget);
  }

  Future<void> expectTrailerVisible(int index, String name) async {
    expect(find.byKey(WidgetKeys.discoveryPlayTrailer), findsOneWidget);
    await openDetailsTab(2);
    expect(find.byKey(WidgetKeys.discoveryTrailer(index)), findsOneWidget);
    expect(find.text(name), findsOneWidget);
  }

  void expectTrailersNotVisible() {
    expect(find.byKey(WidgetKeys.discoveryTrailer(0)), findsNothing);
  }

  Future<void> playTrailer(int index) async {
    await tester.tap(find.byKey(WidgetKeys.discoveryTrailer(index)));
    await tester.pumpAndSettle();
  }

  void expectNoMatchesVisible() {
    expect(find.text('No titles fit yet'), findsOneWidget);
    expect(find.text('Your library is unavailable'), findsNothing);
  }

  void expectPosterBlurHashVisible(String id) {
    expect(find.byKey(WidgetKeys.discoveryPosterBlurHash(id)), findsOneWidget);
  }

  void expectNoPosterPreviewRequest() {
    expect(find.byKey(WidgetKeys.discoveryPosterPreview), findsNothing);
  }

  Future<void> openQuickFilters() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
  }

  Future<void> tapRecentThirtyDays() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryRecentFilter));
    await tester.pump();
  }

  Future<void> openFilterTab(int index) async {
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterTab(index)));
    await tester.pumpAndSettle();
  }

  Future<void> openFilters() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(WidgetKeys.discoveryFavoriteField),
      CandySpacing.section,
      scrollable: _filterScrollable,
    );
  }

  Future<void> tapResetFilters() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryResetFilters));
    await tester.pumpAndSettle();
  }

  Future<void> applyOpenFilters() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryApplyFilters));
    await tester.pumpAndSettle();
  }

  Future<void> applyAdvancedFilters() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(WidgetKeys.discoverySearchField),
      'Candy',
    );
    await _selectDropdownValue(WidgetKeys.discoverySortField, 'Recently added');
    await _selectDropdownValue(WidgetKeys.discoveryAddedWithinField, '30 days');
    await openFilterTab(1);
    for (final key in <Key>[
      WidgetKeys.discoveryGenre('mystery'),
      WidgetKeys.discoveryDecade(2020),
      WidgetKeys.discoveryOfficialRating('PG-13'),
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        CandySpacing.section,
        scrollable: _filterScrollable,
      );
      await tester.tap(find.byKey(key));
      await tester.pump();
    }
    await tester.tap(find.byKey(WidgetKeys.discoveryApplyFilters));
    await tester.pumpAndSettle();
  }

  Future<void> _selectDropdownValue(Key key, String label) async {
    final field = find.byKey(key);
    // Scroll until the field is tappable rather than tucked under the
    // pinned apply bar.
    await tester.scrollUntilVisible(
      field.hitTestable(),
      CandySpacing.section,
      scrollable: _filterScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  void expectSwipeVisible() {
    expect(find.byKey(WidgetKeys.discoverySwipeDeck), findsOneWidget);
  }

  void expectShuffleVisible() {
    expect(find.byKey(WidgetKeys.discoveryShuffle), findsOneWidget);
  }

  Future<void> openSwipe() async {
    await tester.tap(find.byKey(WidgetKeys.discoverySwipeMode));
    await tester.pump();
  }

  Future<void> openShuffle() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryShuffleMode));
    await tester.pump();
  }

  /// Pulls the lever and lets the reel run until it locks on a pick.
  Future<void> reveal() async {
    await startSpin();
    await tester.pump(CandyMotion.reelSpin);
    await tester.pump(CandyMotion.reelSettle);
  }

  Future<void> startSpin() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryRevealButton));
    await tester.pump();
  }

  void expectRevealButtonEnabled({required bool enabled}) {
    final button = tester.widget<ButtonStyleButton>(
      find.byKey(WidgetKeys.discoveryRevealButton),
    );
    expect(button.onPressed != null, enabled);
  }

  Future<void> openFirstDetails() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryCandidate('movie-1')));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> toggleFirstFavorite() async {
    final favorite = find.byKey(WidgetKeys.discoveryFavorite('movie-1'));
    final position = _gridScrollableState.position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await tester.tap(favorite);
    await tester.pump();
  }

  Future<void> filterToMovies() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final movieFilter = find.byKey(WidgetKeys.discoveryMovieFilter);
    await tester.ensureVisible(movieFilter);
    await tester.tap(movieFilter);
    final applyFilters = find.byKey(WidgetKeys.discoveryApplyFilters);
    await tester.scrollUntilVisible(
      applyFilters,
      300,
      scrollable: find
          .descendant(
            of: find.byKey(WidgetKeys.discoveryFilterSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(applyFilters);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> savePreset(String name) async {
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
    await openFilterTab(3);
    final nameField = find.byKey(WidgetKeys.discoveryPresetName);
    final saveButton = find.byKey(WidgetKeys.discoverySavePreset);
    await tester.enterText(nameField, name);
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();
  }

  Future<void> openFiltersAtSelects() async {
    await tester.tap(find.byKey(WidgetKeys.discoveryFilterButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(WidgetKeys.discoveryFavoriteField),
      CandySpacing.section,
      scrollable: _filterScrollable,
    );
  }

  void expectCandidateVisible(String name) {
    expect(find.text(name), findsWidgets);
  }

  /// Header and Overview tab first, then the Details tab.
  Future<void> expectDetailsVisible() async {
    expect(find.byKey(WidgetKeys.discoveryDetails), findsOneWidget);
    expect(find.text('Synopsis'), findsOneWidget);
    expect(find.text('A warm mystery in space.'), findsOneWidget);
    expect(find.textContaining('2024'), findsWidgets);
    expect(find.textContaining('112'), findsWidgets);
    expect(find.textContaining('8.4'), findsWidgets);
    expect(find.textContaining('91'), findsWidgets);
    expect(find.textContaining('PG-13'), findsWidgets);
    expect(find.textContaining('Ava Actor'), findsWidgets);

    await openDetailsTab(1);
    expect(find.text('Status'), findsOneWidget);
    expect(find.textContaining('Released'), findsWidgets);
    await openDetailsTab(0);
  }

  Future<void> openDetailsTab(int index) async {
    await tester.tap(find.byKey(WidgetKeys.discoveryDetailsTab(index)));
    await tester.pumpAndSettle();
  }

  /// The scrolling tab content runs to the bottom of the sheet.
  void expectNoBlankAreaBelowDetails({double bottomInset = 0}) {
    final sheetBottom = tester.getBottomLeft(find.byType(BottomSheet)).dy;
    final detailsBottom = tester
        .getBottomLeft(find.byKey(WidgetKeys.discoveryDetails))
        .dy;

    expect(
      sheetBottom - detailsBottom,
      lessThanOrEqualTo(CandySpacing.compact + bottomInset),
    );
  }

  void expectDetailsScrollable() {
    expect(_detailsScrollableState.position.maxScrollExtent, greaterThan(0));
  }

  Future<void> scrollDetailsToBottom() async {
    final position = _detailsScrollableState.position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
  }

  void expectNoLayoutException() {
    expect(tester.takeException(), isNull);
  }

  void expectModeTransitionDuration(Duration duration) {
    final switcher = tester.widget<AnimatedSwitcher>(
      find.byKey(WidgetKeys.discoveryModeTransition),
    );
    expect(switcher.duration, duration);
  }

  void expectRevealTransitionDuration(Duration duration) {
    final switchers = tester.widgetList<AnimatedSwitcher>(
      find.descendant(
        of: find.byKey(WidgetKeys.discoveryShuffle),
        matching: find.byType(AnimatedSwitcher),
      ),
    );
    expect(switchers, hasLength(1));
    expect(switchers.single.duration, duration);
  }

  void expectCandidateUsesPressBounce(String id) {
    expect(
      tester.widget(find.byKey(WidgetKeys.discoveryCandidate(id))),
      isA<CandyBounce>(),
    );
  }

  void expectUnboxedHeader() {
    expect(
      find.ancestor(
        of: find.byKey(WidgetKeys.discoveryFilterButton),
        matching: find.byType(Card),
      ),
      findsNothing,
    );
  }

  void expectCompactDiscoveryHeader({required int candidateCount}) {
    expect(find.text('Jellyfilter'), findsOneWidget);
    expect(find.text('Movie night starts here'), findsNothing);
    expect(find.text('$candidateCount title'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(WidgetKeys.discoveryFilterButton),
        matching: find.byIcon(Icons.filter_list_rounded),
      ),
      findsOneWidget,
    );
    _expectAssetImage('docs/icons/app-icon.png');
    _expectAssetImageNotVisible('docs/icons/filter-icon.png');
  }

  void expectSearchArtworkVisible() {
    _expectAssetImage('docs/icons/search-icon.png');
  }

  void expectFilterSelectSpacing(double minimumGap) {
    final watched = find.byKey(WidgetKeys.discoveryWatchedField);
    final favorite = find.byKey(WidgetKeys.discoveryFavoriteField);
    final gap =
        tester.getTopLeft(favorite).dy - tester.getBottomLeft(watched).dy;

    expect(gap, greaterThanOrEqualTo(minimumGap));
  }

  void expectProgressivePoster(String id) {
    final card = find.byKey(WidgetKeys.discoveryCandidate(id));
    final images = tester
        .widgetList<Image>(
          find.descendant(of: card, matching: find.byType(Image)),
        )
        .toList(growable: false);
    final providers = images
        .map((image) => image.image)
        .toList(growable: false);
    final urls = images
        .map((image) => _networkImageFor(image.image))
        .map((provider) => Uri.parse(provider.url))
        .toList(growable: false);

    expect(urls, hasLength(2));
    expect(
      providers.whereType<ResizeImage>().map((provider) => provider.width),
      containsAll(<int>[48, 600]),
    );
    expect(
      urls.map((uri) => uri.queryParameters['maxWidth']),
      containsAll(<String>['48', '600']),
    );
    expect(
      urls
          .singleWhere((uri) => uri.queryParameters['maxWidth'] == '48')
          .queryParameters['blur'],
      '20',
    );
    expect(images.any((image) => image.frameBuilder != null), isTrue);
  }

  void expectGridPosterFit(String id, BoxFit fit) {
    _expectPosterFitIn(WidgetKeys.discoveryGrid, id, fit);
  }

  void expectSwipePosterFit(String id, BoxFit fit) {
    _expectPosterFitIn(WidgetKeys.discoverySwipeDeck, id, fit);
  }

  void expectShufflePosterFit(String id, BoxFit fit) {
    _expectPosterFitIn(WidgetKeys.discoveryShuffle, id, fit);
  }

  void _expectPosterFitIn(Key modeKey, String id, BoxFit fit) {
    final mode = find.byKey(modeKey);
    final card = find.descendant(
      of: mode,
      matching: find.byKey(WidgetKeys.discoveryCandidate(id)),
    );
    final images = tester.widgetList<Image>(
      find.descendant(of: card, matching: find.byType(Image)),
    );

    expect(images, isNotEmpty);
    expect(images.map((image) => image.fit), everyElement(fit));
  }

  /// The vertical list of the filter tab that is currently showing.
  Finder get _filterScrollable => find
      .descendant(
        of: find.byKey(WidgetKeys.discoveryFilterSheet),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .last;

  Finder get _gridScrollable => find.descendant(
    of: find.byKey(WidgetKeys.discoveryGrid),
    matching: find.byType(Scrollable),
  );

  ScrollableState get _gridScrollableState =>
      tester.state<ScrollableState>(_gridScrollable);

  Finder get _detailsScrollable => find.descendant(
    of: find.byKey(WidgetKeys.discoveryDetails),
    matching: find.byType(Scrollable),
  );

  ScrollableState get _detailsScrollableState =>
      tester.state<ScrollableState>(_detailsScrollable);

  NetworkImage _networkImageFor(ImageProvider provider) => switch (provider) {
    ResizeImage(:final imageProvider) => imageProvider as NetworkImage,
    NetworkImage() => provider,
    _ => throw TestFailure('Expected a network-backed image provider.'),
  };

  void _expectAssetImage(String assetName) {
    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .map(_assetName);
    expect(assetNames, contains(assetName));
  }

  void _expectAssetImageNotVisible(String assetName) {
    final assetNames = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .map(_assetName);
    expect(assetNames, isNot(contains(assetName)));
  }

  String? _assetName(ImageProvider provider) => switch (provider) {
    AssetImage(:final assetName) => assetName,
    ResizeImage(imageProvider: AssetImage(:final assetName)) => assetName,
    _ => null,
  };
}
