import 'dart:convert';

import 'package:jellyfilter/features/discovery/domain/repositories/shortlist_store.dart';
import 'package:jellyfilter/features/persistence/data/shared_preferences_discovery_store.dart';

final class SharedPreferencesShortlistStore implements ShortlistStore {
  SharedPreferencesShortlistStore(this.preferences, String scope)
    : _key = '${preferences.keyFor(scope)}.shortlist';

  final DiscoveryBlobPreferences preferences;
  final String _key;

  @override
  Future<List<ShortlistEntry>> read() async {
    final stored = await preferences.read(_key);
    if (stored == null) {
      return const <ShortlistEntry>[];
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      return const <ShortlistEntry>[];
    }
    if (decoded is! List) {
      return const <ShortlistEntry>[];
    }
    final seen = <String>{};
    return <ShortlistEntry>[
      for (final value in decoded)
        if (value case {
          'id': final String id,
          'title': final String title,
        } when id.trim().isNotEmpty && title.trim().isNotEmpty && seen.add(id))
          (id: id, title: title),
    ];
  }

  @override
  Future<void> write(List<ShortlistEntry> entries) => preferences.write(
    _key,
    jsonEncode([
      for (final entry in entries) {'id': entry.id, 'title': entry.title},
    ]),
  );
}
