import 'package:flutter/widgets.dart';

/// Stable identifiers for app-level widget tests and automation.
abstract final class WidgetKeys {
  static const appShell = Key('app-shell');
  static const connectionForm = Key('connection-form');
  static const connectionUrlField = Key('connection-url-field');
  static const connectionUsernameField = Key('connection-username-field');
  static const connectionPasswordField = Key('connection-password-field');
  static const connectionSubmitButton = Key('connection-submit-button');
  static const connectionConfirmPrivateHttpButton = Key(
    'connection-confirm-private-http-button',
  );
  static const connectionError = Key('connection-error');
  static const connectionSummary = Key('connection-summary');
  static const connectionLogoutButton = Key('connection-logout-button');
  static const connectionExploreButton = Key('connection-explore-button');
  static const discoveryPage = Key('discovery-page');
  static const discoveryModeNavigation = Key('discovery-mode-navigation');
  static const discoveryGridMode = Key('discovery-grid-mode');
  static const discoverySwipeMode = Key('discovery-swipe-mode');
  static const discoveryShuffleMode = Key('discovery-shuffle-mode');
  static const discoveryGrid = Key('discovery-grid');
  static const discoverySwipeDeck = Key('discovery-swipe-deck');
  static const discoveryShuffle = Key('discovery-shuffle');
  static const discoveryModeTransition = Key('discovery-mode-transition');
  static const discoveryShufflePlaceholder = Key(
    'discovery-shuffle-placeholder',
  );
  static const discoveryRevealButton = Key('discovery-reveal-button');
  static const discoveryDetails = Key('discovery-details');
  static const discoveryDetailsLoading = Key('discovery-details-loading');
  static const discoveryClearButton = Key('discovery-clear-button');
  static const discoveryMoreButton = Key('discovery-more-button');
  static const discoveryFilterButton = Key('discovery-filter-button');
  static const discoveryRecentFilter = Key('discovery-recent-filter');
  static const discoveryUnwatchedFilter = Key('discovery-unwatched-filter');
  static const discoveryFavoritesFilter = Key('discovery-favorites-filter');
  static const discoveryActiveFilterIndicator = Key(
    'discovery-active-filter-indicator',
  );
  static const discoverySearchField = Key('discovery-search-field');
  static const discoveryLibraryField = Key('discovery-library-field');
  static const discoveryGenresField = Key('discovery-genres-field');
  static const discoveryRuntimeField = Key('discovery-runtime-field');
  static const discoveryCommunityRatingField = Key(
    'discovery-community-rating-field',
  );
  static const discoveryCriticRatingField = Key(
    'discovery-critic-rating-field',
  );
  static const discoveryDecadeField = Key('discovery-decade-field');
  static const discoveryWatchedField = Key('discovery-watched-field');
  static const discoveryFavoriteField = Key('discovery-favorite-field');
  static const discoverySortField = Key('discovery-sort-field');
  static const discoveryAddedWithinField = Key('discovery-added-within-field');
  static const discoveryResetFilters = Key('discovery-reset-filters');
  static const discoveryFilterSheet = Key('discovery-filter-sheet');
  static const discoveryMovieFilter = Key('discovery-movie-filter');
  static const discoverySeriesFilter = Key('discovery-series-filter');
  static const discoveryApplyFilters = Key('discovery-apply-filters');
  static const discoveryPresetName = Key('discovery-preset-name');
  static const discoverySavePreset = Key('discovery-save-preset');
  static const discoveryPosterPreview = Key('discovery-poster-preview');

  static Key discoveryCandidate(String id) => Key('discovery-candidate-$id');

  static Key discoveryShuffleCandidate(String id) =>
      Key('discovery-shuffle-candidate-$id');

  static Key discoveryFavorite(String id) => Key('discovery-favorite-$id');

  static Key discoveryTrailer(int index) => Key('discovery-trailer-$index');

  static Key discoveryPosterBlurHash(String id) =>
      Key('discovery-poster-blurhash-$id');

  static Key discoveryOfficialRating(String value) =>
      Key('discovery-official-rating-$value');

  static Key discoveryGenre(String value) => Key('discovery-genre-$value');

  static Key discoveryDecade(int value) => Key('discovery-decade-$value');

  static Key discoverySeriesStatus(String value) =>
      Key('discovery-series-status-$value');

  static Key discoveryPreset(String name) => Key('discovery-preset-$name');

  static const discoveryActiveFilters = Key('discovery-active-filters');
  static const discoverySwipeLike = Key('discovery-swipe-like');
  static const discoverySortButton = Key('discovery-sort-button');
  static const discoveryReverseSort = Key('discovery-reverse-sort');
  static const discoveryTagSearch = Key('discovery-tag-search');
  static const discoveryReverseSortToggle = Key(
    'discovery-reverse-sort-toggle',
  );

  static Key discoveryTagFilter(String tag) => Key('discovery-tag-filter-$tag');
  static const discoveryPlayTrailer = Key('discovery-play-trailer');
  static const discoveryOrganizeButton = Key('discovery-organize-button');
  static const discoveryOrganizer = Key('discovery-organizer');
  static const discoveryNewPlaylistField = Key('discovery-new-playlist');
  static const discoveryCreatePlaylist = Key('discovery-create-playlist');
  static const discoveryTagField = Key('discovery-tag-field');
  static const discoveryAddTag = Key('discovery-add-tag');
  static const discoveryOrganizerMessage = Key('discovery-organizer-message');

  static Key discoveryDetailsTab(int index) =>
      Key('discovery-details-tab-$index');

  static Key discoveryOrganizerTab(int index) =>
      Key('discovery-organizer-tab-$index');

  static Key discoveryPlaylist(String id) => Key('discovery-playlist-$id');

  static Key discoveryTag(String tag) => Key('discovery-tag-$tag');

  static Key discoverySuggestedTag(String tag) =>
      Key('discovery-suggested-tag-$tag');
  static const discoveryFadeWatchedToggle = Key('discovery-fade-watched');

  static Key discoveryWatchedBadge(String id) =>
      Key('discovery-watched-badge-$id');

  static Key discoverySortChoice(String name) =>
      Key('discovery-sort-choice-$name');
  static const discoverySwipeReject = Key('discovery-swipe-reject');
  static const discoverySwipeInfo = Key('discovery-swipe-info');
  static const discoveryFavoriteBias = Key('discovery-favorite-bias');
  static const discoveryActiveFiltersClear = Key(
    'discovery-active-filters-clear',
  );

  static Key discoveryActiveFilterChip(String id) =>
      Key('discovery-active-filter-$id');

  static Key discoveryFilterTab(int index) =>
      Key('discovery-filter-tab-$index');
}
