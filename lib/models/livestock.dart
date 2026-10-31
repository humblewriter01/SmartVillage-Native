/// Livestock & poultry domain models.
///
/// Mirrors `src/services/livestockService.ts`
/// (`LivestockAnimal`, `SymptomWeight`, `LivestockDisease`,
/// `DifferentialMatch`, `LivestockCheckResult`).
library;

class Animal {
  const Animal({
    required this.id,
    required this.name,
    required this.hausaName,
    required this.emoji,
    required this.commonSymptoms,
    required this.commonSymptomsHausa,
  });

  final String id;
  final String name;
  final String hausaName;
  final String emoji;

  /// Symptom strings are the *canonical English* keys used by the scoring
  /// engine; the Hausa list is index-aligned for display only.
  final List<String> commonSymptoms;
  final List<String> commonSymptomsHausa;

  String displayName(bool hausa) => hausa ? hausaName : name;

  /// Localised label for the symptom at [index] of [commonSymptoms].
  String symptomLabel(int index, bool hausa) {
    if (!hausa) return commonSymptoms[index];
    if (index < commonSymptomsHausa.length) return commonSymptomsHausa[index];
    return commonSymptoms[index];
  }
}

/// A symptom coupled with its diagnostic weight.
///
/// * 3 = hallmark / pathognomonic
/// * 2 = characteristic / secondary
/// * 1 = generic / systemic
class SymptomWeight {
  const SymptomWeight({required this.symptom, required this.weight});

  final String symptom;
  final int weight;
}

class AnimalDisease {
  const AnimalDisease({
    required this.id,
    required this.animalId,
    required this.name,
    required this.hausaName,
    required this.keySymptoms,
    required this.weightedSymptoms,
    required this.causes,
    required this.causesHausa,
    required this.treatment,
    required this.treatmentHausa,
    required this.prevention,
    required this.preventionHausa,
    required this.isUrgentContagious,
  });

  final String id;
  final String animalId;
  final String name;
  final String hausaName;
  final List<String> keySymptoms;
  final List<SymptomWeight> weightedSymptoms;
  final String causes;
  final String causesHausa;
  final String treatment;
  final String treatmentHausa;
  final String prevention;
  final String preventionHausa;
  final bool isUrgentContagious;

  String displayName(bool hausa) => hausa ? hausaName : name;
  String localizedCauses(bool hausa) => hausa ? causesHausa : causes;
  String localizedTreatment(bool hausa) => hausa ? treatmentHausa : treatment;
  String localizedPrevention(bool hausa) => hausa ? preventionHausa : prevention;

  /// The disease's symptoms as one readable line.
  ///
  /// Unlike crops and health conditions there is no `symptomsHausa` string:
  /// the source dataset never translated disease symptoms separately. Every
  /// entry of [keySymptoms] is one of [animal]'s [Animal.commonSymptoms], which
  /// *are* bilingual, so Hausa is resolved by position through
  /// [Animal.symptomLabel] instead of inventing translations.
  String localizedSymptoms(Animal animal, bool hausa) => keySymptoms
      .map((String symptom) {
        final int index = animal.commonSymptoms.indexOf(symptom);
        return index < 0 ? symptom : animal.symptomLabel(index, hausa);
      })
      .join(', ');
}

enum MatchStrength { strong, moderate, weak }

class DifferentialMatch {
  const DifferentialMatch({
    required this.disease,
    required this.score,
    required this.matchedSymptoms,
    required this.matchStrength,
  });

  final AnimalDisease disease;
  final int score;
  final List<String> matchedSymptoms;
  final MatchStrength matchStrength;
}

class LivestockCheckResult {
  const LivestockCheckResult({
    required this.animal,
    required this.hasMatch,
    required this.likelyDisease,
    required this.differentials,
    required this.confidence,
    required this.matchedSymptoms,
    this.noMatchMessageEn,
    this.noMatchMessageHa,
  });

  final Animal animal;
  final bool hasMatch;
  final AnimalDisease? likelyDisease;
  final List<DifferentialMatch> differentials;
  final double confidence;
  final List<String> matchedSymptoms;
  final String? noMatchMessageEn;
  final String? noMatchMessageHa;
}
