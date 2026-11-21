import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/features/discovery/application/browse_selection_cubit.dart';

void main() {
  group('BrowseSelectionCubit', () {
    test('should start, grow, and end the selection by toggling', () async {
      final selection = BrowseSelectionCubit();
      expect(selection.isSelecting, isFalse);

      selection.toggle('a');
      selection.toggle('b');
      expect(selection.state, {'a', 'b'});
      expect(selection.isSelecting, isTrue);

      selection.toggle('a');
      selection.toggle('b');
      expect(selection.isSelecting, isFalse);
      await selection.close();
    });

    test('should select all, keep only visible picks, and clear', () async {
      final selection = BrowseSelectionCubit()
        ..toggle('a')
        ..selectAll(['a', 'b', 'c']);
      expect(selection.state, {'a', 'b', 'c'});

      selection.retain(['b', 'c', 'd']);
      expect(selection.state, {'b', 'c'});

      final unchanged = selection.state;
      selection.retain(['b', 'c']);
      expect(selection.state, same(unchanged));

      selection.clear();
      expect(selection.state, isEmpty);
      await selection.close();
    });
  });
}
