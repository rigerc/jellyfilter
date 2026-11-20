typedef ShortlistEntry = ({String id, String title});

abstract interface class ShortlistStore {
  Future<List<ShortlistEntry>> read();
  Future<void> write(List<ShortlistEntry> entries);
}
