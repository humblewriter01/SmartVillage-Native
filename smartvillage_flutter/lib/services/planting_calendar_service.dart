import '../data/calendar_data.dart';
import '../models/planting_calendar.dart';

/// Seasonal planning for Northern & Middle-Belt Nigeria.
/// Port of `plantingCalendarService`.
class PlantingCalendarService {
  const PlantingCalendarService._();

  static List<CropCalendarSchedule> get crops => cropCalendar;

  static bool isMonthInWindow(int month, int startMonth, int endMonth) {
    if (startMonth <= endMonth) {
      return month >= startMonth && month <= endMonth;
    }
    return month >= startMonth || month <= endMonth;
  }

  static bool isPlantingActive(CropCalendarSchedule crop, int month) {
    if (crop.plantingWindows.isNotEmpty) {
      return crop.plantingWindows
          .any((w) => isMonthInWindow(month, w.startMonth, w.endMonth));
    }
    return isMonthInWindow(month, crop.plantingStartMonth, crop.plantingEndMonth);
  }

  static bool isHarvestActive(CropCalendarSchedule crop, int month) {
    if (crop.harvestWindows.isNotEmpty) {
      return crop.harvestWindows
          .any((w) => isMonthInWindow(month, w.startMonth, w.endMonth));
    }
    return isMonthInWindow(month, crop.harvestStartMonth, crop.harvestEndMonth);
  }

  static HarvestWindow? activeHarvestWindow(
    CropCalendarSchedule crop,
    int month,
  ) {
    for (final window in crop.harvestWindows) {
      if (isMonthInWindow(month, window.startMonth, window.endMonth)) {
        return window;
      }
    }
    return null;
  }

  static PlantingWindow? activePlantingWindow(
    CropCalendarSchedule crop,
    int month,
  ) {
    for (final window in crop.plantingWindows) {
      if (isMonthInWindow(month, window.startMonth, window.endMonth)) {
        return window;
      }
    }
    return null;
  }

  static SeasonInfo currentSeason(int month) {
    if (month >= 5 && month <= 9) {
      return const SeasonInfo(
        name: 'Rainy Season (Damina)',
        nameHausa: 'Lokacin Damina',
        description:
            'Primary planting and vegetative growth period across Nigeria.',
        descriptionHausa:
            'Babban lokacin shuka da noman rani a Arewacin Najeriya.',
        harmattanWarning: false,
      );
    }
    if (month == 12 || month == 1 || month == 2) {
      return const SeasonInfo(
        name: 'Harmattan Season (Kakika / Hunturu)',
        nameHausa: 'Lokacin Hunturu da Kura (Harmattan)',
        description:
            'Dry, dusty north-easterly winds and cold nights. Ideal for irrigated onion and wheat.',
        descriptionHausa:
            'Lokacin sanyi, busasshen iska da kura. Lokaci mai kyau ga noman rani na albasa da alkama.',
        harmattanWarning: true,
      );
    }
    return const SeasonInfo(
      name: 'Dry Season / Early Heat (Rani / Bazara)',
      nameHausa: 'Lokacin Rani da Bazara',
      description:
          'Hot, dry conditions. Storage, land preparation, and fadama irrigation.',
      descriptionHausa:
          'Zafi da bushewar ƙasa. Lokacin gyaran gona da ajiye hatsi.',
      harmattanWarning: false,
    );
  }

  static List<PlantingRecommendation> recommendationsFor(DateTime date) {
    final month = date.month;
    final recommendations = <PlantingRecommendation>[];

    for (final crop in cropCalendar) {
      final plantingActive = isPlantingActive(crop, month);
      final harvestActive = isHarvestActive(crop, month);

      if (plantingActive) {
        final window = activePlantingWindow(crop, month);
        recommendations.add(
          PlantingRecommendation(
            crop: crop,
            status: RecommendationStatus.optimal,
            title: 'Plant ${crop.name} now',
            titleHausa: 'Shuka ${crop.hausaName} yanzu',
            reason:
                '${window?.label(false) ?? 'Planting window is open'} — ideal rainfall: ${crop.idealRainfall}, temperature ${crop.idealTemp}.',
            reasonHausa:
                '${window?.label(true) ?? 'Lokacin shuka ya buɗe'} — ruwan sama da ya dace: ${crop.idealRainfall}, zafin jiki ${crop.idealTemp}.',
          ),
        );
      } else if (harvestActive) {
        final window = activeHarvestWindow(crop, month);
        recommendations.add(
          PlantingRecommendation(
            crop: crop,
            status: RecommendationStatus.careWindow,
            title: 'Harvest ${crop.name}',
            titleHausa: 'Girbe ${crop.hausaName}',
            reason:
                '${window?.label(false) ?? 'Harvest window is open'} — ${crop.advice}',
            reasonHausa:
                '${window?.label(true) ?? 'Lokacin girbi ya buɗe'} — ${crop.adviceHausa}',
          ),
        );
      } else {
        final nextStart = _nextStartMonth(crop, month);
        final monthsAway = (nextStart - month) % 12;
        recommendations.add(
          PlantingRecommendation(
            crop: crop,
            status: monthsAway <= 2
                ? RecommendationStatus.upcoming
                : RecommendationStatus.past,
            title: monthsAway == 0
                ? 'Prepare land for ${crop.name}'
                : 'Plant ${crop.name} in $monthsAway month(s)',
            titleHausa: monthsAway == 0
                ? 'Shirya gona domin ${crop.hausaName}'
                : 'Shuka ${crop.hausaName} cikin wata $monthsAway',
            reason: crop.advice,
            reasonHausa: crop.adviceHausa,
          ),
        );
      }
    }

    recommendations.sort((a, b) => a.status.index.compareTo(b.status.index));
    return recommendations;
  }

  static int _nextStartMonth(CropCalendarSchedule crop, int currentMonth) {
    if (crop.plantingWindows.isEmpty) {
      return crop.plantingStartMonth;
    }
    final starts = crop.plantingWindows.map((w) => w.startMonth).toList()..sort();
    for (final start in starts) {
      if (start >= currentMonth) return start;
    }
    return starts.first;
  }

  static String monthName(int month, bool hausa) {
    const english = <String>[
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const hausaMonths = <String>[
      'Janairu', 'Faburairu', 'Maris', 'Afirilu', 'Mayu', 'Yuni',
      'Yuli', 'Agusta', 'Satumba', 'Oktoba', 'Nuwamba', 'Disamba',
    ];
    final index = (month - 1).clamp(0, 11);
    return hausa ? hausaMonths[index] : english[index];
  }

  static String windowLabel(CropCalendarSchedule crop, bool hausa) {
    final start = monthName(crop.plantingStartMonth, hausa);
    final end = monthName(crop.plantingEndMonth, hausa);
    return hausa ? '$start zuwa $end' : '$start – $end';
  }

  static String seasonTypeLabel(SeasonType type, bool hausa) {
    switch (type) {
      case SeasonType.rainfed:
        return hausa ? 'Damina kawai' : 'Rain-fed only';
      case SeasonType.irrigatedDry:
        return hausa ? 'Rani (shayarwa)' : 'Irrigated dry season';
      case SeasonType.both:
        return hausa ? 'Damina da Rani' : 'Rain-fed & irrigated';
    }
  }
}
