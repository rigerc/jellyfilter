// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Jellyfilter';

  @override
  String get homeHeadline => 'Pick something great';

  @override
  String get homeDescription =>
      'A playful way to discover your Jellyfin library.';

  @override
  String get connectionTitle => 'Connect your Jellyfin';

  @override
  String get connectionServerUrlLabel => 'Server address';

  @override
  String get connectionUsernameLabel => 'Username';

  @override
  String get connectionPasswordLabel => 'Password';

  @override
  String get connectionSubmitLabel => 'Connect';

  @override
  String get connectionPrivateHttpWarning =>
      'This local HTTP connection is unencrypted. Continue only if you trust this private network.';

  @override
  String get connectionContinuePrivateHttpLabel => 'Continue on local network';

  @override
  String get connectionConnectingLabel => 'Connecting…';

  @override
  String get connectionConnectedLabel => 'Connected';

  @override
  String get connectionNeedsReauthenticationLabel =>
      'Your session expired. Please connect again.';

  @override
  String get connectionUnreachableError =>
      'We could not reach that server. Check the address and network.';

  @override
  String get connectionServerError =>
      'The Jellyfin server is temporarily unavailable. Try again shortly.';

  @override
  String get connectionInvalidCertificateError =>
      'The server certificate is not trusted. Use a valid HTTPS certificate.';

  @override
  String get connectionIncompatibleError =>
      'That server is not a compatible Jellyfin server.';

  @override
  String get connectionUnsafeRedirectError =>
      'The server redirected the request unsafely. Check the address and try again.';

  @override
  String get connectionInvalidCredentialsError =>
      'Those credentials were not accepted.';

  @override
  String get connectionExpiredSessionError =>
      'Your session expired. Please connect again.';

  @override
  String get connectionInvalidUrlError =>
      'Enter a valid Jellyfin server address.';

  @override
  String get connectionPublicHttpError =>
      'Public HTTP connections are not allowed. Use HTTPS.';

  @override
  String get connectionStorageError =>
      'Secure session storage is unavailable on this device.';

  @override
  String get connectionUnknownError =>
      'We could not complete the connection. Try again.';

  @override
  String get connectionSummaryTitle => 'Connected to Jellyfin';

  @override
  String get connectionSummaryServerLabel => 'Server';

  @override
  String get connectionSummaryUserLabel => 'Signed in as';

  @override
  String get connectionLogoutLabel => 'Log out';

  @override
  String get connectionExploreLabel => 'Explore library';

  @override
  String get discoveryTitle => 'Jellyfilter';

  @override
  String discoveryCandidateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titles',
      one: '1 title',
    );
    return '$_temp0';
  }

  @override
  String get discoveryGridLabel => 'Grid';

  @override
  String get discoverySwipeLabel => 'Swipe';

  @override
  String get discoveryShuffleLabel => 'Shuffle';

  @override
  String get discoveryLikeLabel => 'Like';

  @override
  String get discoveryRejectLabel => 'Not this one';

  @override
  String get discoveryFadeWatchedLabel => 'Fade watched';

  @override
  String get discoveryReverseSortLabel => 'Reverse order';

  @override
  String get discoveryFindTagHint => 'Find a tag';

  @override
  String discoveryTagsShownLabel(int shown, int total) {
    return 'Showing the $shown most used of $total tags. Search to find others.';
  }

  @override
  String get discoveryChipLegend =>
      'Tap once to require, twice to exclude, again to clear.';

  @override
  String get discoveryChipRequired => 'Required';

  @override
  String get discoveryChipExcluded => 'Excluded';

  @override
  String discoveryRequiredCount(int count) {
    return '$count required';
  }

  @override
  String discoveryExcludedCount(int count) {
    return '$count excluded';
  }

  @override
  String discoveryActiveSortReversed(String label) {
    return 'Sorted by $label, reversed';
  }

  @override
  String discoveryActiveExcluded(String value) {
    return 'Not $value';
  }

  @override
  String discoveryActiveTag(String value) {
    return 'Tag: $value';
  }

  @override
  String get discoveryTabOverview => 'Overview';

  @override
  String get discoveryTabDetails => 'Details';

  @override
  String get discoveryCastTitle => 'Cast';

  @override
  String get discoverySynopsisTitle => 'Synopsis';

  @override
  String get discoveryYearTitle => 'Year';

  @override
  String get discoveryContentRatingTitle => 'Content rating';

  @override
  String get discoveryStatusTitle => 'Status';

  @override
  String get discoveryAddedTitle => 'Added to library';

  @override
  String get discoveryCommunityShort => 'Community';

  @override
  String get discoveryCriticsShort => 'Critics';

  @override
  String get discoveryOrganizeLabel => 'Playlists & tags';

  @override
  String discoveryOrganizeTitle(String title) {
    return 'Save “$title”';
  }

  @override
  String get discoveryPlaylistsTab => 'Playlists';

  @override
  String get discoveryTagsTab => 'Tags';

  @override
  String get discoveryNewPlaylistHint => 'New playlist name';

  @override
  String get discoveryCreatePlaylistLabel => 'Create playlist with this title';

  @override
  String get discoveryAddedToPlaylist => 'Added';

  @override
  String get discoveryAlreadyInPlaylist => 'Already there';

  @override
  String discoveryAddToPlaylistLabel(String playlist) {
    return 'Add to $playlist';
  }

  @override
  String get discoveryNoPlaylists =>
      'No playlists yet. Name one below to create it with this title.';

  @override
  String get discoveryAddTagHint => 'Add a tag';

  @override
  String get discoveryAddTagLabel => 'Add tag';

  @override
  String get discoveryCurrentTagsTitle => 'On this title';

  @override
  String get discoverySuggestedTagsTitle => 'Suggestions';

  @override
  String get discoveryNoTags => 'No tags yet.';

  @override
  String discoveryRemoveTagLabel(String tag) {
    return 'Remove tag $tag';
  }

  @override
  String get discoveryTagsAdminOnly =>
      'Only Jellyfin administrators can change tags.';

  @override
  String get discoveryActionFailed =>
      'That didn\'t save. Check the connection and try again.';

  @override
  String get discoveryActionExpired =>
      'Your Jellyfin session expired. Sign in again.';

  @override
  String get discoveryLoadFailed => 'Couldn\'t load this from Jellyfin.';

  @override
  String get discoveryRetryLabel => 'Retry';

  @override
  String get discoveryWatchedBadge => 'Watched';

  @override
  String get discoverySwipeLikeStamp => 'LIKE';

  @override
  String get discoverySwipeNopeStamp => 'NOPE';

  @override
  String get discoverySwipeInfoLabel => 'Show details';

  @override
  String get discoveryRevealLabel => 'Reveal a pick';

  @override
  String get discoverySpinAgainLabel => 'Spin again';

  @override
  String get discoveryFavorFavoritesLabel => 'Favor favorites';

  @override
  String get discoveryFavorOffLabel => 'Off';

  @override
  String discoveryFavorPercent(int percent) {
    return '$percent%';
  }

  @override
  String get discoveryFavorNoneLabel => 'No favorites here';

  @override
  String discoveryFavorSemantic(int percent) {
    return 'At least $percent% of picks come from your favorites';
  }

  @override
  String get discoverySpinningLabel => 'Spinning…';

  @override
  String get discoveryShuffleIdleTitle => 'Can\'t decide?';

  @override
  String get discoveryShuffleIdleDescription =>
      'Spin the reel for a random pick from your current filters.';

  @override
  String discoveryShuffleLandedLabel(String title) {
    return 'Tonight\'s pick: $title';
  }

  @override
  String get discoveryFavoriteAddLabel => 'Add to Jellyfin favorites';

  @override
  String get discoveryFavoriteRemoveLabel => 'Remove from Jellyfin favorites';

  @override
  String get discoveryFavoriteError =>
      'Jellyfin could not update that favorite. Try again.';

  @override
  String get catalogLoadingLabel => 'Loading your Jellyfin library…';

  @override
  String get catalogErrorTitle => 'Your library is unavailable';

  @override
  String get catalogErrorDescription =>
      'Check the Jellyfin connection, then reconnect to refresh current results.';

  @override
  String get catalogReconnectLabel => 'Reconnect';

  @override
  String discoveryDetailsLabel(String title) {
    return 'Open details for $title';
  }

  @override
  String get discoveryTrailersLabel => 'Trailers';

  @override
  String get discoveryPlayTrailerLabel => 'Play trailer';

  @override
  String get discoveryTrailerLaunchError =>
      'That trailer could not be opened. Try again.';

  @override
  String get discoveryNoCandidatesTitle => 'No titles fit yet';

  @override
  String get discoveryNoCandidatesDescription =>
      'Adjust your filters or clear dismissed titles to keep exploring.';

  @override
  String get discoveryClearLabel => 'Clear discovery data';

  @override
  String get discoveryMoreActionsLabel => 'More actions';

  @override
  String get discoveryFiltersLabel => 'Filters';

  @override
  String get discoveryQuickRecentLabel => 'Added in last 30 days';

  @override
  String get discoveryQuickUnwatchedLabel => 'Unwatched';

  @override
  String get discoveryQuickFavoritesLabel => 'Favorites';

  @override
  String get discoveryQuickFiltersLabel => 'Quick filters';

  @override
  String get discoveryActiveFilterLabel => 'Filters active';

  @override
  String get discoveryFilterSheetTitle => 'Shape tonight\'s lineup';

  @override
  String get discoverySearchTitleLabel => 'Search titles';

  @override
  String get discoveryLibraryLabel => 'Library';

  @override
  String get discoveryAllLibrariesLabel => 'All libraries';

  @override
  String get discoverySortLabel => 'Sort by';

  @override
  String get discoverySortDefaultLabel => 'Recommended';

  @override
  String get discoverySortRandomLabel => 'Random';

  @override
  String get discoverySortRecentlyAddedLabel => 'Recently added';

  @override
  String get discoverySortTitleLabel => 'Title';

  @override
  String get discoverySortReleaseYearLabel => 'Release year';

  @override
  String get discoverySortCommunityRatingLabel => 'Community rating';

  @override
  String get discoverySortRuntimeLabel => 'Runtime';

  @override
  String get discoveryAddedWithinLabel => 'Added within';

  @override
  String get discoveryAddedWithinAnyLabel => 'Any time';

  @override
  String get discoveryAddedWithinWeekLabel => '7 days';

  @override
  String get discoveryAddedWithinMonthLabel => '30 days';

  @override
  String get discoveryAddedWithinQuarterLabel => '90 days';

  @override
  String get discoveryAddedWithinYearLabel => '365 days';

  @override
  String get discoveryResetFiltersLabel => 'Reset filters';

  @override
  String get discoveryOfficialRatingsFilterLabel => 'Content ratings';

  @override
  String get discoveryFineTuneFiltersLabel => 'Fine-tune your picks';

  @override
  String get discoveryLibraryDetailsLabel => 'Library details';

  @override
  String get discoveryApplyFiltersLabel => 'Show matches';

  @override
  String get discoveryResetAllLabel => 'Reset all';

  @override
  String get discoveryFilterTabBasics => 'Basics';

  @override
  String get discoveryFilterTabContent => 'Content';

  @override
  String get discoveryFilterTabRatings => 'Ratings';

  @override
  String get discoveryFilterTabPresets => 'Presets';

  @override
  String discoveryActiveCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active',
      one: '1 active',
    );
    return '$_temp0';
  }

  @override
  String discoverySelectedCountLabel(int count) {
    return '$count selected';
  }

  @override
  String get discoveryActiveFiltersLabel => 'Active filters';

  @override
  String get discoveryClearAllLabel => 'Clear all';

  @override
  String discoveryRemoveFilterLabel(String filter) {
    return 'Remove $filter';
  }

  @override
  String discoveryActiveSearch(String term) {
    return '“$term”';
  }

  @override
  String discoveryActiveAddedWithin(int days) {
    return 'Added in last $days days';
  }

  @override
  String discoveryActiveRuntimeRange(int minimum, int maximum) {
    return '$minimum–$maximum min';
  }

  @override
  String discoveryActiveRuntimeMinimum(int minimum) {
    return '$minimum+ min';
  }

  @override
  String discoveryActiveRuntimeMaximum(int maximum) {
    return 'Up to $maximum min';
  }

  @override
  String discoveryActiveCommunity(String value) {
    return 'Community $value';
  }

  @override
  String discoveryActiveCritic(String value) {
    return 'Critics $value';
  }

  @override
  String get discoveryActiveWatched => 'Watched';

  @override
  String get discoveryActiveUnwatched => 'Unwatched';

  @override
  String get discoveryActiveFavorites => 'Favorites';

  @override
  String get discoveryActiveNotFavorites => 'Not in favorites';

  @override
  String discoveryActiveSort(String label) {
    return 'Sorted by $label';
  }

  @override
  String get discoveryRuntimeTitle => 'Runtime';

  @override
  String get discoveryGenresTitle => 'Genres';

  @override
  String discoveryRuntimeRangeValue(int minimum, String maximum) {
    return '$minimum–$maximum min';
  }

  @override
  String get discoveryCommunityTitle => 'Community rating';

  @override
  String get discoveryCriticTitle => 'Critic rating';

  @override
  String discoveryMinimumValue(String value) {
    return '$value or higher';
  }

  @override
  String get discoveryWatchedTitle => 'Watched';

  @override
  String get discoveryFavoriteTitle => 'In favorites';

  @override
  String get discoveryOrderTitle => 'Library & order';

  @override
  String get discoverySuggestedPresetsLabel => 'Suggested presets';

  @override
  String get discoveryPresetUnwatchedLabel => 'Unwatched';

  @override
  String get discoveryPresetFavoritesLabel => 'Favorites';

  @override
  String get discoveryPresetNewAndUnseenLabel => 'New & unseen';

  @override
  String get discoveryPresetUnwatchedGemsLabel => 'Unwatched gems';

  @override
  String get discoveryPresetShortGemsLabel => 'Short gems';

  @override
  String get discoveryPresetCriticsPicksLabel => 'Critics\' picks';

  @override
  String discoveryDeletePresetLabel(String preset) {
    return 'Delete preset $preset';
  }

  @override
  String get discoveryPresetsEmpty =>
      'No saved presets yet. Save the filters you use most and bring them back with one tap.';

  @override
  String get discoverySavedPresetsLabel => 'Saved presets';

  @override
  String discoveryRuntimeFilterLabel(int minimum, int maximum) {
    return 'Runtime: $minimum–$maximum minutes';
  }

  @override
  String discoveryCommunityFilterLabel(String value) {
    return 'Minimum community rating: $value';
  }

  @override
  String discoveryCriticFilterLabel(String value) {
    return 'Minimum critic rating: $value';
  }

  @override
  String get discoveryGenresFilterLabel => 'Genres (comma separated)';

  @override
  String get discoveryDecadeFilterLabel => 'Decade';

  @override
  String get discoveryWatchedFilterLabel => 'Watched state';

  @override
  String get discoveryFavoriteFilterLabel => 'Favorite state';

  @override
  String get discoveryAnyLabel => 'Any';

  @override
  String get discoveryYesLabel => 'Yes';

  @override
  String get discoveryNoLabel => 'No';

  @override
  String get discoveryPresetsLabel => 'Filter presets';

  @override
  String get discoveryPresetNameLabel => 'Preset name';

  @override
  String get discoverySavePresetLabel => 'Save current filters';

  @override
  String get discoveryClearConfirmation =>
      'Clear filters, presets, recent picks, likes, and dismissals on this device? Your Jellyfin login stays connected.';

  @override
  String get discoveryCancelLabel => 'Cancel';

  @override
  String get discoveryConfirmClearLabel => 'Clear';

  @override
  String get discoveryUnknownValue => 'Not available';

  @override
  String get discoverySynopsisLabel => 'Synopsis';

  @override
  String discoveryYearLabel(String value) {
    return 'Year: $value';
  }

  @override
  String discoveryRuntimeLabel(String value) {
    return 'Runtime: $value';
  }

  @override
  String discoveryRuntimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String discoveryGenresLabel(String value) {
    return 'Genres: $value';
  }

  @override
  String discoveryCommunityRatingLabel(String value) {
    return 'Community rating: $value';
  }

  @override
  String discoveryCriticRatingLabel(String value) {
    return 'Critic rating: $value';
  }

  @override
  String discoveryContentRatingLabel(String value) {
    return 'Content rating: $value';
  }

  @override
  String discoveryStatusLabel(String value) {
    return 'Status: $value';
  }

  @override
  String discoveryCastLabel(String value) {
    return 'Featured cast: $value';
  }
}
