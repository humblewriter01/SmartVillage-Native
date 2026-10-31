/// Crop & disease domain models.
///
/// Mirrors `src/data/cropReferenceData.ts` from the React blueprint
/// (`CropReference` / `CropDiseaseReference`).
library;

class Disease {
  const Disease({
    required this.id,
    required this.name,
    required this.hausaName,
    required this.affectedParts,
    required this.causes,
    required this.causesHausa,
    required this.symptoms,
    required this.symptomsHausa,
    required this.treatment,
    required this.treatmentHausa,
    required this.prevention,
    required this.preventionHausa,
    required this.leafColor,
    required this.spotColor,
  });

  final String id;
  final String name;
  final String hausaName;
  final List<String> affectedParts;
  final String causes;
  final String causesHausa;
  final String symptoms;
  final String symptomsHausa;
  final String treatment;
  final String treatmentHausa;
  final String prevention;
  final String preventionHausa;

  /// ARGB colour used by the offline vector leaf illustration.
  final int leafColor;

  /// ARGB colour of the diagnostic spots drawn on the leaf illustration.
  final int spotColor;

  /// A "healthy" entry always ends with `_healthy` in the reference dataset.
  bool get isHealthy =>
      id.endsWith('_healthy') || name.toLowerCase().contains('healthy');

  String displayName(bool hausa) => hausa ? hausaName : name;
  String localizedCauses(bool hausa) => hausa ? causesHausa : causes;
  String localizedSymptoms(bool hausa) => hausa ? symptomsHausa : symptoms;
  String localizedTreatment(bool hausa) => hausa ? treatmentHausa : treatment;
  String localizedPrevention(bool hausa) => hausa ? preventionHausa : prevention;
}

class Crop {
  const Crop({
    required this.id,
    required this.crop,
    required this.hausaName,
    required this.emoji,
    required this.description,
    required this.descriptionHausa,
    required this.leafColor,
    required this.diseases,
  });

  final String id;
  final String crop;
  final String hausaName;
  final String emoji;
  final String description;
  final String descriptionHausa;
  final int leafColor;
  final List<Disease> diseases;

  String displayName(bool hausa) => hausa ? hausaName : crop;
  String localizedDescription(bool hausa) =>
      hausa ? descriptionHausa : description;

  Disease? diseaseById(String diseaseId) {
    for (final disease in diseases) {
      if (disease.id == diseaseId) return disease;
    }
    return null;
  }

  Disease? get healthyDisease {
    for (final disease in diseases) {
      if (disease.isHealthy) return disease;
    }
    return null;
  }
}
