import 'dart:async';

import 'package:jellyfilter/features/favorites/domain/repositories/favorite_repository.dart';

final class FavoriteRepositoryInvocation {
  const FavoriteRepositoryInvocation({
    required this.itemId,
    required this.isFavorite,
  });

  final String itemId;
  final bool isFavorite;
}

final class FavoriteRepositoryFake implements FavoriteRepository {
  final List<FavoriteRepositoryInvocation> invocations =
      <FavoriteRepositoryInvocation>[];
  final List<Completer<FavoriteUpdateResult>> completions =
      <Completer<FavoriteUpdateResult>>[];

  @override
  Future<FavoriteUpdateResult> setFavorite({
    required String itemId,
    required bool isFavorite,
  }) {
    invocations.add(
      FavoriteRepositoryInvocation(itemId: itemId, isFavorite: isFavorite),
    );
    final completion = Completer<FavoriteUpdateResult>();
    completions.add(completion);
    return completion.future;
  }
}

/// In-memory playlists and tags, with switchable failures.
final class LibraryActionsFake implements LibraryActionsRepository {
  LibraryActionsFake({
    List<LibraryPlaylist> playlists = const <LibraryPlaylist>[],
    Map<String, List<String>> members = const <String, List<String>>{},
    List<String> tags = const <String>[],
  }) : playlists = List<LibraryPlaylist>.of(playlists),
       members = <String, List<String>>{
         for (final entry in members.entries)
           entry.key: List<String>.of(entry.value),
       },
       tags = List<String>.of(tags);

  final List<LibraryPlaylist> playlists;
  final Map<String, List<String>> members;
  List<String> tags;
  LibraryActionFailure? tagFailure;
  final List<List<String>> savedTags = <List<String>>[];

  @override
  Future<LibraryActionResult<List<LibraryPlaylist>>> loadPlaylists() async =>
      LibraryActionResult<List<LibraryPlaylist>>.success(
        List<LibraryPlaylist>.of(playlists),
      );

  @override
  Future<LibraryActionResult<bool>> addToPlaylist({
    required String playlistId,
    required String itemId,
  }) async {
    final list = members.putIfAbsent(playlistId, () => <String>[]);
    if (list.contains(itemId)) {
      return const LibraryActionResult<bool>.success(false);
    }
    list.add(itemId);
    return const LibraryActionResult<bool>.success(true);
  }

  @override
  Future<LibraryActionResult<LibraryPlaylist>> createPlaylist({
    required String name,
    required String itemId,
  }) async {
    final playlist = LibraryPlaylist(id: 'new-${playlists.length}', name: name);
    playlists.add(playlist);
    members[playlist.id] = <String>[itemId];
    return LibraryActionResult<LibraryPlaylist>.success(playlist);
  }

  @override
  Future<LibraryActionResult<List<String>>> loadTags(String itemId) async =>
      LibraryActionResult<List<String>>.success(List<String>.of(tags));

  @override
  Future<LibraryActionResult<List<String>>> setTags({
    required String itemId,
    required List<String> tags,
  }) async {
    final failure = tagFailure;
    if (failure != null) {
      return LibraryActionResult<List<String>>.failure(failure);
    }
    savedTags.add(List<String>.of(tags));
    this.tags = List<String>.of(tags);
    return LibraryActionResult<List<String>>.success(this.tags);
  }
}
