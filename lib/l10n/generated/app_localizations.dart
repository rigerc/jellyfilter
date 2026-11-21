import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Jellyfilter'**
  String get appTitle;

  /// No description provided for @homeHeadline.
  ///
  /// In en, this message translates to:
  /// **'Pick something great'**
  String get homeHeadline;

  /// No description provided for @homeDescription.
  ///
  /// In en, this message translates to:
  /// **'A playful way to discover your Jellyfin library.'**
  String get homeDescription;

  /// No description provided for @connectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your Jellyfin'**
  String get connectionTitle;

  /// No description provided for @connectionServerUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get connectionServerUrlLabel;

  /// No description provided for @connectionUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get connectionUsernameLabel;

  /// No description provided for @connectionPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get connectionPasswordLabel;

  /// No description provided for @connectionSubmitLabel.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectionSubmitLabel;

  /// No description provided for @connectionPrivateHttpWarning.
  ///
  /// In en, this message translates to:
  /// **'This local HTTP connection is unencrypted. Continue only if you trust this private network.'**
  String get connectionPrivateHttpWarning;

  /// No description provided for @connectionContinuePrivateHttpLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue on local network'**
  String get connectionContinuePrivateHttpLabel;

  /// No description provided for @connectionConnectingLabel.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connectionConnectingLabel;

  /// No description provided for @connectionConnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectionConnectedLabel;

  /// No description provided for @connectionNeedsReauthenticationLabel.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please connect again.'**
  String get connectionNeedsReauthenticationLabel;

  /// No description provided for @connectionUnreachableError.
  ///
  /// In en, this message translates to:
  /// **'We could not reach that server. Check the address and network.'**
  String get connectionUnreachableError;

  /// No description provided for @connectionServerError.
  ///
  /// In en, this message translates to:
  /// **'The Jellyfin server is temporarily unavailable. Try again shortly.'**
  String get connectionServerError;

  /// No description provided for @connectionInvalidCertificateError.
  ///
  /// In en, this message translates to:
  /// **'The server certificate is not trusted. Use a valid HTTPS certificate.'**
  String get connectionInvalidCertificateError;

  /// No description provided for @connectionIncompatibleError.
  ///
  /// In en, this message translates to:
  /// **'That server is not a compatible Jellyfin server.'**
  String get connectionIncompatibleError;

  /// No description provided for @connectionUnsafeRedirectError.
  ///
  /// In en, this message translates to:
  /// **'The server redirected the request unsafely. Check the address and try again.'**
  String get connectionUnsafeRedirectError;

  /// No description provided for @connectionInvalidCredentialsError.
  ///
  /// In en, this message translates to:
  /// **'Those credentials were not accepted.'**
  String get connectionInvalidCredentialsError;

  /// No description provided for @connectionExpiredSessionError.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please connect again.'**
  String get connectionExpiredSessionError;

  /// No description provided for @connectionInvalidUrlError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Jellyfin server address.'**
  String get connectionInvalidUrlError;

  /// No description provided for @connectionPublicHttpError.
  ///
  /// In en, this message translates to:
  /// **'Public HTTP connections are not allowed. Use HTTPS.'**
  String get connectionPublicHttpError;

  /// No description provided for @connectionStorageError.
  ///
  /// In en, this message translates to:
  /// **'Secure session storage is unavailable on this device.'**
  String get connectionStorageError;

  /// No description provided for @connectionUnknownError.
  ///
  /// In en, this message translates to:
  /// **'We could not complete the connection. Try again.'**
  String get connectionUnknownError;

  /// No description provided for @connectionSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected to Jellyfin'**
  String get connectionSummaryTitle;

  /// No description provided for @connectionSummaryServerLabel.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get connectionSummaryServerLabel;

  /// No description provided for @connectionSummaryUserLabel.
  ///
  /// In en, this message translates to:
  /// **'Signed in as'**
  String get connectionSummaryUserLabel;

  /// No description provided for @connectionLogoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get connectionLogoutLabel;

  /// No description provided for @connectionExploreLabel.
  ///
  /// In en, this message translates to:
  /// **'Explore library'**
  String get connectionExploreLabel;

  /// No description provided for @discoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Jellyfilter'**
  String get discoveryTitle;

  /// No description provided for @discoveryCandidateCount.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{{count, plural, =1{1 show} other{{count} shows}}} other{{count, plural, =1{1 title} other{{count} titles}}}}'**
  String discoveryCandidateCount(int count, String kind);

  /// No description provided for @discoveryBrowseLabel.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get discoveryBrowseLabel;

  /// No description provided for @discoverySelectionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String discoverySelectionCount(int count);

  /// No description provided for @discoverySelectionCancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get discoverySelectionCancelLabel;

  /// No description provided for @discoverySelectAllLabel.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get discoverySelectAllLabel;

  /// No description provided for @discoverySelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get discoverySelectHint;

  /// No description provided for @discoveryBulkShortlistLabel.
  ///
  /// In en, this message translates to:
  /// **'Shortlist'**
  String get discoveryBulkShortlistLabel;

  /// No description provided for @discoveryBulkUnshortlistLabel.
  ///
  /// In en, this message translates to:
  /// **'Unsave'**
  String get discoveryBulkUnshortlistLabel;

  /// No description provided for @discoveryBulkShortlistTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to shortlist'**
  String get discoveryBulkShortlistTooltip;

  /// No description provided for @discoveryBulkUnshortlistTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from shortlist'**
  String get discoveryBulkUnshortlistTooltip;

  /// No description provided for @discoveryBulkFavoriteLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get discoveryBulkFavoriteLabel;

  /// No description provided for @discoveryBulkUnfavoriteLabel.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get discoveryBulkUnfavoriteLabel;

  /// No description provided for @discoveryBulkFavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get discoveryBulkFavoriteTooltip;

  /// No description provided for @discoveryBulkUnfavoriteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get discoveryBulkUnfavoriteTooltip;

  /// No description provided for @discoveryBulkPlaylistLabel.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get discoveryBulkPlaylistLabel;

  /// No description provided for @discoveryBulkPlaylistTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add to a playlist'**
  String get discoveryBulkPlaylistTooltip;

  /// No description provided for @discoveryBulkShortlistAdded.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{{count, plural, =1{Added 1 show to your shortlist} other{Added {count} shows to your shortlist}}} other{{count, plural, =1{Added 1 movie to your shortlist} other{Added {count} movies to your shortlist}}}}'**
  String discoveryBulkShortlistAdded(int count, String kind);

  /// No description provided for @discoveryBulkShortlistRemoved.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{{count, plural, =1{Removed 1 show from your shortlist} other{Removed {count} shows from your shortlist}}} other{{count, plural, =1{Removed 1 movie from your shortlist} other{Removed {count} movies from your shortlist}}}}'**
  String discoveryBulkShortlistRemoved(int count, String kind);

  /// No description provided for @discoveryBulkFavorited.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{{count, plural, =1{Added 1 show to favorites} other{Added {count} shows to favorites}}} other{{count, plural, =1{Added 1 movie to favorites} other{Added {count} movies to favorites}}}}'**
  String discoveryBulkFavorited(int count, String kind);

  /// No description provided for @discoveryBulkUnfavorited.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{{count, plural, =1{Removed 1 show from favorites} other{Removed {count} shows from favorites}}} other{{count, plural, =1{Removed 1 movie from favorites} other{Removed {count} movies from favorites}}}}'**
  String discoveryBulkUnfavorited(int count, String kind);

  /// No description provided for @discoveryBulkFavoriteFailed.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{{count, plural, =1{Couldn’t update 1 show. Try again.} other{Couldn’t update {count} shows. Try again.}}} other{{count, plural, =1{Couldn’t update 1 movie. Try again.} other{Couldn’t update {count} movies. Try again.}}}}'**
  String discoveryBulkFavoriteFailed(int count, String kind);

  /// No description provided for @discoveryBulkPlaylistTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Add 1 movie to a playlist} other{Add {count} movies to a playlist}}'**
  String discoveryBulkPlaylistTitle(int count);

  /// No description provided for @discoveryBulkPlaylistAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1} other{Added {count}}}'**
  String discoveryBulkPlaylistAdded(int count);

  /// No description provided for @discoveryBulkPlaylistPartial.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Couldn’t add 1 movie. Try again.} other{Couldn’t add {count} movies. Try again.}}'**
  String discoveryBulkPlaylistPartial(int count);

  /// No description provided for @discoveryBulkNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Name one below to create it with these movies.'**
  String get discoveryBulkNoPlaylists;

  /// No description provided for @discoveryBulkCreatePlaylistLabel.
  ///
  /// In en, this message translates to:
  /// **'Create playlist with these movies'**
  String get discoveryBulkCreatePlaylistLabel;

  /// No description provided for @discoveryShowAsListLabel.
  ///
  /// In en, this message translates to:
  /// **'Show as list'**
  String get discoveryShowAsListLabel;

  /// No description provided for @discoveryShowAsGridLabel.
  ///
  /// In en, this message translates to:
  /// **'Show as grid'**
  String get discoveryShowAsGridLabel;

  /// No description provided for @discoveryListTitleColumn.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get discoveryListTitleColumn;

  /// No description provided for @discoveryListRatedColumn.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get discoveryListRatedColumn;

  /// No description provided for @discoverySwipeLabel.
  ///
  /// In en, this message translates to:
  /// **'Swipe'**
  String get discoverySwipeLabel;

  /// No description provided for @discoveryShuffleLabel.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get discoveryShuffleLabel;

  /// No description provided for @discoveryShuffleFilteredSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Filtered titles'**
  String get discoveryShuffleFilteredSourceLabel;

  /// No description provided for @discoveryShuffleForYouSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get discoveryShuffleForYouSourceLabel;

  /// No description provided for @discoveryRecommendationReason.
  ///
  /// In en, this message translates to:
  /// **'Picked for you: {reasons}'**
  String discoveryRecommendationReason(String reasons);

  /// No description provided for @discoveryShortlistLabel.
  ///
  /// In en, this message translates to:
  /// **'Shortlist'**
  String get discoveryShortlistLabel;

  /// No description provided for @discoveryMoviesLabel.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get discoveryMoviesLabel;

  /// No description provided for @discoveryShowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Shows'**
  String get discoveryShowsLabel;

  /// No description provided for @discoveryShowMoviesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discover movies'**
  String get discoveryShowMoviesTooltip;

  /// No description provided for @discoveryShowShowsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Discover TV shows'**
  String get discoveryShowShowsTooltip;

  /// No description provided for @discoverySeasonCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 season} other{{count} seasons}}'**
  String discoverySeasonCount(int count);

  /// No description provided for @discoveryEpisodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode} other{{count} episodes}}'**
  String discoveryEpisodeCount(int count);

  /// No description provided for @discoveryAiredRange.
  ///
  /// In en, this message translates to:
  /// **'{start}–{end}'**
  String discoveryAiredRange(String start, String end);

  /// No description provided for @discoveryAiredSince.
  ///
  /// In en, this message translates to:
  /// **'{start}–'**
  String discoveryAiredSince(String start);

  /// No description provided for @discoveryEpisodesLeftBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String discoveryEpisodesLeftBadge(int count);

  /// No description provided for @discoveryEpisodesLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unwatched episode} other{{count} unwatched episodes}}'**
  String discoveryEpisodesLeftLabel(int count);

  /// No description provided for @discoveryWatchedEpisodesLabel.
  ///
  /// In en, this message translates to:
  /// **'{played} of {total} episodes watched'**
  String discoveryWatchedEpisodesLabel(int played, int total);

  /// No description provided for @discoverySeriesContinuing.
  ///
  /// In en, this message translates to:
  /// **'Continuing'**
  String get discoverySeriesContinuing;

  /// No description provided for @discoverySeriesEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get discoverySeriesEnded;

  /// No description provided for @discoveryFilterTabShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get discoveryFilterTabShow;

  /// No description provided for @discoverySeriesStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get discoverySeriesStatusTitle;

  /// No description provided for @discoverySeriesLengthTitle.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get discoverySeriesLengthTitle;

  /// No description provided for @discoverySeriesLengthMiniseries.
  ///
  /// In en, this message translates to:
  /// **'Miniseries'**
  String get discoverySeriesLengthMiniseries;

  /// No description provided for @discoverySeriesLengthShort.
  ///
  /// In en, this message translates to:
  /// **'2–4 seasons'**
  String get discoverySeriesLengthShort;

  /// No description provided for @discoverySeriesLengthLong.
  ///
  /// In en, this message translates to:
  /// **'5+ seasons'**
  String get discoverySeriesLengthLong;

  /// No description provided for @discoveryWatchProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get discoveryWatchProgressTitle;

  /// No description provided for @discoveryWatchProgressNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get discoveryWatchProgressNotStarted;

  /// No description provided for @discoveryWatchProgressInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get discoveryWatchProgressInProgress;

  /// No description provided for @discoveryWatchProgressFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get discoveryWatchProgressFinished;

  /// No description provided for @discoveryEpisodeLengthTitle.
  ///
  /// In en, this message translates to:
  /// **'Episode length'**
  String get discoveryEpisodeLengthTitle;

  /// No description provided for @discoverySortNewEpisodesLabel.
  ///
  /// In en, this message translates to:
  /// **'New episodes'**
  String get discoverySortNewEpisodesLabel;

  /// No description provided for @discoverySortFirstAiredLabel.
  ///
  /// In en, this message translates to:
  /// **'First aired'**
  String get discoverySortFirstAiredLabel;

  /// No description provided for @discoveryPresetFinishStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Finish what you started'**
  String get discoveryPresetFinishStartedLabel;

  /// No description provided for @discoveryPresetBingeableMinisLabel.
  ///
  /// In en, this message translates to:
  /// **'Bingeable minis'**
  String get discoveryPresetBingeableMinisLabel;

  /// No description provided for @discoveryPresetStillAiringLabel.
  ///
  /// In en, this message translates to:
  /// **'Still airing'**
  String get discoveryPresetStillAiringLabel;

  /// No description provided for @discoveryPresetUnstartedGemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Unstarted gems'**
  String get discoveryPresetUnstartedGemsLabel;

  /// No description provided for @discoveryTabEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get discoveryTabEpisodes;

  /// No description provided for @discoveryNextUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Next up'**
  String get discoveryNextUpTitle;

  /// No description provided for @discoveryEpisodeCode.
  ///
  /// In en, this message translates to:
  /// **'S{season} · E{episode}'**
  String discoveryEpisodeCode(int season, int episode);

  /// No description provided for @discoverySeasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get discoverySeasonsTitle;

  /// No description provided for @discoverySeasonProgress.
  ///
  /// In en, this message translates to:
  /// **'{played} of {total} watched'**
  String discoverySeasonProgress(int played, int total);

  /// No description provided for @discoveryNoSeasons.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin has no seasons for this show yet.'**
  String get discoveryNoSeasons;

  /// No description provided for @discoveryAiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Aired'**
  String get discoveryAiredTitle;

  /// No description provided for @discoveryShortlistAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add {title} to shortlist'**
  String discoveryShortlistAddLabel(String title);

  /// No description provided for @discoveryShortlistRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove {title} from shortlist'**
  String discoveryShortlistRemoveLabel(String title);

  /// No description provided for @discoveryShortlistCount.
  ///
  /// In en, this message translates to:
  /// **'Shortlist · {kind, select, series{{count, plural, =1{1 show} other{{count} shows}}} other{{count, plural, =1{1 movie} other{{count} movies}}}}'**
  String discoveryShortlistCount(int count, String kind);

  /// No description provided for @discoveryShortlistViewLabel.
  ///
  /// In en, this message translates to:
  /// **'View shortlist'**
  String get discoveryShortlistViewLabel;

  /// No description provided for @discoveryShortlistPreviewPair.
  ///
  /// In en, this message translates to:
  /// **'{first}, {second}'**
  String discoveryShortlistPreviewPair(String first, String second);

  /// No description provided for @discoveryShortlistEmpty.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{Bookmark shows to shuffle them here.} other{Bookmark movies to shuffle them here.}}'**
  String discoveryShortlistEmpty(String kind);

  /// No description provided for @discoveryShortlistBrowseLabel.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{Browse shows} other{Browse movies}}'**
  String discoveryShortlistBrowseLabel(String kind);

  /// No description provided for @discoveryShortlistLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading shortlist…'**
  String get discoveryShortlistLoading;

  /// No description provided for @discoveryShortlistIdleDescription.
  ///
  /// In en, this message translates to:
  /// **'Drag here to pick from your shortlist.'**
  String get discoveryShortlistIdleDescription;

  /// No description provided for @discoveryShortlistUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get discoveryShortlistUnavailable;

  /// No description provided for @discoveryShortlistNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{None of your saved shows are available.} other{None of your saved movies are available.}}'**
  String discoveryShortlistNoneAvailable(String kind);

  /// No description provided for @discoveryShortlistLookupError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your shortlist.'**
  String get discoveryShortlistLookupError;

  /// No description provided for @discoveryShortlistSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t update your shortlist. Try again.'**
  String get discoveryShortlistSaveError;

  /// No description provided for @discoveryShortlistRevealLabel.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{Reveal show} other{Reveal movie}}'**
  String discoveryShortlistRevealLabel(String kind);

  /// No description provided for @discoveryShortlistRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {title}'**
  String discoveryShortlistRemoved(String title);

  /// No description provided for @discoveryShortlistUndoLabel.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get discoveryShortlistUndoLabel;

  /// No description provided for @discoveryLikeLabel.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get discoveryLikeLabel;

  /// No description provided for @discoveryRejectLabel.
  ///
  /// In en, this message translates to:
  /// **'Not this one'**
  String get discoveryRejectLabel;

  /// No description provided for @discoveryFadeWatchedLabel.
  ///
  /// In en, this message translates to:
  /// **'Fade watched'**
  String get discoveryFadeWatchedLabel;

  /// No description provided for @discoveryReverseSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Reverse order'**
  String get discoveryReverseSortLabel;

  /// No description provided for @discoveryFindTagHint.
  ///
  /// In en, this message translates to:
  /// **'Find a tag'**
  String get discoveryFindTagHint;

  /// No description provided for @discoveryTagsShownLabel.
  ///
  /// In en, this message translates to:
  /// **'Showing the {shown} most used of {total} tags. Search to find others.'**
  String discoveryTagsShownLabel(int shown, int total);

  /// No description provided for @discoveryChipLegend.
  ///
  /// In en, this message translates to:
  /// **'Tap once to require, twice to exclude, again to clear.'**
  String get discoveryChipLegend;

  /// No description provided for @discoveryChipRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get discoveryChipRequired;

  /// No description provided for @discoveryChipExcluded.
  ///
  /// In en, this message translates to:
  /// **'Excluded'**
  String get discoveryChipExcluded;

  /// No description provided for @discoveryRequiredCount.
  ///
  /// In en, this message translates to:
  /// **'{count} required'**
  String discoveryRequiredCount(int count);

  /// No description provided for @discoveryExcludedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} excluded'**
  String discoveryExcludedCount(int count);

  /// No description provided for @discoveryActiveSortReversed.
  ///
  /// In en, this message translates to:
  /// **'Sorted by {label}, reversed'**
  String discoveryActiveSortReversed(String label);

  /// No description provided for @discoveryActiveExcluded.
  ///
  /// In en, this message translates to:
  /// **'Not {value}'**
  String discoveryActiveExcluded(String value);

  /// No description provided for @discoveryActiveTag.
  ///
  /// In en, this message translates to:
  /// **'Tag: {value}'**
  String discoveryActiveTag(String value);

  /// No description provided for @discoveryTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get discoveryTabOverview;

  /// No description provided for @discoveryTabDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get discoveryTabDetails;

  /// No description provided for @discoveryCastTitle.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get discoveryCastTitle;

  /// No description provided for @discoverySynopsisTitle.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get discoverySynopsisTitle;

  /// No description provided for @discoveryYearTitle.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get discoveryYearTitle;

  /// No description provided for @discoveryContentRatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Content rating'**
  String get discoveryContentRatingTitle;

  /// No description provided for @discoveryStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get discoveryStatusTitle;

  /// No description provided for @discoveryAddedTitle.
  ///
  /// In en, this message translates to:
  /// **'Added to library'**
  String get discoveryAddedTitle;

  /// No description provided for @discoveryCommunityShort.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get discoveryCommunityShort;

  /// No description provided for @discoveryCriticsShort.
  ///
  /// In en, this message translates to:
  /// **'Critics'**
  String get discoveryCriticsShort;

  /// No description provided for @discoveryOrganizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Playlists & tags'**
  String get discoveryOrganizeLabel;

  /// No description provided for @discoveryOrganizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Save “{title}”'**
  String discoveryOrganizeTitle(String title);

  /// No description provided for @discoveryPlaylistsTab.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get discoveryPlaylistsTab;

  /// No description provided for @discoveryTagsTab.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get discoveryTagsTab;

  /// No description provided for @discoveryNewPlaylistHint.
  ///
  /// In en, this message translates to:
  /// **'New playlist name'**
  String get discoveryNewPlaylistHint;

  /// No description provided for @discoveryCreatePlaylistLabel.
  ///
  /// In en, this message translates to:
  /// **'Create playlist with this title'**
  String get discoveryCreatePlaylistLabel;

  /// No description provided for @discoveryAddedToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get discoveryAddedToPlaylist;

  /// No description provided for @discoveryAlreadyInPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Already there'**
  String get discoveryAlreadyInPlaylist;

  /// No description provided for @discoveryAddToPlaylistLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to {playlist}'**
  String discoveryAddToPlaylistLabel(String playlist);

  /// No description provided for @discoveryNoPlaylists.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Name one below to create it with this title.'**
  String get discoveryNoPlaylists;

  /// No description provided for @discoveryAddTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get discoveryAddTagHint;

  /// No description provided for @discoveryAddTagLabel.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get discoveryAddTagLabel;

  /// No description provided for @discoveryCurrentTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'On this title'**
  String get discoveryCurrentTagsTitle;

  /// No description provided for @discoverySuggestedTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get discoverySuggestedTagsTitle;

  /// No description provided for @discoveryNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet.'**
  String get discoveryNoTags;

  /// No description provided for @discoveryRemoveTagLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove tag {tag}'**
  String discoveryRemoveTagLabel(String tag);

  /// No description provided for @discoveryTagsAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only Jellyfin administrators can change tags.'**
  String get discoveryTagsAdminOnly;

  /// No description provided for @discoveryActionFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t save. Check the connection and try again.'**
  String get discoveryActionFailed;

  /// No description provided for @discoveryActionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your Jellyfin session expired. Sign in again.'**
  String get discoveryActionExpired;

  /// No description provided for @discoveryLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this from Jellyfin.'**
  String get discoveryLoadFailed;

  /// No description provided for @discoveryRetryLabel.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get discoveryRetryLabel;

  /// No description provided for @discoveryWatchedBadge.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get discoveryWatchedBadge;

  /// No description provided for @discoverySwipeLikeStamp.
  ///
  /// In en, this message translates to:
  /// **'LIKE'**
  String get discoverySwipeLikeStamp;

  /// No description provided for @discoverySwipeNopeStamp.
  ///
  /// In en, this message translates to:
  /// **'NOPE'**
  String get discoverySwipeNopeStamp;

  /// No description provided for @discoverySwipeShortlistPull.
  ///
  /// In en, this message translates to:
  /// **'Pull down to shortlist'**
  String get discoverySwipeShortlistPull;

  /// No description provided for @discoverySwipeShortlistRelease.
  ///
  /// In en, this message translates to:
  /// **'Release to shortlist'**
  String get discoverySwipeShortlistRelease;

  /// No description provided for @discoverySwipeShortlistAlreadySaved.
  ///
  /// In en, this message translates to:
  /// **'Already on your shortlist'**
  String get discoverySwipeShortlistAlreadySaved;

  /// No description provided for @discoverySwipeShortlistSaved.
  ///
  /// In en, this message translates to:
  /// **'Added {title} to your shortlist'**
  String discoverySwipeShortlistSaved(String title);

  /// No description provided for @discoverySwipeInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get discoverySwipeInfoLabel;

  /// No description provided for @discoveryRevealLabel.
  ///
  /// In en, this message translates to:
  /// **'Reveal a pick'**
  String get discoveryRevealLabel;

  /// No description provided for @discoverySpinAgainLabel.
  ///
  /// In en, this message translates to:
  /// **'Spin again'**
  String get discoverySpinAgainLabel;

  /// No description provided for @discoveryShuffleDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Spin duration'**
  String get discoveryShuffleDurationLabel;

  /// No description provided for @discoveryShuffleInstantLabel.
  ///
  /// In en, this message translates to:
  /// **'Instant'**
  String get discoveryShuffleInstantLabel;

  /// No description provided for @discoveryShuffleDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String discoveryShuffleDurationSeconds(double seconds);

  /// No description provided for @discoveryFavorFavoritesLabel.
  ///
  /// In en, this message translates to:
  /// **'Favor favorites'**
  String get discoveryFavorFavoritesLabel;

  /// No description provided for @discoveryFavorOffLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get discoveryFavorOffLabel;

  /// No description provided for @discoveryFavorPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String discoveryFavorPercent(int percent);

  /// No description provided for @discoveryFavorNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'No favorites here'**
  String get discoveryFavorNoneLabel;

  /// No description provided for @discoveryFavorSemantic.
  ///
  /// In en, this message translates to:
  /// **'At least {percent}% of picks come from your favorites'**
  String discoveryFavorSemantic(int percent);

  /// No description provided for @discoverySpinningLabel.
  ///
  /// In en, this message translates to:
  /// **'Spinning…'**
  String get discoverySpinningLabel;

  /// No description provided for @discoveryShuffleIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'Can\'t decide?'**
  String get discoveryShuffleIdleTitle;

  /// No description provided for @discoveryShuffleIdleDescription.
  ///
  /// In en, this message translates to:
  /// **'Drag here for a random pick from your current filters.'**
  String get discoveryShuffleIdleDescription;

  /// No description provided for @discoveryShuffleLandedLabel.
  ///
  /// In en, this message translates to:
  /// **'Tonight\'s pick: {title}'**
  String discoveryShuffleLandedLabel(String title);

  /// No description provided for @discoveryFavoriteAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add to Jellyfin favorites'**
  String get discoveryFavoriteAddLabel;

  /// No description provided for @discoveryFavoriteRemoveLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove from Jellyfin favorites'**
  String get discoveryFavoriteRemoveLabel;

  /// No description provided for @discoveryFavoriteError.
  ///
  /// In en, this message translates to:
  /// **'Jellyfin could not update that favorite. Try again.'**
  String get discoveryFavoriteError;

  /// No description provided for @catalogLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading your Jellyfin library…'**
  String get catalogLoadingLabel;

  /// No description provided for @catalogErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is unavailable'**
  String get catalogErrorTitle;

  /// No description provided for @catalogErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Check the Jellyfin connection, then reconnect to refresh current results.'**
  String get catalogErrorDescription;

  /// No description provided for @catalogReconnectLabel.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get catalogReconnectLabel;

  /// No description provided for @discoveryDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Open details for {title}'**
  String discoveryDetailsLabel(String title);

  /// No description provided for @discoveryTrailersLabel.
  ///
  /// In en, this message translates to:
  /// **'Trailers'**
  String get discoveryTrailersLabel;

  /// No description provided for @discoveryPlayTrailerLabel.
  ///
  /// In en, this message translates to:
  /// **'Play trailer'**
  String get discoveryPlayTrailerLabel;

  /// No description provided for @discoveryTrailerLaunchError.
  ///
  /// In en, this message translates to:
  /// **'That trailer could not be opened. Try again.'**
  String get discoveryTrailerLaunchError;

  /// No description provided for @discoveryNoCandidatesTitle.
  ///
  /// In en, this message translates to:
  /// **'No titles fit yet'**
  String get discoveryNoCandidatesTitle;

  /// No description provided for @discoveryNoCandidatesDescription.
  ///
  /// In en, this message translates to:
  /// **'Adjust your filters or clear dismissed titles to keep exploring.'**
  String get discoveryNoCandidatesDescription;

  /// No description provided for @discoveryClearLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear discovery data'**
  String get discoveryClearLabel;

  /// No description provided for @discoveryMoreActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get discoveryMoreActionsLabel;

  /// No description provided for @discoveryFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get discoveryFiltersLabel;

  /// No description provided for @discoveryQuickRecentLabel.
  ///
  /// In en, this message translates to:
  /// **'Added in last 30 days'**
  String get discoveryQuickRecentLabel;

  /// No description provided for @discoveryQuickUnwatchedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get discoveryQuickUnwatchedLabel;

  /// No description provided for @discoveryQuickFavoritesLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get discoveryQuickFavoritesLabel;

  /// No description provided for @discoveryQuickFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Quick filters'**
  String get discoveryQuickFiltersLabel;

  /// No description provided for @discoveryActiveFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters active'**
  String get discoveryActiveFilterLabel;

  /// No description provided for @discoveryFilterSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Shape tonight\'s lineup'**
  String get discoveryFilterSheetTitle;

  /// No description provided for @discoverySearchTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Search titles'**
  String get discoverySearchTitleLabel;

  /// No description provided for @discoveryLibraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get discoveryLibraryLabel;

  /// No description provided for @discoveryAllLibrariesLabel.
  ///
  /// In en, this message translates to:
  /// **'All libraries'**
  String get discoveryAllLibrariesLabel;

  /// No description provided for @discoverySortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get discoverySortLabel;

  /// No description provided for @discoverySortDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get discoverySortDefaultLabel;

  /// No description provided for @discoverySortForYouLabel.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get discoverySortForYouLabel;

  /// No description provided for @discoverySortRandomLabel.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get discoverySortRandomLabel;

  /// No description provided for @discoverySortRecentlyAddedLabel.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get discoverySortRecentlyAddedLabel;

  /// No description provided for @discoverySortTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get discoverySortTitleLabel;

  /// No description provided for @discoverySortReleaseYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Release year'**
  String get discoverySortReleaseYearLabel;

  /// No description provided for @discoverySortCommunityRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Community rating'**
  String get discoverySortCommunityRatingLabel;

  /// No description provided for @discoverySortRuntimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get discoverySortRuntimeLabel;

  /// No description provided for @discoveryAddedWithinLabel.
  ///
  /// In en, this message translates to:
  /// **'Added within'**
  String get discoveryAddedWithinLabel;

  /// No description provided for @discoveryAddedWithinAnyLabel.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get discoveryAddedWithinAnyLabel;

  /// No description provided for @discoveryAddedWithinWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get discoveryAddedWithinWeekLabel;

  /// No description provided for @discoveryAddedWithinMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get discoveryAddedWithinMonthLabel;

  /// No description provided for @discoveryAddedWithinQuarterLabel.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get discoveryAddedWithinQuarterLabel;

  /// No description provided for @discoveryAddedWithinYearLabel.
  ///
  /// In en, this message translates to:
  /// **'365 days'**
  String get discoveryAddedWithinYearLabel;

  /// No description provided for @discoveryResetFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get discoveryResetFiltersLabel;

  /// No description provided for @discoveryOfficialRatingsFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Content ratings'**
  String get discoveryOfficialRatingsFilterLabel;

  /// No description provided for @discoveryFineTuneFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune your picks'**
  String get discoveryFineTuneFiltersLabel;

  /// No description provided for @discoveryLibraryDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Library details'**
  String get discoveryLibraryDetailsLabel;

  /// No description provided for @discoveryApplyFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Show matches'**
  String get discoveryApplyFiltersLabel;

  /// No description provided for @discoveryResetAllLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get discoveryResetAllLabel;

  /// No description provided for @discoveryFilterTabBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get discoveryFilterTabBasics;

  /// No description provided for @discoveryFilterTabContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get discoveryFilterTabContent;

  /// No description provided for @discoveryFilterTabRatings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get discoveryFilterTabRatings;

  /// No description provided for @discoveryFilterTabPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get discoveryFilterTabPresets;

  /// No description provided for @discoveryActiveCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active} other{{count} active}}'**
  String discoveryActiveCountLabel(int count);

  /// No description provided for @discoverySelectedCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String discoverySelectedCountLabel(int count);

  /// No description provided for @discoveryActiveFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Active filters'**
  String get discoveryActiveFiltersLabel;

  /// No description provided for @discoveryClearAllLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get discoveryClearAllLabel;

  /// No description provided for @discoveryRemoveFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Remove {filter}'**
  String discoveryRemoveFilterLabel(String filter);

  /// No description provided for @discoveryActiveSearch.
  ///
  /// In en, this message translates to:
  /// **'“{term}”'**
  String discoveryActiveSearch(String term);

  /// No description provided for @discoveryActiveAddedWithin.
  ///
  /// In en, this message translates to:
  /// **'Added in last {days} days'**
  String discoveryActiveAddedWithin(int days);

  /// No description provided for @discoveryActiveRuntimeRange.
  ///
  /// In en, this message translates to:
  /// **'{minimum}–{maximum} min'**
  String discoveryActiveRuntimeRange(int minimum, int maximum);

  /// No description provided for @discoveryActiveRuntimeMinimum.
  ///
  /// In en, this message translates to:
  /// **'{minimum}+ min'**
  String discoveryActiveRuntimeMinimum(int minimum);

  /// No description provided for @discoveryActiveRuntimeMaximum.
  ///
  /// In en, this message translates to:
  /// **'Up to {maximum} min'**
  String discoveryActiveRuntimeMaximum(int maximum);

  /// No description provided for @discoveryActiveCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community {value}'**
  String discoveryActiveCommunity(String value);

  /// No description provided for @discoveryActiveCritic.
  ///
  /// In en, this message translates to:
  /// **'Critics {value}'**
  String discoveryActiveCritic(String value);

  /// No description provided for @discoveryActiveWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get discoveryActiveWatched;

  /// No description provided for @discoveryActiveUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get discoveryActiveUnwatched;

  /// No description provided for @discoveryActiveFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get discoveryActiveFavorites;

  /// No description provided for @discoveryActiveNotFavorites.
  ///
  /// In en, this message translates to:
  /// **'Not in favorites'**
  String get discoveryActiveNotFavorites;

  /// No description provided for @discoveryActiveSort.
  ///
  /// In en, this message translates to:
  /// **'Sorted by {label}'**
  String discoveryActiveSort(String label);

  /// No description provided for @discoveryRuntimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get discoveryRuntimeTitle;

  /// No description provided for @discoveryGenresTitle.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get discoveryGenresTitle;

  /// No description provided for @discoveryRuntimeRangeValue.
  ///
  /// In en, this message translates to:
  /// **'{minimum}–{maximum} min'**
  String discoveryRuntimeRangeValue(int minimum, String maximum);

  /// No description provided for @discoveryCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community rating'**
  String get discoveryCommunityTitle;

  /// No description provided for @discoveryCriticTitle.
  ///
  /// In en, this message translates to:
  /// **'Critic rating'**
  String get discoveryCriticTitle;

  /// No description provided for @discoveryMinimumValue.
  ///
  /// In en, this message translates to:
  /// **'{value} or higher'**
  String discoveryMinimumValue(String value);

  /// No description provided for @discoveryWatchedTitle.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get discoveryWatchedTitle;

  /// No description provided for @discoveryFavoriteTitle.
  ///
  /// In en, this message translates to:
  /// **'In favorites'**
  String get discoveryFavoriteTitle;

  /// No description provided for @discoveryOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Library & order'**
  String get discoveryOrderTitle;

  /// No description provided for @discoverySuggestedPresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested presets'**
  String get discoverySuggestedPresetsLabel;

  /// No description provided for @discoveryPresetUnwatchedLabel.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get discoveryPresetUnwatchedLabel;

  /// No description provided for @discoveryPresetFavoritesLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get discoveryPresetFavoritesLabel;

  /// No description provided for @discoveryPresetNewAndUnseenLabel.
  ///
  /// In en, this message translates to:
  /// **'New & unseen'**
  String get discoveryPresetNewAndUnseenLabel;

  /// No description provided for @discoveryPresetUnwatchedGemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Unwatched gems'**
  String get discoveryPresetUnwatchedGemsLabel;

  /// No description provided for @discoveryPresetShortGemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Short gems'**
  String get discoveryPresetShortGemsLabel;

  /// No description provided for @discoveryPresetCriticsPicksLabel.
  ///
  /// In en, this message translates to:
  /// **'Critics\' picks'**
  String get discoveryPresetCriticsPicksLabel;

  /// No description provided for @discoveryDeletePresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete preset {preset}'**
  String discoveryDeletePresetLabel(String preset);

  /// No description provided for @discoveryPresetsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved presets yet. Save the filters you use most and bring them back with one tap.'**
  String get discoveryPresetsEmpty;

  /// No description provided for @discoverySavedPresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved presets'**
  String get discoverySavedPresetsLabel;

  /// No description provided for @discoveryRuntimeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Runtime: {minimum}–{maximum} minutes'**
  String discoveryRuntimeFilterLabel(int minimum, int maximum);

  /// No description provided for @discoveryCommunityFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum community rating: {value}'**
  String discoveryCommunityFilterLabel(String value);

  /// No description provided for @discoveryCriticFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum critic rating: {value}'**
  String discoveryCriticFilterLabel(String value);

  /// No description provided for @discoveryGenresFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Genres (comma separated)'**
  String get discoveryGenresFilterLabel;

  /// No description provided for @discoveryDecadeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Decade'**
  String get discoveryDecadeFilterLabel;

  /// No description provided for @discoveryWatchedFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Watched state'**
  String get discoveryWatchedFilterLabel;

  /// No description provided for @discoveryFavoriteFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Favorite state'**
  String get discoveryFavoriteFilterLabel;

  /// No description provided for @discoveryAnyLabel.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get discoveryAnyLabel;

  /// No description provided for @discoveryYesLabel.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get discoveryYesLabel;

  /// No description provided for @discoveryNoLabel.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get discoveryNoLabel;

  /// No description provided for @discoveryPresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter presets'**
  String get discoveryPresetsLabel;

  /// No description provided for @discoveryPresetNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get discoveryPresetNameLabel;

  /// No description provided for @discoverySavePresetLabel.
  ///
  /// In en, this message translates to:
  /// **'Save current filters'**
  String get discoverySavePresetLabel;

  /// No description provided for @discoveryClearConfirmation.
  ///
  /// In en, this message translates to:
  /// **'{kind, select, series{Clear filters, presets, recent picks, likes, and dismissals for shows on this device? Your movies and Jellyfin login stay as they are.} other{Clear filters, presets, recent picks, likes, and dismissals on this device? Your Jellyfin login stays connected.}}'**
  String discoveryClearConfirmation(String kind);

  /// No description provided for @discoveryCancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get discoveryCancelLabel;

  /// No description provided for @discoveryConfirmClearLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get discoveryConfirmClearLabel;

  /// No description provided for @discoveryUnknownValue.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get discoveryUnknownValue;

  /// No description provided for @discoverySynopsisLabel.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get discoverySynopsisLabel;

  /// No description provided for @discoveryYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year: {value}'**
  String discoveryYearLabel(String value);

  /// No description provided for @discoveryRuntimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Runtime: {value}'**
  String discoveryRuntimeLabel(String value);

  /// No description provided for @discoveryRuntimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String discoveryRuntimeMinutes(int minutes);

  /// No description provided for @discoveryGenresLabel.
  ///
  /// In en, this message translates to:
  /// **'Genres: {value}'**
  String discoveryGenresLabel(String value);

  /// No description provided for @discoveryCommunityRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Community rating: {value}'**
  String discoveryCommunityRatingLabel(String value);

  /// No description provided for @discoveryCriticRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Critic rating: {value}'**
  String discoveryCriticRatingLabel(String value);

  /// No description provided for @discoveryContentRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Content rating: {value}'**
  String discoveryContentRatingLabel(String value);

  /// No description provided for @discoveryStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {value}'**
  String discoveryStatusLabel(String value);

  /// No description provided for @discoveryCastLabel.
  ///
  /// In en, this message translates to:
  /// **'Featured cast: {value}'**
  String discoveryCastLabel(String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
