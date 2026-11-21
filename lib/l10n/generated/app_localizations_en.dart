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
  String discoveryCandidateCount(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shows',
      one: '1 show',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titles',
      one: '1 title',
    );
    String _temp2 = intl.Intl.selectLogic(kind, {
      'series': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String get discoveryBrowseLabel => 'Browse';

  @override
  String discoverySelectionCount(int count) {
    return '$count selected';
  }

  @override
  String get discoverySelectionCancelLabel => 'Cancel selection';

  @override
  String get discoverySelectAllLabel => 'Select all';

  @override
  String get discoverySelectHint => 'Select';

  @override
  String get discoveryBulkShortlistLabel => 'Shortlist';

  @override
  String get discoveryBulkUnshortlistLabel => 'Unsave';

  @override
  String get discoveryBulkShortlistTooltip => 'Add to shortlist';

  @override
  String get discoveryBulkUnshortlistTooltip => 'Remove from shortlist';

  @override
  String get discoveryBulkFavoriteLabel => 'Favorite';

  @override
  String get discoveryBulkUnfavoriteLabel => 'Unfavorite';

  @override
  String get discoveryBulkFavoriteTooltip => 'Add to favorites';

  @override
  String get discoveryBulkUnfavoriteTooltip => 'Remove from favorites';

  @override
  String get discoveryBulkPlaylistLabel => 'Playlist';

  @override
  String get discoveryBulkPlaylistTooltip => 'Add to a playlist';

  @override
  String discoveryBulkShortlistAdded(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count shows to your shortlist',
      one: 'Added 1 show to your shortlist',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count movies to your shortlist',
      one: 'Added 1 movie to your shortlist',
    );
    String _temp2 = intl.Intl.selectLogic(kind, {
      'series': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String discoveryBulkShortlistRemoved(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count shows from your shortlist',
      one: 'Removed 1 show from your shortlist',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count movies from your shortlist',
      one: 'Removed 1 movie from your shortlist',
    );
    String _temp2 = intl.Intl.selectLogic(kind, {
      'series': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String discoveryBulkFavorited(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count shows to favorites',
      one: 'Added 1 show to favorites',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count movies to favorites',
      one: 'Added 1 movie to favorites',
    );
    String _temp2 = intl.Intl.selectLogic(kind, {
      'series': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String discoveryBulkUnfavorited(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count shows from favorites',
      one: 'Removed 1 show from favorites',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count movies from favorites',
      one: 'Removed 1 movie from favorites',
    );
    String _temp2 = intl.Intl.selectLogic(kind, {
      'series': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String discoveryBulkFavoriteFailed(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn’t update $count shows. Try again.',
      one: 'Couldn’t update 1 show. Try again.',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn’t update $count movies. Try again.',
      one: 'Couldn’t update 1 movie. Try again.',
    );
    String _temp2 = intl.Intl.selectLogic(kind, {
      'series': '$_temp0',
      'other': '$_temp1',
    });
    return '$_temp2';
  }

  @override
  String discoveryBulkPlaylistTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count movies to a playlist',
      one: 'Add 1 movie to a playlist',
    );
    return '$_temp0';
  }

  @override
  String discoveryBulkPlaylistAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count',
      one: 'Added 1',
    );
    return '$_temp0';
  }

  @override
  String discoveryBulkPlaylistPartial(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn’t add $count movies. Try again.',
      one: 'Couldn’t add 1 movie. Try again.',
    );
    return '$_temp0';
  }

  @override
  String get discoveryBulkNoPlaylists =>
      'No playlists yet. Name one below to create it with these movies.';

  @override
  String get discoveryBulkCreatePlaylistLabel =>
      'Create playlist with these movies';

  @override
  String get discoveryShowAsListLabel => 'Show as list';

  @override
  String get discoveryShowAsGridLabel => 'Show as grid';

  @override
  String get discoveryListTitleColumn => 'Title';

  @override
  String get discoveryListRatedColumn => 'Rated';

  @override
  String get discoverySwipeLabel => 'Swipe';

  @override
  String get discoveryShuffleLabel => 'Shuffle';

  @override
  String get discoveryShuffleFilteredSourceLabel => 'Filtered titles';

  @override
  String get discoveryShuffleForYouSourceLabel => 'For you';

  @override
  String discoveryRecommendationReason(String reasons) {
    return 'Picked for you: $reasons';
  }

  @override
  String get discoveryShortlistLabel => 'Shortlist';

  @override
  String get discoveryMoviesLabel => 'Movies';

  @override
  String get discoveryShowsLabel => 'Shows';

  @override
  String get discoveryShowMoviesTooltip => 'Discover movies';

  @override
  String get discoveryShowShowsTooltip => 'Discover TV shows';

  @override
  String discoverySeasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seasons',
      one: '1 season',
    );
    return '$_temp0';
  }

  @override
  String discoveryEpisodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String discoveryAiredRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String discoveryAiredSince(String start) {
    return '$start–';
  }

  @override
  String discoveryEpisodesLeftBadge(int count) {
    return '$count left';
  }

  @override
  String discoveryEpisodesLeftLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unwatched episodes',
      one: '1 unwatched episode',
    );
    return '$_temp0';
  }

  @override
  String discoveryWatchedEpisodesLabel(int played, int total) {
    return '$played of $total episodes watched';
  }

  @override
  String get discoverySeriesContinuing => 'Continuing';

  @override
  String get discoverySeriesEnded => 'Ended';

  @override
  String get discoveryFilterTabShow => 'Show';

  @override
  String get discoverySeriesStatusTitle => 'Status';

  @override
  String get discoverySeriesLengthTitle => 'Length';

  @override
  String get discoverySeriesLengthMiniseries => 'Miniseries';

  @override
  String get discoverySeriesLengthShort => '2–4 seasons';

  @override
  String get discoverySeriesLengthLong => '5+ seasons';

  @override
  String get discoveryWatchProgressTitle => 'Your progress';

  @override
  String get discoveryWatchProgressNotStarted => 'Not started';

  @override
  String get discoveryWatchProgressInProgress => 'In progress';

  @override
  String get discoveryWatchProgressFinished => 'Finished';

  @override
  String get discoveryEpisodeLengthTitle => 'Episode length';

  @override
  String get discoverySortNewEpisodesLabel => 'New episodes';

  @override
  String get discoverySortFirstAiredLabel => 'First aired';

  @override
  String get discoveryPresetFinishStartedLabel => 'Finish what you started';

  @override
  String get discoveryPresetBingeableMinisLabel => 'Bingeable minis';

  @override
  String get discoveryPresetStillAiringLabel => 'Still airing';

  @override
  String get discoveryPresetUnstartedGemsLabel => 'Unstarted gems';

  @override
  String get discoveryTabEpisodes => 'Episodes';

  @override
  String get discoveryNextUpTitle => 'Next up';

  @override
  String discoveryEpisodeCode(int season, int episode) {
    return 'S$season · E$episode';
  }

  @override
  String get discoverySeasonsTitle => 'Seasons';

  @override
  String discoverySeasonProgress(int played, int total) {
    return '$played of $total watched';
  }

  @override
  String get discoveryNoSeasons => 'Jellyfin has no seasons for this show yet.';

  @override
  String get discoveryAiredTitle => 'Aired';

  @override
  String discoveryShortlistAddLabel(String title) {
    return 'Add $title to shortlist';
  }

  @override
  String discoveryShortlistRemoveLabel(String title) {
    return 'Remove $title from shortlist';
  }

  @override
  String discoveryShortlistCount(int count, String kind) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shows',
      one: '1 show',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movies',
      one: '1 movie',
    );
    String _temp2 = intl.Intl.selectLogic(kind, {
      'series': '$_temp0',
      'other': '$_temp1',
    });
    return 'Shortlist · $_temp2';
  }

  @override
  String get discoveryShortlistViewLabel => 'View shortlist';

  @override
  String discoveryShortlistPreviewPair(String first, String second) {
    return '$first, $second';
  }

  @override
  String discoveryShortlistEmpty(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'series': 'Bookmark shows to shuffle them here.',
      'other': 'Bookmark movies to shuffle them here.',
    });
    return '$_temp0';
  }

  @override
  String discoveryShortlistBrowseLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'series': 'Browse shows',
      'other': 'Browse movies',
    });
    return '$_temp0';
  }

  @override
  String get discoveryShortlistLoading => 'Loading shortlist…';

  @override
  String get discoveryShortlistIdleDescription =>
      'Drag here to pick from your shortlist.';

  @override
  String get discoveryShortlistUnavailable => 'Unavailable';

  @override
  String discoveryShortlistNoneAvailable(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'series': 'None of your saved shows are available.',
      'other': 'None of your saved movies are available.',
    });
    return '$_temp0';
  }

  @override
  String get discoveryShortlistLookupError => 'Couldn’t load your shortlist.';

  @override
  String get discoveryShortlistSaveError =>
      'Couldn’t update your shortlist. Try again.';

  @override
  String discoveryShortlistRevealLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'series': 'Reveal show',
      'other': 'Reveal movie',
    });
    return '$_temp0';
  }

  @override
  String discoveryShortlistRemoved(String title) {
    return 'Removed $title';
  }

  @override
  String get discoveryShortlistUndoLabel => 'Undo';

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
  String get discoverySwipeShortlistPull => 'Pull down to shortlist';

  @override
  String get discoverySwipeShortlistRelease => 'Release to shortlist';

  @override
  String get discoverySwipeShortlistAlreadySaved => 'Already on your shortlist';

  @override
  String discoverySwipeShortlistSaved(String title) {
    return 'Added $title to your shortlist';
  }

  @override
  String get discoverySwipeInfoLabel => 'Show details';

  @override
  String get discoveryRevealLabel => 'Reveal a pick';

  @override
  String get discoverySpinAgainLabel => 'Spin again';

  @override
  String get discoveryShuffleDurationLabel => 'Spin duration';

  @override
  String get discoveryShuffleInstantLabel => 'Instant';

  @override
  String discoveryShuffleDurationSeconds(double seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String secondsString = secondsNumberFormat.format(seconds);

    return '$secondsString s';
  }

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
      'Drag here for a random pick from your current filters.';

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
  String get discoverySortForYouLabel => 'For you';

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
  String discoveryClearConfirmation(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'series':
          'Clear filters, presets, recent picks, likes, and dismissals for shows on this device? Your movies and Jellyfin login stay as they are.',
      'other':
          'Clear filters, presets, recent picks, likes, and dismissals on this device? Your Jellyfin login stays connected.',
    });
    return '$_temp0';
  }

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
