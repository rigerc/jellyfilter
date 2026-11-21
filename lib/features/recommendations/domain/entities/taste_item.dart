import 'dart:collection';

enum TasteRole { director, actor }

/// Someone who made or starred in a movie.
final class TastePerson {
  const TastePerson({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final TasteRole role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TastePerson &&
          other.id == id &&
          other.name == name &&
          other.role == role;

  @override
  int get hashCode => Object.hash(id, name, role);
}

/// A movie reduced to the traits and watch data that shape taste.
final class TasteItem {
  TasteItem({
    required this.id,
    required this.name,
    Iterable<String> genres = const <String>[],
    Iterable<String> studios = const <String>[],
    Iterable<String> tags = const <String>[],
    Iterable<TastePerson> people = const <TastePerson>[],
    this.year,
    this.communityRating,
    this.played = false,
    this.playCount = 0,
    this.favorite = false,
    this.likes,
    this.rating,
    this.lastPlayed,
  }) : genres = List<String>.unmodifiable(genres),
       studios = List<String>.unmodifiable(studios),
       tags = List<String>.unmodifiable(tags),
       people = List<TastePerson>.unmodifiable(people);

  final String id;
  final String name;
  final List<String> genres;

  /// Studios in server order; the first is the primary studio.
  final List<String> studios;
  final List<String> tags;

  /// Directors and actors in billing order. Empty when not fetched.
  final List<TastePerson> people;
  final int? year;
  final double? communityRating;
  final bool played;
  final int playCount;
  final bool favorite;
  final bool? likes;

  /// The user's rating on Jellyfin's 0–10 scale; 0 or null means unrated.
  final double? rating;
  final DateTime? lastPlayed;

  bool get _rated => (rating ?? 0) > 0;

  /// Whether Jellyfin holds any sign of the user's opinion on this movie.
  bool get hasInteraction =>
      played || playCount > 0 || favorite || likes != null || _rated;

  /// Seen or already judged, so it is not worth recommending.
  bool get isSettled => played || _rated || likes == false;

  /// This item marked as watched, with history gathered elsewhere such as
  /// the played episodes of a series. A started series is already known to
  /// the user, so it is settled like a watched movie.
  TasteItem withWatchHistory({required int playCount, DateTime? lastPlayed}) =>
      TasteItem(
        id: id,
        name: name,
        genres: genres,
        studios: studios,
        tags: tags,
        people: people,
        year: year,
        communityRating: communityRating,
        played: true,
        playCount: playCount,
        favorite: favorite,
        likes: likes,
        rating: rating,
        lastPlayed: lastPlayed,
      );

  TasteItem withPeople(Iterable<TastePerson> value) => TasteItem(
    id: id,
    name: name,
    genres: genres,
    studios: studios,
    tags: tags,
    people: value,
    year: year,
    communityRating: communityRating,
    played: played,
    playCount: playCount,
    favorite: favorite,
    likes: likes,
    rating: rating,
    lastPlayed: lastPlayed,
  );
}

/// Choices made inside Jellyfilter that hint at the user's taste.
final class LocalTasteChoices {
  LocalTasteChoices({
    Set<String> likedIds = const <String>{},
    Set<String> rejectedIds = const <String>{},
    Set<String> shortlistedIds = const <String>{},
  }) : likedIds = UnmodifiableSetView<String>(likedIds),
       rejectedIds = UnmodifiableSetView<String>(rejectedIds),
       shortlistedIds = UnmodifiableSetView<String>(shortlistedIds);

  static final none = LocalTasteChoices();

  /// A swipe right or a shortlist save: interest, but not proof of enjoyment.
  static const interestWeight = 0.75;

  /// Both a swipe right and a shortlist save.
  static const strongInterestWeight = 1.0;

  /// A swipe left often means "not tonight", so it counts less than a
  /// Jellyfin dislike.
  static const rejectionWeight = -0.5;

  final Set<String> likedIds;
  final Set<String> rejectedIds;
  final Set<String> shortlistedIds;

  Set<String> get allIds => <String>{
    ...likedIds,
    ...rejectedIds,
    ...shortlistedIds,
  };

  /// The weight these choices give [id], or null when there are none.
  double? weightOf(String id) {
    final liked = likedIds.contains(id);
    final shortlisted = shortlistedIds.contains(id);
    final rejected = rejectedIds.contains(id);
    if (!liked && !shortlisted && !rejected) {
      return null;
    }
    final interest = liked && shortlisted
        ? strongInterestWeight
        : liked || shortlisted
        ? interestWeight
        : 0.0;
    return interest + (rejected ? rejectionWeight : 0.0);
  }

  bool sameAs(LocalTasteChoices other) =>
      _sameSet(likedIds, other.likedIds) &&
      _sameSet(rejectedIds, other.rejectedIds) &&
      _sameSet(shortlistedIds, other.shortlistedIds);

  static bool _sameSet(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);
}
