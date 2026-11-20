import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';

/// Reads the watch history and people data that recommendations learn from.
///
/// Every method throws a `TasteFailure` when the server cannot answer.
abstract interface class TasteRepository {
  /// Movies the user has played, favorited, liked, or disliked.
  Future<List<TasteItem>> loadHistory();

  /// The movies with [ids]. With [withPeople], each carries its directors
  /// and actors in billing order.
  Future<List<TasteItem>> loadItems(Set<String> ids, {bool withPeople = false});

  /// Ids of movies where the person with [personId] has [role].
  Future<Set<String>> loadMovieIdsWithPerson(String personId, TasteRole role);
}
