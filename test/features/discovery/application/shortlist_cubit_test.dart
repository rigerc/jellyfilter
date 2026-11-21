import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfilter/core/media/entities/catalog_candidate.dart';
import 'package:jellyfilter/features/discovery/application/shortlist_cubit.dart';
import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';

import '../../../shared/fake_discovery_store.dart';

void main() {
  group('ShortlistCubit bulk edits', () {
    test(
      'should add only unsaved movies, newest first, in one write',
      () async {
        final store = _CountingStore([(id: 'b', title: 'B')]);
        final cubit = _cubit(store);

        final saved = await cubit.addAll([
          _movie('a'),
          _movie('b'),
          _movie('c'),
        ]);

        expect(saved, isTrue);
        expect(store.writes, 1);
        expect(cubit.state.entries.map((entry) => entry.id), ['a', 'c', 'b']);
        await cubit.close();
      },
    );

    test('should remove several movies in one write', () async {
      final store = _CountingStore([
        (id: 'a', title: 'A'),
        (id: 'b', title: 'B'),
        (id: 'c', title: 'C'),
      ]);
      final cubit = _cubit(store);

      final saved = await cubit.removeAll({'a', 'c', 'missing'});

      expect(saved, isTrue);
      expect(store.writes, 1);
      expect(cubit.state.entries.map((entry) => entry.id), ['b']);
      await cubit.close();
    });

    test('should skip the write when nothing changes', () async {
      final store = _CountingStore([(id: 'a', title: 'A')]);
      final cubit = _cubit(store);

      expect(await cubit.addAll([_movie('a')]), isTrue);
      expect(await cubit.removeAll({'missing'}), isTrue);

      expect(store.writes, 0);
      await cubit.close();
    });
  });
}

ShortlistCubit _cubit(ShortlistStore store) => ShortlistCubit(
  store: store,
  loadMovies: (_) async => const <CatalogCandidate>[],
  selector: FakeDiscoverySelector(null),
);

CatalogCandidate _movie(String id) => CatalogCandidate(
  id: id,
  name: id.toUpperCase(),
  mediaType: CatalogMediaType.movie,
  poster: const CatalogImage.fallback(),
  backdrop: const CatalogImage.fallback(),
);

final class _CountingStore implements ShortlistStore {
  _CountingStore(this.entries);

  List<ShortlistEntry> entries;
  int writes = 0;

  @override
  Future<List<ShortlistEntry>> read() async => entries;

  @override
  Future<void> write(List<ShortlistEntry> entries) async {
    writes++;
    this.entries = entries;
  }
}
