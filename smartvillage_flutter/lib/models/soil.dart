/// Soil-health models.
///
/// Mirrors `src/services/soilService.ts`
/// (`CropSoilRequirement`, `SoilConditionAdvice`, `SoilRecord`).
library;

class CropSoilRequirement {
  const CropSoilRequirement({
    required this.cropId,
    required this.name,
    required this.hausaName,
    required this.emoji,
    required this.minPh,
    required this.optimalPhMin,
    required this.optimalPhMax,
    required this.maxPh,
    required this.optimalMoistureMin,
    required this.optimalMoistureMax,
    required this.criticalNotesEn,
    required this.criticalNotesHa,
  });

  final String cropId;
  final String name;
  final String hausaName;
  final String emoji;
  final double minPh;
  final double optimalPhMin;
  final double optimalPhMax;
  final double maxPh;
  final double optimalMoistureMin;
  final double optimalMoistureMax;
  final String criticalNotesEn;
  final String criticalNotesHa;

  String displayName(bool hausa) => hausa ? hausaName : name;
  String localizedNotes(bool hausa) => hausa ? criticalNotesHa : criticalNotesEn;
}

class SoilConditionAdvice {
  const SoilConditionAdvice({
    required this.phStatus,
    required this.phScoreTextEn,
    required this.phScoreTextHa,
    required this.phAdviceEn,
    required this.phAdviceHa,
    required this.moistureStatus,
    required this.moistureTextEn,
    required this.moistureTextHa,
    required this.moistureAdviceEn,
    required this.moistureAdviceHa,
    required this.overallRating,
    required this.overallScore,
  });

  final String phStatus;
  final String phScoreTextEn;
  final String phScoreTextHa;
  final String phAdviceEn;
  final String phAdviceHa;
  final String moistureStatus;
  final String moistureTextEn;
  final String moistureTextHa;
  final String moistureAdviceEn;
  final String moistureAdviceHa;
  final String overallRating;
  final int overallScore;

  String phScoreText(bool hausa) => hausa ? phScoreTextHa : phScoreTextEn;
  String phAdvice(bool hausa) => hausa ? phAdviceHa : phAdviceEn;
  String moistureText(bool hausa) => hausa ? moistureTextHa : moistureTextEn;
  String moistureAdvice(bool hausa) => hausa ? moistureAdviceHa : moistureAdviceEn;
}

class SoilRecord {
  const SoilRecord({
    required this.id,
    required this.plotName,
    required this.cropId,
    required this.cropName,
    required this.cropHausaName,
    required this.ph,
    required this.moisture,
    required this.soilType,
    required this.createdAt,
    required this.advice,
  });

  final String id;
  final String plotName;
  final String cropId;
  final String cropName;
  final String cropHausaName;
  final double ph;
  final double moisture;
  final String soilType;
  final String createdAt;
  final SoilConditionAdvice advice;
}
