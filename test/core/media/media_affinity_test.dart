import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/media/entities/media_affinity.dart';

void main() {
  test('should put ranked ids first and keep the rest in order', () {
    final affinity = MediaAffinity(rankedIds: const <String>['c', 'a']);
    expect(
      affinity.sort(const <String>['a', 'x', 'b', 'c', 'y'], (id) => id),
      <String>['c', 'a', 'x', 'b', 'y'],
    );
    expect(affinity.rankOf('a'), 1);
    expect(affinity.rankOf('x'), isNull);
  });

  test('should leave items untouched when nothing is ranked', () {
    final items = <String>['b', 'a'];
    expect(identical(MediaAffinity.empty.sort(items, (id) => id), items), true);
  });

  test('should expose reasons per title', () {
    final affinity = MediaAffinity(
      rankedIds: const <String>['a'],
      reasons: const <String, List<AffinityReason>>{
        'a': <AffinityReason>[
          AffinityReason(kind: AffinityReasonKind.studio, label: 'A24'),
        ],
      },
    );
    expect(affinity.reasonsFor('a').single.label, 'A24');
    expect(affinity.reasonsFor('b'), isEmpty);
  });
}
