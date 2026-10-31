import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'storage_service.dart';

/// A crop currently in the ground.
class PlantedCrop {
  PlantedCrop({
    required this.id,
    required this.cropId,
    required this.name,
    required this.hausaName,
    required this.fieldLabel,
    required this.plantingDate,
    required this.maturityDays,
    required this.criticalTipsEn,
    required this.criticalTipsHa,
  });

  final String id;
  final String cropId;
  final String name;
  final String hausaName;
  final String fieldLabel;
  final DateTime plantingDate;
  final int maturityDays;
  final String criticalTipsEn;
  final String criticalTipsHa;

  String displayName(bool hausa) => hausa ? hausaName : name;
  String tip(bool hausa) => hausa ? criticalTipsHa : criticalTipsEn;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'cropId': cropId,
        'name': name,
        'hausaName': hausaName,
        'fieldLabel': fieldLabel,
        'plantingDate': plantingDate.toIso8601String().split('T').first,
        'maturityDays': maturityDays,
        'criticalTipsEn': criticalTipsEn,
        'criticalTipsHa': criticalTipsHa,
      };

  static PlantedCrop fromJson(Map<String, dynamic> json) => PlantedCrop(
        id: json['id'] as String? ?? 'crop-${DateTime.now().millisecondsSinceEpoch}',
        cropId: json['cropId'] as String? ?? 'onion',
        name: json['name'] as String? ?? 'Onion',
        hausaName: json['hausaName'] as String? ?? 'Albasa',
        fieldLabel: json['fieldLabel'] as String? ?? '',
        plantingDate:
            DateTime.tryParse(json['plantingDate'] as String? ?? '') ??
                DateTime.now(),
        maturityDays: (json['maturityDays'] as num?)?.toInt() ?? 100,
        criticalTipsEn: json['criticalTipsEn'] as String? ?? '',
        criticalTipsHa: json['criticalTipsHa'] as String? ?? '',
      );
}

class HarvestPreset {
  const HarvestPreset({
    required this.cropId,
    required this.name,
    required this.hausaName,
    required this.maturityDays,
    required this.criticalTipsEn,
    required this.criticalTipsHa,
  });

  final String cropId;
  final String name;
  final String hausaName;
  final int maturityDays;
  final String criticalTipsEn;
  final String criticalTipsHa;

  String displayName(bool hausa) => hausa ? hausaName : name;
  String tip(bool hausa) => hausa ? criticalTipsHa : criticalTipsEn;
}

class HarvestStatus {
  const HarvestStatus({
    required this.daysElapsed,
    required this.daysRemaining,
    required this.progressPercent,
    required this.harvestDate,
    required this.stageEn,
    required this.stageHa,
    required this.isHarvestReady,
  });

  final int daysElapsed;
  final int daysRemaining;
  final int progressPercent;
  final DateTime harvestDate;
  final String stageEn;
  final String stageHa;
  final bool isHarvestReady;

  String stage(bool hausa) => hausa ? stageHa : stageEn;
}

