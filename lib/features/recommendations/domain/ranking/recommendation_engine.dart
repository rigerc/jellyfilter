import 'package:jellyfilter/core/media/entities/media_affinity.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_item.dart';
import 'package:jellyfilter/features/recommendations/domain/entities/taste_profile.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/diversity_selector.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/recommendation_scorer.dart';
import 'package:jellyfilter/features/recommendations/domain/ranking/taste_profile_builder.dart';

/// A person in the profile, used to look up which candidates they are in.
typedef TastePersonRef = ({String id, TasteRole role});

/// The outcome of one ranking pass.
final class RankingResult {
  RankingResult({
    required this.affinity,
    required this.signals,
    required this.profile,
  });

  final MediaAffinity affinity;
  final List<TasteSignal> signals;
  final TasteProfile profile;

  /// Evidence ids by how much they count, strongest first, so people can
  /// be fetched for the movies that matter most.
  List<String> strongestEvidenceIds(int limit) =>
      (List<TasteSignal>.of(signals)..sort(
            (left, right) => right.weight.abs().compareTo(left.weight.abs()),
          ))
          .take(limit)
          .map((signal) => signal.item.id)
          .toList(growable: false);

  /// Profile people by the size of their weight, liked or avoided.
  List<TastePersonRef> strongestPeople(int limit) {
    final people =
        profile.features.values
            .where((feature) => feature.personId != null)
            .where((feature) => profile.weightOf(feature.key) != 0)
            .toList()
          ..sort(
            (left, right) => profile
                .weightOf(right.key)
                .abs()
                .compareTo(profile.weightOf(left.key).abs()),
          );
    return <TastePersonRef>[
      for (final feature in people.take(limit))
        if ((feature.personId, feature.role) case (final id?, final role?))
          (id: id, role: role),
    ];
  }
}

/// Ranks candidate movies against what the user watched and chose.
abstract final class RecommendationEngine {
  /// Ranks [candidates] using [evidence], every movie whose watch data or
  /// local choices are known. [personMovies] maps a person key (see
  /// `TasteFeatures.personKey`) to the movies that person is in.
  ///
  /// Watched, rated, disliked, and rejected movies are left unranked.
  static RankingResult rank({
    required Iterable<TasteItem> candidates,
    required Iterable<TasteItem> evidence,
    required LocalTasteChoices choices,
    required DateTime now,
    Map<String, Set<String>> personMovies = const <String, Set<String>>{},
  }) {
    final signals = TasteProfileBuilder.collect(evidence, choices, now);
    final profile = TasteProfileBuilder.build(signals);
    final hasTaste = profile.hasSignal;
    final ownSignals = <String, TasteSignal>{
      for (final signal in signals) signal.item.id: signal,
    };
    final peopleByMovie = <String, List<TasteFeature>>{};
    for (final MapEntry(key: key, value: movieIds) in personMovies.entries) {
      final feature = profile.features[key];
      if (feature == null) {
        continue;
      }
      for (final id in movieIds) {
        (peopleByMovie[id] ??= <TasteFeature>[]).add(feature);
      }
    }
    final seen = <String>{};
    final scored = <ScoredTitle>[
      for (final candidate in candidates)
        if (seen.add(candidate.id) &&
            !candidate.isSettled &&
            !choices.rejectedIds.contains(candidate.id))
          hasTaste
              ? RecommendationScorer.score(
                  candidate,
                  profile,
                  people: peopleByMovie[candidate.id] ?? const [],
                  own: ownSignals[candidate.id],
                )
              : RecommendationScorer.coldStart(candidate),
    ];
    final ordered = DiversitySelector.order(scored);
    return RankingResult(
      affinity: MediaAffinity(
        rankedIds: ordered.map((title) => title.item.id),
        reasons: <String, List<AffinityReason>>{
          for (final title in ordered)
            if (title.reasons.isNotEmpty)
              title.item.id: title.reasons
                  .map(_reason)
                  .whereType<AffinityReason>()
                  .toList(growable: false),
        },
        hasTaste: hasTaste,
      ),
      signals: signals,
      profile: profile,
    );
  }

  static AffinityReason? _reason(TasteFeature feature) {
    final kind = switch (feature.kind) {
      TasteFeatureKind.genre => AffinityReasonKind.genre,
      TasteFeatureKind.studio => AffinityReasonKind.studio,
      TasteFeatureKind.tag => AffinityReasonKind.tag,
      TasteFeatureKind.director ||
      TasteFeatureKind.actor => AffinityReasonKind.person,
      TasteFeatureKind.decade => null,
    };
    if (kind == null || feature.label.isEmpty) {
      return null;
    }
    return AffinityReason(kind: kind, label: feature.label);
  }
}
