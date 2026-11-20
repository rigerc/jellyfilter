import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/failures/taste_failure.dart';
import 'package:jellyfilter/features/recommendations/domain/repositories/taste_repository.dart';

/// In-memory taste data that records every request.
final class FakeTasteRepository implements TasteRepository {
  FakeTasteRepository({
    this.history = const <TasteItem>[],
    this.items = const <String, TasteItem>{},
    this.personMovies = const <String, Set<String>>{},
    this.failHistory = false,
  });

  List<TasteItem> history;
  Map<String, TasteItem> items;

  /// Movie ids keyed by person id.
  Map<String, Set<String>> personMovies;
  bool failHistory;

  int historyLoads = 0;
  final List<Set<String>> itemRequests = <Set<String>>[];
  final List<Set<String>> peopleRequests = <Set<String>>[];
  final List<String> personRequests = <String>[];

  @override
  Future<List<TasteItem>> loadHistory() async {
    historyLoads++;
    if (failHistory) {
      throw const TasteFailure(TasteFailureReason.unreachable);
    }
    return history;
  }

  @override
  Future<List<TasteItem>> loadItems(
    Set<String> ids, {
    bool withPeople = false,
  }) async {
    (withPeople ? peopleRequests : itemRequests).add(Set<String>.of(ids));
    return <TasteItem>[for (final id in ids) ?items[id]];
  }

  @override
  Future<Set<String>> loadMovieIdsWithPerson(
    String personId,
    TasteRole role,
  ) async {
    personRequests.add(personId);
    return personMovies[personId] ?? const <String>{};
  }
}
