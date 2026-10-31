import '../data/livestock_data.dart';
import '../models/livestock.dart';

/// Weighted-symptom livestock diagnosis.
///
/// Faithful port of `livestockService.diagnose()` from the React blueprint:
///
/// ```
/// coverage  = weightedMatched / totalDiseaseWeight
/// relevance = weightedMatched / totalSelectedWeight
/// score     = (0.5 * coverage + 0.5 * relevance) * 100  (+12 if a hallmark
///             symptom with weight 3 matched)
/// ```
///
/// The score is clamped to 15..100 and mapped to strong (>= 80),
/// moderate (>= 50) or weak. When nothing matches we deliberately return
/// `hasMatch: false` instead of inventing a diagnosis.
class LivestockService {
  const LivestockService._();

  static const List<String> _noMatchEn = <String>[
    'No matching disease found.',
    'Please select more symptoms or consult a local vet.',
  ];
  static const List<String> _noMatchHa = <String>[
    'Ba a sami cutar da ta dace ba.',
    'Don Allah zaɓi ƙarin alamomi ko tuntuɓi likitan dabbobi.',
  ];

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static List<Animal> get animals => livestockAnimals;

  static Animal? animal(String id) => animalById(id);

  static LivestockCheckResult? diagnose(
    String animalId,
    List<String> selectedSymptoms,
  ) {
    final animal = animalById(animalId);
    if (animal == null) return null;
    if (selectedSymptoms.isEmpty) return null;

    final diseases = diseasesForAnimal(animalId);
    if (diseases.isEmpty) return null;

    int symptomWeight(String symptom, AnimalDisease disease) {
      final normalized = _normalize(symptom);
      for (final weighted in disease.weightedSymptoms) {
        final target = _normalize(weighted.symptom);
        if (target.contains(normalized) || normalized.contains(target)) {
          return weighted.weight;
        }
      }
      return 1;
    }

    final differentials = <DifferentialMatch>[];

    for (final disease in diseases) {
      final matched = <String>[];
      var weightedMatched = 0;
      var hasHallmark = false;

      final totalDiseaseWeight = disease.weightedSymptoms
          .fold<int>(0, (sum, weighted) => sum + weighted.weight);

      for (final symptom in selectedSymptoms) {
        final normalized = _normalize(symptom);
        final isMatch = disease.keySymptoms.any((key) {
          final target = _normalize(key);
          return target.contains(normalized) || normalized.contains(target);
        });

        if (!isMatch) continue;
        matched.add(symptom);
        final weight = symptomWeight(symptom, disease);
        weightedMatched += weight;
        if (weight == 3) hasHallmark = true;
      }

      if (matched.isEmpty) continue;

      var totalSelectedWeight = 0;
      for (final symptom in selectedSymptoms) {
        totalSelectedWeight += symptomWeight(symptom, disease);
      }

      final coverage = weightedMatched / (totalDiseaseWeight < 1 ? 1 : totalDiseaseWeight);
      final relevance =
          weightedMatched / (totalSelectedWeight < 1 ? 1 : totalSelectedWeight);
      var baseScore = (0.5 * coverage + 0.5 * relevance) * 100;
      if (hasHallmark) baseScore += 12;

      final score = baseScore.round().clamp(15, 100);

      final strength = score >= 80
          ? MatchStrength.strong
          : score >= 50
              ? MatchStrength.moderate
              : MatchStrength.weak;

      differentials.add(
        DifferentialMatch(
          disease: disease,
          score: score,
          matchedSymptoms: matched,
          matchStrength: strength,
        ),
      );
    }

    differentials.sort((a, b) => b.score.compareTo(a.score));

    if (differentials.isEmpty) {
      return LivestockCheckResult(
        animal: animal,
        hasMatch: false,
        likelyDisease: null,
        differentials: const <DifferentialMatch>[],
        confidence: 0,
        matchedSymptoms: const <String>[],
        noMatchMessageEn: _noMatchEn.join(' '),
        noMatchMessageHa: _noMatchHa.join(' '),
      );
    }

    final top = differentials.first;
    return LivestockCheckResult(
      animal: animal,
      hasMatch: true,
      likelyDisease: top.disease,
      differentials: differentials.take(3).toList(growable: false),
      confidence: top.score / 100,
      matchedSymptoms: top.matchedSymptoms,
    );
  }

  /// Localised label for a canonical English symptom string.
  static String symptomLabel(String animalId, String symptom, bool hausa) {
    final animal = animalById(animalId);
    if (animal == null || !hausa) return symptom;
    final index = animal.commonSymptoms.indexOf(symptom);
    if (index < 0) return symptom;
    return animal.symptomLabel(index, true);
  }

  static String strengthLabel(MatchStrength strength, bool hausa) {
    switch (strength) {
      case MatchStrength.strong:
        return hausa ? 'Matsayi mai ƙarfi' : 'Strong match';
      case MatchStrength.moderate:
        return hausa ? 'Matsayi mai matsakaici' : 'Moderate match';
      case MatchStrength.weak:
        return hausa ? 'Matsayi mai rauni' : 'Weak match';
    }
  }
}
