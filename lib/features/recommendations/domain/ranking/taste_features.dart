import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_profile.dart';

/// Turns a movie into comparable traits and says how much each kind counts.
abstract final class TasteFeatures {
  /// Only the top-billed actors say much about a movie.
  static const maxActors = 5;

  /// Some libraries carry dozens of keyword tags; a few are enough.
  static const maxTags = 10;

  /// Candidate people are matched through the profile's strongest people
  /// only, so every candidate counts this many person slots when its score
  /// is normalized: one director and the top-billed actors.
  static const personSlots = 1 + maxActors;

  static List<TasteFeature> of(TasteItem item) {
    final features = <String, TasteFeature>{};
    void add(TasteFeatureKind kind, String prefix, String value, String label) {
      final normalized = normalize(value);
      if (normalized.isEmpty) {
        return;
      }
      final key = '$prefix:$normalized';
      features.putIfAbsent(
        key,
        () => TasteFeature(key: key, kind: kind, label: label.trim()),
      );
    }

    for (final genre in item.genres) {
      add(TasteFeatureKind.genre, 'g', genre, genre);
    }
    for (final studio in item.studios) {
      add(TasteFeatureKind.studio, 's', studio, studio);
    }
    for (final tag in item.tags.take(maxTags)) {
      add(TasteFeatureKind.tag, 't', tag, tag);
    }
    final year = item.year;
    if (year != null && year > 0) {
      final decade = year ~/ 10 * 10;
      add(TasteFeatureKind.decade, 'd', '$decade', '$decade');
    }
    final directors = item.people.where(
      (person) => person.role == TasteRole.director,
    );
    final actors = item.people
        .where((person) => person.role == TasteRole.actor)
        .take(maxActors);
    for (final person in <TastePerson>[...directors, ...actors]) {
      final feature = personFeature(person);
      if (feature != null) {
        features.putIfAbsent(feature.key, () => feature);
      }
    }
    return features.values.toList(growable: false);
  }

  static TasteFeature? personFeature(TastePerson person) {
    final id = person.id.trim();
    if (id.isEmpty) {
      return null;
    }
    return TasteFeature(
      key: personKey(person.role, id),
      kind: person.role == TasteRole.director
          ? TasteFeatureKind.director
          : TasteFeatureKind.actor,
      label: person.name.trim(),
    );
  }

  static String personKey(TasteRole role, String id) =>
      role == TasteRole.director ? 'pd:$id' : 'pa:$id';

  /// How much one evidence movie adds to the profile, per trait kind.
  static double profileFactor(TasteFeatureKind kind) => switch (kind) {
    TasteFeatureKind.genre => 1.0,
    TasteFeatureKind.studio => 0.5,
    TasteFeatureKind.tag => 0.5,
    TasteFeatureKind.decade => 0.5,
    TasteFeatureKind.director => 1.2,
    TasteFeatureKind.actor => 0.8,
  };

  /// How much a matching profile weight adds to a candidate's score.
  static double scoreFactor(TasteFeatureKind kind) => switch (kind) {
    TasteFeatureKind.decade => 0.3,
    TasteFeatureKind.director => 1.2,
    _ => 1.0,
  };

  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(_whitespace, ' ');

  static final RegExp _whitespace = RegExp(r'\s+');
}
