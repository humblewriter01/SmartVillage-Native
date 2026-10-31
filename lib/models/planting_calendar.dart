/// Planting-calendar models.
///
/// Mirrors `src/services/plantingCalendarService.ts`
/// (`PlantingWindow`, `HarvestWindow`, `CropCalendarSchedule`,
/// `PlantingRecommendation`).
library;

enum SeasonType { rainfed, irrigatedDry, both }

enum RecommendationStatus { optimal, upcoming, past, careWindow }

class PlantingWindow {
  const PlantingWindow({
    required this.seasonLabelEn,
    required this.seasonLabelHa,
    required this.startMonth,
    required this.startDay,
    required this.endMonth,
    required this.endDay,
  });

  final String seasonLabelEn;
  final String seasonLabelHa;
  final int startMonth;
  final int startDay;
  final int endMonth;
  final int endDay;

  String label(bool hausa) => hausa ? seasonLabelHa : seasonLabelEn;
}

class HarvestWindow {
  const HarvestWindow({
    required this.seasonLabelEn,
    required this.seasonLabelHa,
    required this.startMonth,
    required this.endMonth,
  });

  final String seasonLabelEn;
  final String seasonLabelHa;
  final int startMonth;
  final int endMonth;

  String label(bool hausa) => hausa ? seasonLabelHa : seasonLabelEn;
}

class CropCalendarSchedule {
  const CropCalendarSchedule({
    required this.id,
    required this.name,
    required this.hausaName,
    required this.seasonType,
    required this.plantingStartMonth,
    required this.plantingStartDay,
    required this.plantingEndMonth,
    required this.plantingEndDay,
    required this.harvestStartMonth,
    required this.harvestEndMonth,
    required this.plantingWindows,
    required this.harvestWindows,
    required this.carePeriodWeeks,
    required this.idealRainfall,
    required this.idealTemp,
    required this.advice,
    required this.adviceHausa,
    required this.babyPlantCare,
    required this.babyPlantCareHausa,
  });

  final String id;
  final String name;
  final String hausaName;
  final SeasonType seasonType;
  final int plantingStartMonth;
  final int plantingStartDay;
  final int plantingEndMonth;
  final int plantingEndDay;
  final int harvestStartMonth;
  final int harvestEndMonth;
  final List<PlantingWindow> plantingWindows;
  final List<HarvestWindow> harvestWindows;
  final int carePeriodWeeks;
  final String idealRainfall;
  final String idealTemp;
  final String advice;
  final String adviceHausa;
  final String babyPlantCare;
  final String babyPlantCareHausa;

  String displayName(bool hausa) => hausa ? hausaName : name;
  String localizedAdvice(bool hausa) => hausa ? adviceHausa : advice;
  String localizedBabyCare(bool hausa) =>
      hausa ? babyPlantCareHausa : babyPlantCare;
}

class PlantingRecommendation {
  const PlantingRecommendation({
    required this.crop,
    required this.status,
    required this.title,
    required this.titleHausa,
    required this.reason,
    required this.reasonHausa,
  });

  final CropCalendarSchedule crop;
  final RecommendationStatus status;
  final String title;
  final String titleHausa;
  final String reason;
  final String reasonHausa;

  String displayTitle(bool hausa) => hausa ? titleHausa : title;
  String displayReason(bool hausa) => hausa ? reasonHausa : reason;
}

class SeasonInfo {
  const SeasonInfo({
    required this.name,
    required this.nameHausa,
    required this.description,
    required this.descriptionHausa,
    required this.harmattanWarning,
  });

  final String name;
  final String nameHausa;
  final String description;
  final String descriptionHausa;
  final bool harmattanWarning;

  String displayName(bool hausa) => hausa ? nameHausa : name;
  String displayDescription(bool hausa) => hausa ? descriptionHausa : description;
}
