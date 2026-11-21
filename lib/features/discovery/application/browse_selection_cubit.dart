import 'package:flutter_bloc/flutter_bloc.dart';

/// Titles picked in Browse for a bulk action, in the order they were picked.
/// Empty means Browse is not selecting.
final class BrowseSelectionCubit extends Cubit<Set<String>> {
  BrowseSelectionCubit() : super(const <String>{});

  bool get isSelecting => state.isNotEmpty;

  /// Adds [id] when it is not picked and removes it when it is. Removing the
  /// last title ends the selection.
  void toggle(String id) {
    final next = <String>{...state};
    if (!next.remove(id)) {
      next.add(id);
    }
    emit(Set<String>.unmodifiable(next));
  }

  void selectAll(Iterable<String> ids) =>
      emit(Set<String>.unmodifiable(<String>{...state, ...ids}));

  void clear() {
    if (state.isNotEmpty) {
      emit(const <String>{});
    }
  }

  /// Drops picks that are no longer shown, such as after a filter change.
  void retain(Iterable<String> visibleIds) {
    final visible = visibleIds.toSet();
    if (state.every(visible.contains)) {
      return;
    }
    emit(Set<String>.unmodifiable(state.where(visible.contains).toSet()));
  }
}