/// Harvest countdown maths + persistence.
/// Port of `HarvestCountdownCard.calculateStatus` and
/// `HomeHarvestCountdown`'s seeded plantings.
class HarvestService {
  HarvestService({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  final StorageService _storage;

  static const String storageKey = 'smartvillage.harvest_countdowns';

  /// 13 crop presets with maturity windows and harvest-readiness signs.
  static const List<HarvestPreset> presets = <HarvestPreset>[
    HarvestPreset(
      cropId: 'onion',
      name: 'Onion',
      hausaName: 'Albasa',
      maturityDays: 110,
      criticalTipsEn:
          'When 50%-70% of onion necks collapse and fall over, withhold irrigation 7-10 days before pulling bulbs to ensure thick skins and prevent rot.',
      criticalTipsHa:
          'Idan kashi 50% zuwa 70% na wuyan ganyen albasa suka karkata kasa (neck fall), a dakatar da ban ruwa kwanaki 7-10 kafin kwashewa domin kada su rube a rumbu.',
    ),
    HarvestPreset(
      cropId: 'maize',
      name: 'Maize',
      hausaName: 'Masara',
      maturityDays: 100,
      criticalTipsEn:
          'When silks turn dark brown/dry and the black layer forms at kernel tips, grain moisture is ready for harvest.',
      criticalTipsHa:
          'Idan gashin masara ya zama baki kuma kwayar hatsi ta yi tauri tare da baƙin layi a gindinta (black layer), lokacin girbi ya yi.',
    ),
    HarvestPreset(
      cropId: 'tomato',
      name: 'Tomato',
      hausaName: 'Tumatir',
      maturityDays: 80,
      criticalTipsEn:
          'Harvest in early morning when fruits reach the pink/breaker stage to maintain shelf life during transport.',
      criticalTipsHa:
          'A tsinke tumatir da sassafe idan ya fara nuna ruwan hoda ko ja (breaker stage) don kada zafin rana ya lalata shi kafin zuwa kasuwa.',
    ),
    HarvestPreset(
      cropId: 'rice',
      name: 'Rice',
      hausaName: 'Shinkafa',
      maturityDays: 120,
      criticalTipsEn:
          'Harvest when 80%-85% of panicle grains turn straw gold to minimize shattering and lodging losses.',
      criticalTipsHa:
          'Lokacin da kashi 80% na hatsin zangarniyar shinkafa ya zama launin zinare (dorawa), a fara girbi don hana zubar hatsi a gona.',
    ),
    HarvestPreset(
      cropId: 'sorghum',
      name: 'Sorghum',
      hausaName: 'Dawa',
      maturityDays: 120,
      criticalTipsEn:
          'Harvest panicles when grain moisture drops below 20% and seed firmness resists fingernail denting.',
      criticalTipsHa:
          'A girbe dawa idan kwayar hatsi ta bushe sosai kuma tsuntsaye ba za su iya huda ta ba.',
    ),
    HarvestPreset(
      cropId: 'cowpea',
      name: 'Cowpea (Beans)',
      hausaName: 'Wake',
      maturityDays: 70,
      criticalTipsEn:
          'Pick mature dry pods in rounds every few days to protect seeds from pod borers and late rains.',
      criticalTipsHa:
          'A kwashe ɓawon waken da suka bushe akai-akai domin kariya daga kwari da ruwan sama na makara.',
    ),
    HarvestPreset(
      cropId: 'groundnut',
      name: 'Groundnut',
      hausaName: 'Gyada',
      maturityDays: 100,
      criticalTipsEn:
          'Lift vines when inner pod shells develop dark brown markings and lower foliage begins yellowing.',
      criticalTipsHa:
          'A cire gyada idan cikin kwasfar ya yi duhun ruwan kasa kuma ganyen ya fara bushewa.',
    ),
    HarvestPreset(
      cropId: 'wheat',
      name: 'Wheat',
      hausaName: 'Alkama',
      maturityDays: 100,
      criticalTipsEn:
          'Harvest irrigated wheat before high March temperatures cause shattering and shriveling.',
      criticalTipsHa:
          'A duba zangarniya idan ta bushe sarai ta yi launi mai haske kafin zafin watan Maris ya yi yawa.',
    ),
    HarvestPreset(
      cropId: 'soybeans',
      name: 'Soybeans',
      hausaName: 'Waken Soya',
      maturityDays: 105,
      criticalTipsEn:
          'Harvest when 90% of leaves drop and pods turn golden-brown and rattle. Avoid over-drying in the field to prevent severe pod shattering losses.',
      criticalTipsHa:
          'A girbe waken soya da zaran kashi 90% na ganyen ya zube kuma kwasfar ta bushe zuwa launin ruwan kasa. Idan aka jinkirta kwasfar na fashewa tana zubar da iri.',
    ),
    HarvestPreset(
      cropId: 'cassava',
      name: 'Cassava',
      hausaName: 'Rogo',
      maturityDays: 330,
      criticalTipsEn:
          'Harvest cassava at 10-12 months (330 days) when soil around the stem base cracks. Process or market tubers within 48-72 hours of harvest to avoid vascular decay.',
      criticalTipsHa:
          'A girbe rogo bayan watanni 10-12 (kwanaki 330) idan kasa ta fara tsagewa a gindin shuka. A kwashe tushen da wuri domin hana tauri ko rubewa a karkashin kasa.',
    ),
    HarvestPreset(
      cropId: 'yam',
      name: 'Yam',
      hausaName: 'Doya',
      maturityDays: 240,
      criticalTipsEn:
          'Harvest when foliage completely dies back in November-January (approx. 240 days). Dig carefully with wooden or blunt tools to avoid wounding tubers.',
      criticalTipsHa:
          'Idan ganyen doya ya fara bushewa ya zama launin ruwan kasa a watan Nuwamba/Disamba (kwanaki 240), lokacin tono ya yi. A tono da hankali ba tare da raunata dankalin ba.',
    ),
    HarvestPreset(
      cropId: 'pepper',
      name: 'Pepper (Chili / Atarodo)',
      hausaName: 'Barkono',
      maturityDays: 90,
      criticalTipsEn:
          'Harvest ripe red or firm mature green peppers every 5-7 days (approx. 90 days from transplant). Frequent picking encourages continuous fruit setting.',
      criticalTipsHa:
          'A tsinke barkono idan ya yi ja ko koren da ya cika girma a kowanne kwanaki 5-7 (kwanaki 90 bayan shuka). Tsinke akai-akai yana sa shukar ta sake fitar da sabbin fure da ya ya.',
    ),
    HarvestPreset(
      cropId: 'millet',
      name: 'Pearl Millet',
      hausaName: 'Gero',
      maturityDays: 75,
      criticalTipsEn:
          'Harvest heads when grain hardens and moisture drops below 15% (approx. 75 days). Sun-dry panicles thoroughly before threshing or granary storage to deter weevils.',
      criticalTipsHa:
          'A yanke zangarniyar gero da zaran kwayar hatsi ta bushe kuma ta yi tauri sosai (kwanaki 75). A shanya a rana kafin daka ko adanawa a rumbu don hana kwari.',
    ),
  ];

  static HarvestPreset? presetFor(String cropId) {
    for (final preset in presets) {
      if (preset.cropId == cropId) return preset;
      if (preset.cropId == 'soybeans' && cropId == 'soybean') return preset;
      if (preset.cropId == 'soybean' && cropId == 'soybeans') return preset;
    }
    return null;
  }

  /// Status maths ported 1:1 from `calculateStatus`.
  static HarvestStatus status(PlantedCrop crop, {DateTime? now}) {
    final today = DateUtilsX.dateOnly(now ?? DateTime.now());
    final planted = DateUtilsX.dateOnly(crop.plantingDate);

    final diffDays = today.difference(planted).inDays;
    final daysElapsed = diffDays < 0 ? 0 : diffDays;
    final daysRemaining =
        (crop.maturityDays - daysElapsed) < 0 ? 0 : crop.maturityDays - daysElapsed;
    final progressPercent = ((daysElapsed / crop.maturityDays) * 100)
        .round()
        .clamp(0, 100);

    var stageEn = 'Germination & Sprouting';
    var stageHa = 'Shuka da Fitowa';
    if (progressPercent >= 100) {
      stageEn = 'Harvest Ready!';
      stageHa = 'Lokacin Girbi ya Yi!';
    } else if (progressPercent >= 75) {
      stageEn = 'Maturation & Sizing';
      stageHa = 'Balagar Ƙarshe da Kafa Kai';
    } else if (progressPercent >= 40) {
      stageEn = 'Vegetative Growth';
      stageHa = 'Girma da Ƙarfin Ganye';
    } else if (progressPercent >= 15) {
      stageEn = 'Early Establishment';
      stageHa = 'Cire Ciyawa da Karin Ƙasa';
    }

    return HarvestStatus(
      daysElapsed: daysElapsed,
      daysRemaining: daysRemaining,
      progressPercent: progressPercent,
      harvestDate: planted.add(Duration(days: crop.maturityDays)),
      stageEn: stageEn,
      stageHa: stageHa,
      isHarvestReady: daysRemaining <= 0,
    );
  }

  Future<List<PlantedCrop>> load() async {
    final raw = await _storage.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final crops = decoded
              .whereType<Map<dynamic, dynamic>>()
              .map((item) => PlantedCrop.fromJson(
                    item.map((k, v) => MapEntry(k.toString(), v)),
                  ))
              .toList(growable: false);
          if (crops.isNotEmpty) return crops;
        }
      } catch (error) {
        debugPrint('[HarvestService] could not read saved plantings: $error');
      }
    }
    final seeded = seedPlantings();
    await save(seeded);
    return seeded;
  }

  Future<void> save(List<PlantedCrop> crops) async {
    try {
      await _storage.setString(
        storageKey,
        jsonEncode(crops.map((c) => c.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('[HarvestService] save failed: $error');
    }
  }

  /// Two demo plantings so the Home card is never empty on first launch.
  static List<PlantedCrop> seedPlantings({DateTime? now}) {
    final base = now ?? DateTime.now();
    final onionDate = base.subtract(const Duration(days: 38));
    final maizeDate = base.subtract(const Duration(days: 22));
    return <PlantedCrop>[
      PlantedCrop(
        id: 'initial-onion',
        cropId: 'onion',
        name: 'Onion',
        hausaName: 'Albasa',
        fieldLabel: 'Gonar Fadama (Kano/Sokoto)',
        plantingDate: onionDate,
        maturityDays: 110,
        criticalTipsEn:
            'When 50%-70% of onion necks collapse and fall over, withhold irrigation 7-10 days before pulling bulbs.',
        criticalTipsHa:
            'Idan kashi 50% zuwa 70% na wuyan ganyen albasa suka karkata kasa (neck fall), a dakatar da ban ruwa kwanaki 7-10 kafin kwashewa.',
      ),
      PlantedCrop(
        id: 'initial-maize',
        cropId: 'maize',
        name: 'Maize',
        hausaName: 'Masara',
        fieldLabel: 'Gonar Masara (Kaduna/Zaria)',
        plantingDate: maizeDate,
        maturityDays: 100,
        criticalTipsEn:
            'When silks turn dark brown/dry and the black layer forms at kernel tips, grain moisture is ready for harvest.',
        criticalTipsHa:
            'Idan gashin masara ya zama baki kwayar hatsi ta yi tauri tare da baƙin layi a gindinta (black layer), lokacin girbi ya yi.',
      ),
    ];
  }
}

/// Tiny date helper (Flutter's `DateUtils` lives in material, which services
/// should not import).
class DateUtilsX {
  const DateUtilsX._();

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String formatShortDate(DateTime date, bool hausa) {
    const monthsEn = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const monthsHa = <String>[
      'Jan', 'Fab', 'Mar', 'Afi', 'May', 'Yun',
      'Yul', 'Agu', 'Sat', 'Okt', 'Nuw', 'Dis',
    ];
    final months = hausa ? monthsHa : monthsEn;
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
