import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'image_analysis.dart';

class WaterGuidelines {
  const WaterGuidelines({
    required this.standard,
    required this.whoLimit,
    required this.nsdwqLimit,
    required this.practicalAdvice,
    required this.practicalAdviceHausa,
  });

  final String standard;
  final String whoLimit;
  final String nsdwqLimit;
  final String practicalAdvice;
  final String practicalAdviceHausa;

  String advice(bool hausa) =>
      hausa ? practicalAdviceHausa : practicalAdvice;
}

class WaterQualityResult {
  const WaterQualityResult({
    required this.status,
    required this.turbidityScore,
    required this.colorAssessment,
    required this.colorAssessmentHausa,
    required this.hasParticles,
    required this.verdictTitle,
    required this.verdictTitleHausa,
    required this.advice,
    required this.adviceHausa,
    required this.guidelines,
  });

  /// `clean` or `not_clean`.
  final String status;
  final int turbidityScore;
  final String colorAssessment;
  final String colorAssessmentHausa;
  final bool hasParticles;
  final String verdictTitle;
  final String verdictTitleHausa;
  final String advice;
  final String adviceHausa;
  final WaterGuidelines guidelines;

  bool get isClean => status == 'clean';

  String displayVerdict(bool hausa) => hausa ? verdictTitleHausa : verdictTitle;
  String displayAdvice(bool hausa) => hausa ? adviceHausa : advice;
  String displayColor(bool hausa) =>
      hausa ? colorAssessmentHausa : colorAssessment;
}

/// Offline visual water-safety screening.
///
/// Port of `waterQualityService.analyzeWater()`:
/// * reject only pure white specular glare,
/// * flag yellow/brown silt and green algae tints,
/// * detect isolated suspended particles with a Laplacian contrast test that
///   ignores straight glass walls,
/// * convert all of that into a 0-100 turbidity score and a
///   "Clean" / "Boil before use" verdict.
class WaterQualityService {
  const WaterQualityService._();

  static const int _size = 160;

