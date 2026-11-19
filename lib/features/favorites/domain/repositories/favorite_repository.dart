import 'package:jellyfin_picker/features/favorites/domain/failures/favorite_failure.dart';

sealed class FavoriteUpdateResult {
  const FavoriteUpdateResult();
}

final class FavoriteUpdated extends FavoriteUpdateResult {
  const FavoriteUpdated({required this.itemId, required this.isFavorite});

  final String itemId;
  final bool isFavorite;
}

final class FavoriteUpdateFailed extends FavoriteUpdateResult {
  const FavoriteUpdateFailed(this.failure);

  final FavoriteFailure failure;
}

abstract interface class FavoriteRepository {
  Future<FavoriteUpdateResult> setFavorite({
    required String itemId,
    required bool isFavorite,
  });
}

/// A user playlist that movies can be added to.
final class LibraryPlaylist {
  const LibraryPlaylist({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is LibraryPlaylist && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Why a playlist or tag action did not complete.
enum LibraryActionFailure {
  /// The account may not do this (tag edits need a Jellyfin administrator).
  notAllowed,
  expiredSession,
  unreachable,
  notFound,
  server,
  incompatible,
}

final class LibraryActionResult<T> {
  const LibraryActionResult.success(T this.value) : failure = null;

  const LibraryActionResult.failure(LibraryActionFailure this.failure)
    : value = null;

  final T? value;
  final LibraryActionFailure? failure;
}

/// Playlist and tag changes for one title, written to Jellyfin.
abstract interface class LibraryActionsRepository {
  Future<LibraryActionResult<List<LibraryPlaylist>>> loadPlaylists();

  /// Adds [itemId]; succeeds with `false` when it was already in the list.
  Future<LibraryActionResult<bool>> addToPlaylist({
    required String playlistId,
    required String itemId,
  });

  Future<LibraryActionResult<LibraryPlaylist>> createPlaylist({
    required String name,
    required String itemId,
  });

  Future<LibraryActionResult<List<String>>> loadTags(String itemId);

  /// Replaces the item's tags and returns what Jellyfin now holds.
  Future<LibraryActionResult<List<String>>> setTags({
    required String itemId,
    required List<String> tags,
  });
}
