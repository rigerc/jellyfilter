import 'dart:collection';

/// What kind of trait made a title a good match.
enum AffinityReasonKind { genre, person, studio, tag }

/// One trait a recommended title shares with what the user enjoys.
final class AffinityReason {
  const AffinityReason({required this.kind, required this.label});

  final AffinityReasonKind kind;

  /// The trait as it should be shown, such as a genre or a person's name.
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AffinityReason && other.kind == kind && other.label == label;

  @override
  int get hashCode => Object.hash(kind, label);
}

/// A personal ranking of catalog titles, best match first.
///
/// Titles that are not ranked (already watched, rated, or turned down) keep
/// their original relative order after every ranked title.
final class MediaAffinity {
  MediaAffinity({
    Iterable<String> rankedIds = const <String>[],
    Map<String, List<AffinityReason>> reasons =
        const <String, List<AffinityReason>>{},
    this.hasTaste = false,
  }) : rankedIds = List<String>.unmodifiable(rankedIds),
       _reasons = Map<String, List<AffinityReason>>.unmodifiable(
         reasons.map(
           (id, values) =>
               MapEntry(id, List<AffinityReason>.unmodifiable(values)),
         ),
       );

  static final empty = MediaAffinity();

  /// Ranked title ids, best match first.
  final List<String> rankedIds;
  final Map<String, List<AffinityReason>> _reasons;

  /// Whether the ranking reflects the user's taste rather than a fallback
  /// to community ratings.
  final bool hasTaste;

  late final Map<String, int> _ranks = HashMap<String, int>.of(<String, int>{
    for (final (index, id) in rankedIds.indexed) id: index,
  });

  bool get isEmpty => rankedIds.isEmpty;

  /// Zero-based rank of [id], or null when the title is not ranked.
  int? rankOf(String id) => _ranks[id];

  List<AffinityReason> reasonsFor(String id) =>
      _reasons[id] ?? const <AffinityReason>[];

  /// Orders [items] by rank. The sort is stable, so unranked items keep
  /// their incoming order after the ranked ones.
  List<T> sort<T>(List<T> items, String Function(T item) idOf) {
    if (isEmpty) {
      return items;
    }
    final indexed = items.indexed.toList(growable: false)
      ..sort((left, right) {
        final leftRank = _ranks[idOf(left.$2)];
        final rightRank = _ranks[idOf(right.$2)];
        if (leftRank != null && rightRank != null) {
          return leftRank.compareTo(rightRank);
        }
        if (leftRank != null) {
          return -1;
        }
        if (rightRank != null) {
          return 1;
        }
        return left.$1.compareTo(right.$1);
      });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }
}