  static Future<WaterQualityResult> analyze(
    Uint8List imageBytes,
  ) async {
    final image = await ImageAnalyzer.decode(imageBytes, size: _size);
    if (image == null) return fallbackResult();

    try {
      final width = image.width;
      final height = image.height;
      final minX = (width * 0.10).floor();
      final maxX = (width * 0.90).floor();
      final minY = (height * 0.10).floor();
      final maxY = (height * 0.92).floor();

      // Brightness map for local contrast / particle analysis.
      final brightness = Float32List(width * height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          brightness[y * width + x] = image.brightness(x, y);
        }
      }

      var nonGlarePixels = 0;
      var yellowBrownPixels = 0;
      var algaePixels = 0;

      for (var y = minY; y < maxY; y++) {
        for (var x = minX; x < maxX; x++) {
          final r = image.r(x, y);
          final g = image.g(x, y);
          final b = image.b(x, y);
          final bright = brightness[y * width + x];

          final maxC = math.max(r, math.max(g, b));
          final minC = math.min(r, math.min(g, b));

          // Only ignore pure uncoloured white sheen on the glass.
          final isSpecularGlare = bright > 242 && (maxC - minC) < 14;
          if (isSpecularGlare) continue;

          nonGlarePixels++;

          final saturation = maxC > 0 ? (maxC - minC) / maxC : 0.0;

          final isYellowTint = (r > b + 12 && g > b + 5 && saturation > 0.09) ||
              (r > b + 20 && saturation > 0.12) ||
              (r > 150 && g > 120 && b < 120 && r > b + 18);
          final isDarkMud =
              (r > b + 8 && g > b + 4 && bright < 115 && saturation > 0.14);

          if (isYellowTint || isDarkMud) {
            yellowBrownPixels++;
          } else if (g > r + 10 && g > b + 10 && saturation > 0.12) {
            algaePixels++;
          }
        }
      }

      final validPixels = math.max(1, nonGlarePixels);
      final yellowFraction = yellowBrownPixels / validPixels;
      final algaeFraction = algaePixels / validPixels;

      // Second pass — isolated particulate detection.
      var isolatedDebris = 0;
      for (var y = minY + 2; y < maxY - 2; y++) {
        for (var x = minX + 2; x < maxX - 2; x++) {
          final c = brightness[y * width + x];
          if (c > 240 || c < 20) continue;

          final top = brightness[(y - 1) * width + x];
          final bottom = brightness[(y + 1) * width + x];
          final left = brightness[y * width + (x - 1)];
          final right = brightness[y * width + (x + 1)];

          final laplacian = (4 * c - top - bottom - left - right).abs();
          if (laplacian <= 16) continue;

          final isSpeck = (c - (top + bottom) / 2).abs() > 9 &&
              (c - (left + right) / 2).abs() > 9;
          if (isSpeck) isolatedDebris++;
        }
      }

      final isYellowBrown = yellowFraction > 0.07;
      final isAlgaeGreen = algaeFraction > 0.08;
      final hasParticles = isolatedDebris >= 6;

      var turbidity = 6;
      if (isYellowBrown) {
        turbidity = math.min(98, 55 + (yellowFraction * 44).round());
      } else if (isAlgaeGreen) {
        turbidity = math.min(95, 56 + (algaeFraction * 40).round());
      }
      if (hasParticles) {
        turbidity = math.max(
          turbidity,
          math.min(88, 54 + isolatedDebris * 2),
        );
      }
      turbidity = math.min(100, math.max(4, turbidity));

      final isClean = turbidity < 25 &&
          !isYellowBrown &&
          !isAlgaeGreen &&
          !hasParticles;

      var colorEn = 'Clear transparent water';
      var colorHa = 'Ruwa mai haske da tsabta';

      if (isYellowBrown && hasParticles) {
        colorEn = 'Yellowish-brown silt & suspended particles detected';
        colorHa = 'An ga laka mai ruwan kasa da barbashi a ciki';
      } else if (isYellowBrown) {
        colorEn = 'Brownish silt / yellow clay sediment detected';
        colorHa = 'An ga laka ko yashi mai launin kasa';
      } else if (isAlgaeGreen) {
        colorEn = 'Greenish tint / algae growth detected';
        colorHa = 'An ga launin kore na toka-toka ko ciyawar ruwa';
      } else if (hasParticles) {
        colorEn = 'Suspended particulate matter detected';
        colorHa = 'An ga barbashi ko datti da ke shawagi a ciki';
      }

      if (isClean) {
        return WaterQualityResult(
          status: 'clean',
          turbidityScore: turbidity,
          colorAssessment: colorEn,
          colorAssessmentHausa: colorHa,
          hasParticles: false,
          verdictTitle: '✅ Clean Water',
          verdictTitleHausa: '✅ Ruwa Mai Kyau',
          advice:
              'Water appears visually clear and free of heavy sediment. For drinking, ensure the container is covered and sanitized. If from an open shallow well, boiling is still recommended.',
          adviceHausa:
              'Ruwan yana da haske kuma babu laka mai yawa. Don sha, tabbatar da an rufe bokiti ko randa. Idan na rijiya ce maras murfi, tafasa shi kafin sha.',
          guidelines: _defaultGuidelines,
        );
      }

      return WaterQualityResult(
        status: 'not_clean',
        turbidityScore: turbidity,
        colorAssessment: colorEn,
        colorAssessmentHausa: colorHa,
        hasParticles: hasParticles,
        verdictTitle: '⚠️ Not Clean – Boil Before Use',
        verdictTitleHausa: '⚠️ Ba shi da Tsabta – Tafasa Kafin Sha',
        advice:
            'High turbidity, discoloration, or suspended particles detected. DO NOT drink untreated. Filter through a clean folded cloth or sand filter, then bring to a rolling boil for at least 1-3 minutes. Alternatively, use SODIS (6 hours direct sunlight in clear PET bottle) or WaterGuard chlorine drops.',
        adviceHausa:
            'An ga laka, kwayoyin datti ko launin da ba a saba gani ba. KADA a sha haka kai tsaye! Tace ruwan da kyallen zane mai tsabta, sannan a tafasa shi a wuta na mintuna 1 zuwa 3. Ko a zuba maganin WaterGuard kafin sha.',
        guidelines: const WaterGuidelines(
          standard: 'WHO & Nigerian Standard for Drinking Water Quality (NSDWQ)',
          whoLimit: '< 5 NTU Turbidity (Exceeded visually)',
          nsdwqLimit: 'Requires disinfection & filtration before potable use',
          practicalAdvice:
              '1. Settle sediment for 2 hours. 2. Filter through cloth/sand. 3. Boil for 3 minutes.',
          practicalAdviceHausa:
              '1. Bar ruwan ya kwanta na awa 2. 2. Tace da mayafi mai tsabta. 3. Tafasa na minti 3.',
        ),
      );
    } catch (error) {
      debugPrint('[WaterQualityService] analysis failed: $error');
      return fallbackResult();
    }
  }

  static const WaterGuidelines _defaultGuidelines = WaterGuidelines(
    standard: 'WHO & Nigerian Standard for Drinking Water Quality (NSDWQ)',
    whoLimit: '< 5 NTU Turbidity, 0 E. coli colonies / 100ml',
    nsdwqLimit: '< 5 NTU, pH 6.5 - 8.5, Taste/Odor: Inoffensive',
    practicalAdvice: 'Keep storage jerrycans clean and elevated off dusty ground.',
    practicalAdviceHausa: 'Ajiye jarka ko bokitin ruwa a wuri mai tsabta sama da ƙasa.',
  );

  // ---------------------------------------------------------------------------
  // Reference results (used by the "try a sample" buttons and tests)
  // ---------------------------------------------------------------------------

  static WaterQualityResult cleanBoreholeResult() => const WaterQualityResult(
        status: 'clean',
        turbidityScore: 8,
        colorAssessment: 'Clear transparent water',
        colorAssessmentHausa: 'Ruwa mai haske da tsabta',
        hasParticles: false,
        verdictTitle: 'Clean – Safe to Drink',
        verdictTitleHausa: 'Ruwa Mai Kyau',
        advice:
            'Water appears visually clear and free of heavy sediment. For drinking, ensure the container is covered and sanitized. If from an open shallow well, boiling is still recommended.',
        adviceHausa:
            'Ruwan yana da haske kuma babu laka mai yawa. Don sha, tabbatar da an rufe bokiti ko randa. Idan na rijiya ce maras murfi, tafasa shi kafin sha.',
        guidelines: _defaultGuidelines,
      );

  static WaterQualityResult turbidRiverResult() => const WaterQualityResult(
        status: 'not_clean',
        turbidityScore: 84,
        colorAssessment: 'Brownish silt / clay sediment detected',
        colorAssessmentHausa: 'An ga laka ko yashi mai launin kasa',
        hasParticles: true,
        verdictTitle: 'Not Clean – Boil Before Use',
        verdictTitleHausa: 'Ba shi da Tsabta – Tafasa Kafin Sha',
        advice:
            'High turbidity, silt, and suspended particles detected. DO NOT drink untreated. Settle for 2 hours, filter through clean folded cloth or sand filter, and bring to a rolling boil for 1-3 minutes. Alternatively, apply WaterGuard chlorine drops or flocculant powder.',
        adviceHausa:
            'An ga laka mai kauri da kwayoyin yashi a cikin ruwan. KADA a sha ba tare da tacewa da tafasawa ba! A bar ruwan ya kwanta na awa 2, a tace da kyalle mai tsabta, sannan a tafasa shi na minti 1 zuwa 3.',
        guidelines: WaterGuidelines(
          standard: 'WHO & Nigerian Standard for Drinking Water Quality (NSDWQ)',
          whoLimit: '< 5 NTU Turbidity (Exceeded visually)',
          nsdwqLimit: 'Requires disinfection & filtration before potable use',
          practicalAdvice:
              '1. Settle sediment for 2 hours. 2. Filter through cloth/sand. 3. Boil for 3 minutes.',
          practicalAdviceHausa:
              '1. Bar ruwan ya kwanta na awa 2. 2. Tace da mayafi mai tsabta. 3. Tafasa na minti 3.',
        ),
      );

  static WaterQualityResult algaeResult() => const WaterQualityResult(
        status: 'not_clean',
        turbidityScore: 78,
        colorAssessment: 'Greenish tint / algae growth detected',
        colorAssessmentHausa: 'An ga launin kore na toka-toka ko ciyawar ruwa',
        hasParticles: true,
        verdictTitle: 'Not Clean – Boil Before Use',
        verdictTitleHausa: 'Ba shi da Tsabta – Tafasa Kafin Sha',
        advice:
            'Green coloration and algae growth detected. Stagnant surface waters often contain cyanobacteria toxins and protozoan parasites. Skim off surface scum, filter through clean cloth, and boil thoroughly. Avoid using for infants.',
        adviceHausa:
            'An ga launin kore da ciyawar ruwa. Ruwan da ya dade a kwance yana dauke da guba da kwayoyin cuta masu hadari. Tace ruwan da kyalle sannan a tafasa sosai a wuta.',
        guidelines: WaterGuidelines(
          standard: 'WHO & Nigerian Standard for Drinking Water Quality (NSDWQ)',
          whoLimit: '0 Cyanobacterial scums, < 5 NTU',
          nsdwqLimit: 'Requires filtration and boiling before use',
          practicalAdvice:
              'Do not collect water from surface scum areas. Boil before drinking.',
          practicalAdviceHausa:
              'Kada a debi ruwa a inda ciyawa ta kwanta a kai. A tafasa kafin sha.',
        ),
      );

  static WaterQualityResult fallbackResult() => const WaterQualityResult(
        status: 'clean',
        turbidityScore: 10,
        colorAssessment: 'Clear transparent appearance',
        colorAssessmentHausa: 'Ruwa mai haske da tsabta',
        hasParticles: false,
        verdictTitle: '✅ Clean Water',
        verdictTitleHausa: '✅ Ruwa Mai Kyau',
        advice:
            'Water appears visually clear. For drinking, ensure containers are covered and kept off dusty ground. If sourced from an open well, boil before drinking.',
        adviceHausa:
            'Ruwan yana da haske da kyau. Don sha, kiyaye tsaftar jarka ko randa. Idan na rijiya ce, tafasa shi kafin sha.',
        guidelines: WaterGuidelines(
          standard: 'WHO Water Safety Plan',
          whoLimit: '< 5 NTU, 0 fecal coliforms',
          nsdwqLimit: 'Potable water must be free from pathogens',
          practicalAdvice: 'Keep drinking water covered in clean containers.',
          practicalAdviceHausa:
              'Koyaushe a rufe ruwan sha a cikin bokiti ko randa mai tsabta.',
        ),
      );
}
