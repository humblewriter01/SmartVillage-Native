/// Knowledge-base models.
///
/// Mirrors `src/data/knowledgeData.ts` (`KnowledgeItem`, `DiseaseInfo`).
library;

enum KnowledgeCategory { crop, health, farm, water, poultry }

class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.category,
    required this.title,
    required this.titleEn,
    required this.titleHa,
    required this.body,
    required this.bodyHa,
    required this.source,
  });

  final String id;
  final KnowledgeCategory category;
  final String title;
  final String titleEn;
  final String titleHa;
  final String body;
  final String bodyHa;
  final String source;

  String displayTitle(bool hausa) => hausa && titleHa.isNotEmpty ? titleHa : title;
  String displayBody(bool hausa) => hausa && bodyHa.isNotEmpty ? bodyHa : body;
}

class TreatmentLevels {
  const TreatmentLevels({
    required this.mild,
    required this.moderate,
    required this.severe,
  });

  final String mild;
  final String moderate;
  final String severe;
}

class DiseaseInfo {
  const DiseaseInfo({
    required this.diseaseId,
    required this.commonName,
    required this.hausaName,
    required this.pathogenType,
    required this.affectedCrops,
    required this.causes,
    required this.symptoms,
    required this.treatments,
    required this.organicAlternative,
    required this.preventionTips,
  });

  final String diseaseId;
  final String commonName;
  final String hausaName;
  final String pathogenType;
  final List<String> affectedCrops;
  final String causes;
  final String symptoms;
  final TreatmentLevels treatments;
  final String organicAlternative;
  final List<String> preventionTips;

  String displayName(bool hausa) =>
      hausa && hausaName.isNotEmpty ? hausaName : commonName;
}
