import 'package:jellyfilter/features/recommendations/domain/ranking/recommendation_scorer.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/taste_features.dart';

/// Orders scored titles best first while keeping one studio from crowding
/// the top of the list.
abstract final class DiversitySelector {
  static const defaultWindow = 60;
  static const defaultCapPerStudio = 3;

  /// Sorts [scored] by score, then fills the first [window] places with at
  /// most [capPerStudio] titles per primary studio (0 disables the cap).
  /// Skipped titles backfill the window if it runs short; everything else
  /// follows by score. Titles without a studio are never capped.
  static List<ScoredTitle> order(
    Iterable<ScoredTitle> scored, {
    int window = defaultWindow,
    int capPerStudio = defaultCapPerStudio,
  }) {
    final sorted = scored.toList()..sort(_compare);
    if (window <= 0 || capPerStudio <= 0) {
      return sorted;
    }
    final head = <ScoredTitle>[];
    final skipped = <ScoredTitle>[];
    final perStudio = <String, int>{};
    var index = 0;
    for (; index < sorted.length && head.length < window; index++) {
      final title = sorted[index];
      final studio = title.item.studios
          .map(TasteFeatures.normalize)
          .where((value) => value.isNotEmpty)
          .firstOrNull;
      if (studio == null) {
        head.add(title);
        continue;
      }
      final count = perStudio[studio] ?? 0;
      if (count >= capPerStudio) {
        skipped.add(title);
        continue;
      }
      perStudio[studio] = count + 1;
      head.add(title);
    }
    final rest = <ScoredTitle>[...skipped, ...sorted.skip(index)]
      ..sort(_compare);
    final backfill = window - head.length;
    if (backfill > 0) {
      head.addAll(rest.take(backfill));
      return <ScoredTitle>[...head, ...rest.skip(backfill)];
    }
    return <ScoredTitle>[...head, ...rest];
  }

  static int _compare(ScoredTitle left, ScoredTitle right) {
    final byScore = right.score.compareTo(left.score);
    if (byScore != 0) {
      return byScore;
    }
    final byRating = (right.item.communityRating ?? 0).compareTo(
      left.item.communityRating ?? 0,
    );
    if (byRating != 0) {
      return byRating;
    }
    final byName = left.item.name.toLowerCase().compareTo(
      right.item.name.toLowerCase(),
    );
    return byName != 0 ? byName : left.item.id.compareTo(right.item.id);
  }
}
