import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../data/crop_data.dart';
import '../models/crop.dart';
import 'image_analysis.dart';

class Prediction {
  const Prediction({required this.label, required this.confidence});

  final String label;
  final double confidence;

  double get percent => confidence * 100;
}

class CropResult {
  const CropResult({
    required this.predictions,
    required this.advice,
    required this.adviceHausa,
    required this.isLowConfidence,
    this.needsCropSelection = false,
    this.cropId,
    this.cropName,
    this.cropHausaName,
    this.referenceDetail,
  });

  final List<Prediction> predictions;
  final String advice;
  final String adviceHausa;
  final bool isLowConfidence;
  final bool needsCropSelection;
  final String? cropId;
  final String? cropName;
  final String? cropHausaName;
  final Disease? referenceDetail;

  String displayAdvice(bool hausa) => hausa ? adviceHausa : advice;
  double get topConfidence =>
      predictions.isEmpty ? 0 : predictions.first.confidence;
}

/// Offline crop diagnosis.
///
/// Port of `src/services/cropService.ts` — the heuristics are intentionally
/// identical so results match the React app farmers already trust:
/// * identify the crop from colour signatures (or honour the manual choice),
/// * evaluate diseases **only inside that crop's own library** (no cross-crop
///   mixing),
/// * let spoken/written symptoms override the visual guess.
class CropService {
  const CropService._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Analyses a leaf photo.
  static Future<CropResult> analyzeImage(
    Uint8List imageBytes, {
    String? targetCropId,
    String? spokenSymptoms,
  }) async {
    final fallbackCrop = cropById(targetCropId ?? 'cassava') ??
        cropReferenceData.first;

    final image = await ImageAnalyzer.decode(imageBytes, size: 224);
    if (image == null) {
      return _fallback(fallbackCrop, confidence: 0.70);
    }

    try {
      final identification = _identifyCrop(image, targetCropId);
      if (!identification.isConfident && targetCropId == null) {
        return const CropResult(
          predictions: <Prediction>[
            Prediction(label: 'crop_selection_needed', confidence: 0.4),
          ],
          advice:
              'Please select your specific crop first so we only show accurate diseases for your plant.',
          adviceHausa:
              'Da fatan zaɓi ainihin amfanin gonarka da farko domin nuna madaidaitan cututtuka kawai.',
          isLowConfidence: true,
          needsCropSelection: true,
        );
      }

      final crop = identification.crop;
      final metrics = _metricsFor(image);
      final evaluation = _evaluateCropDiseases(
        crop,
        metrics,
        spokenSymptoms,
      );
      final disease = evaluation.disease;

      if (evaluation.isHealthy) {
        return CropResult(
          predictions: <Prediction>[
            Prediction(label: '${crop.id}_healthy', confidence: evaluation.confidence),
          ],
          advice:
              'Your ${crop.crop} foliage appears healthy. Continue recommended field practices and proper moisture management.',
          adviceHausa:
              'Ganyen ${crop.hausaName} yana da lafiya. Ci gaba da kula da gona da ingantaccen ban ruwa.',
          isLowConfidence: false,
          cropId: crop.id,
          cropName: crop.crop,
          cropHausaName: crop.hausaName,
          referenceDetail: disease,
        );
      }

      return CropResult(
        predictions: <Prediction>[
          Prediction(label: disease.id, confidence: evaluation.confidence),
        ],
        advice: '${disease.name}: ${disease.treatment} '
            'Prevention: ${disease.prevention}',
        adviceHausa: '${disease.hausaName}: ${disease.treatmentHausa} '
            'Rigakafi: ${disease.preventionHausa}',
        isLowConfidence: false,
        cropId: crop.id,
        cropName: crop.crop,
        cropHausaName: crop.hausaName,
        referenceDetail: disease,
      );
    } catch (error) {
      debugPrint('[CropService] analysis failed: $error');
      return _fallback(fallbackCrop, confidence: 0.75);
    }
  }

  /// Voice / typed symptom triage, scoped to the selected crop.
  static CropResult diagnoseBySymptoms(String spokenText, {String? targetCropId}) {
    final query = spokenText.toLowerCase().trim();

    Crop? scope;
    if (targetCropId != null) {
      scope = cropById(targetCropId);
      if (scope == null && targetCropId == 'soybean') scope = cropById('soybeans');
    }

    if (scope != null) {
      return _resultFor(scope, _matchDisease(scope, query), 0.94);
    }

    for (final crop in cropReferenceData) {
      if (_contains(query, crop.crop) || _contains(query, crop.hausaName)) {
        return _resultFor(crop, _matchDisease(crop, query), 0.94);
      }
    }

    return const CropResult(
      predictions: <Prediction>[
        Prediction(label: 'crop_selection_needed', confidence: 0.4),
      ],
      advice:
          'Please select your crop first so we only show diseases relevant to your specific plant.',
      adviceHausa:
          'Da fatan zaɓi shukarka da farko domin duba cututtukan da suka dace da ita kaɗai.',
      isLowConfidence: true,
      needsCropSelection: true,
    );
  }

  /// Manual picker path (crop + optional suspected disease + symptoms).
  static CropResult diagnoseSelection({
    required String cropId,
    String? suspectedDiseaseId,
    String? symptomsText,
  }) {
    final crop = cropById(cropId) ?? cropReferenceData.first;

    if (suspectedDiseaseId != null) {
      final disease = crop.diseaseById(suspectedDiseaseId) ?? crop.diseases.first;
      return _resultFor(crop, disease, 0.96);
    }

    if (symptomsText != null && symptomsText.trim().isNotEmpty) {
      final matched = _matchDisease(crop, symptomsText.toLowerCase(), strict: true);
      if (matched != null) return _resultFor(crop, matched, 0.94);
    }

    final primary = crop.diseases.first;
    return CropResult(
      predictions: <Prediction>[
        Prediction(label: '${crop.id}_health_assessment', confidence: 0.95),
      ],
      advice: 'Health Assessment for ${crop.crop}: ${crop.description} '
          'Monitored disease: ${primary.name}. Treatment: ${primary.treatment}',
      adviceHausa: 'Duba Lafiyar ${crop.hausaName}: ${crop.descriptionHausa} '
          'Cutar da aka fi lura da ita: ${primary.hausaName}. '
          'Magani: ${primary.treatmentHausa}',
      isLowConfidence: false,
      cropId: crop.id,
      cropName: crop.crop,
      cropHausaName: crop.hausaName,
      referenceDetail: primary,
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static CropResult _resultFor(Crop crop, Disease? disease, double confidence) {
    final match = disease ?? crop.diseases.first;
    return CropResult(
      predictions: <Prediction>[
        Prediction(label: match.id, confidence: confidence),
      ],
      advice: match.treatment,
      adviceHausa: match.treatmentHausa,
      isLowConfidence: false,
      cropId: crop.id,
      cropName: crop.crop,
      cropHausaName: crop.hausaName,
      referenceDetail: match,
    );
  }

  static CropResult _fallback(Crop crop, {required double confidence}) {
    final disease = crop.diseases.first;
    return CropResult(
      predictions: <Prediction>[
        Prediction(label: disease.id, confidence: confidence),
      ],
      advice: disease.treatment,
      adviceHausa: disease.treatmentHausa,
      isLowConfidence: false,
      cropId: crop.id,
      cropName: crop.crop,
      cropHausaName: crop.hausaName,
      referenceDetail: disease,
    );
  }

  static bool _contains(String haystack, String needle) {
    if (needle.isEmpty) return false;
    return haystack.contains(needle.toLowerCase());
  }

  static Disease? _matchDisease(
    Crop crop,
    String query, {
    bool strict = false,
  }) {
    for (final disease in crop.diseases) {
      if (_contains(query, disease.name) ||
          _contains(query, disease.hausaName) ||
          _contains(query, disease.symptoms) ||
          _contains(query, disease.symptomsHausa)) {
        return disease;
      }
    }
    return strict ? null : crop.diseases.first;
  }

  static _CropIdentification _identifyCrop(
    RgbaImage image,
    String? targetCropId,
  ) {
    if (targetCropId != null) {
      final existing = cropById(targetCropId) ??
          (targetCropId == 'soybean' ? cropById('soybeans') : null);
      if (existing != null) {
        return _CropIdentification(
          crop: existing,
          confidence: 0.95,
          isConfident: true,
        );
      }
    }

    var purple = 0;
    var rust = 0;
    var red = 0;
    var cereal = 0;
    var green = 0;
    final total = image.pixelCount;

    for (var i = 0; i < image.bytes.length; i += 4) {
      final r = image.bytes[i];
      final g = image.bytes[i + 1];
      final b = image.bytes[i + 2];

      if (r > 75 && b > 75 && g < r - 15 && g < b - 10) purple++;
      if (r > g + 20 && g > b + 10 && r > 110) rust++;
      if (r > 150 && g < 100 && b < 80) red++;
      if (r > 160 && g > 150 && b < 100) cereal++;
      if (g > r + 15 && g > b + 15) green++;
    }

    final purpleRatio = purple / total;
    final rustRatio = rust / total;
    final redRatio = red / total;
    final cerealRatio = cereal / total;
    final greenRatio = green / total;

    if (purpleRatio > 0.03) {
      return _CropIdentification(
        crop: cropById('onion')!,
        confidence: 0.88,
        isConfident: true,
      );
    }
    if (redRatio > 0.05) {
      return _CropIdentification(
        crop: cropById('tomato')!,
        confidence: 0.82,
        isConfident: true,
      );
    }
    if (rustRatio > 0.15) {
      return _CropIdentification(
        crop: cropById('maize')!,
        confidence: 0.84,
        isConfident: true,
      );
    }
    if (cerealRatio > 0.15) {
      return _CropIdentification(
        crop: cropById('sorghum')!,
        confidence: 0.78,
        isConfident: true,
      );
    }
    if (greenRatio > 0.5) {
      return _CropIdentification(
        crop: cropReferenceData.first,
        confidence: 0.45,
        isConfident: false,
      );
    }

    return _CropIdentification(
      crop: cropReferenceData.first,
      confidence: 0.35,
      isConfident: false,
    );
  }

  static ImageMetrics _metricsFor(RgbaImage image) {
    var green = 0;
    var dark = 0;
    var yellow = 0;
    var rust = 0;
    var purple = 0;

    for (var i = 0; i < image.bytes.length; i += 4) {
      final r = image.bytes[i];
      final g = image.bytes[i + 1];
      final b = image.bytes[i + 2];
      final brightness = (r + g + b) / 3.0;

      if (g > r + 15 && g > b + 15) green++;
      if (r > g + 10 && g > b && r > 90 && brightness < 180) rust++;
      if (r > 75 && b > 75 && g < r - 15 && g < b - 10) purple++;
      if (r > 130 && g > 130 && b < 100) yellow++;
      if (brightness < 70) dark++;
    }

    final total = image.pixelCount;
    return ImageMetrics(
      greenRatio: green / total,
      rustRatio: rust / total,
      purpleRatio: purple / total,
      yellowRatio: yellow / total,
      darkRatio: dark / total,
    );
  }

  static _DiseaseEvaluation _evaluateCropDiseases(
    Crop crop,
    ImageMetrics metrics,
    String? symptomsText,
  ) {
    final diseases = crop.diseases;
    if (diseases.isEmpty) {
      throw StateError('Crop ${crop.crop} has no registered diseases');
    }

    final healthy = crop.healthyDisease;
    if (metrics.greenRatio > 0.75 &&
        metrics.rustRatio < 0.05 &&
        metrics.darkRatio < 0.05 &&
        metrics.yellowRatio < 0.05 &&
        metrics.purpleRatio < 0.02) {
      return _DiseaseEvaluation(
        disease: healthy ?? diseases.first,
        confidence: 0.92,
        isHealthy: true,
      );
    }

    final query = (symptomsText ?? '').toLowerCase();
    if (query.isNotEmpty) {
      for (final disease in diseases) {
        if (_contains(query, disease.name) ||
            _contains(query, disease.hausaName) ||
            _contains(query, disease.symptoms) ||
            _contains(query, disease.symptomsHausa)) {
          return _DiseaseEvaluation(
            disease: disease,
            confidence: 0.96,
            isHealthy: disease.isHealthy,
          );
        }
      }
    }

    Disease? find(bool Function(Disease) test) {
      for (final disease in diseases) {
        if (test(disease)) return disease;
      }
      return null;
    }

    switch (crop.id) {
      case 'onion':
        if (metrics.purpleRatio > 0.02) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id == 'onion_purple_blotch' ||
                    d.id == 'onion_alternaria') ??
                diseases.first,
            confidence: 0.94,
          );
        }
        if (metrics.yellowRatio > 0.1) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id == 'onion_downy_mildew' || d.id.contains('thrips')) ??
                diseases[1 % diseases.length],
            confidence: 0.88,
          );
        }
        if (metrics.darkRatio > 0.1) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id == 'onion_fusarium_rot' ||
                    d.id == 'onion_fusarium' ||
                    d.id == 'onion_neck_rot') ??
                diseases.first,
            confidence: 0.89,
          );
        }
        break;
      case 'maize':
        if (metrics.rustRatio > 0.08) {
          return _DiseaseEvaluation(
            disease: find((d) => d.id == 'maize_rust') ?? diseases.first,
            confidence: 0.93,
          );
        }
        if (metrics.yellowRatio > 0.1) {
          return _DiseaseEvaluation(
            disease:
                find((d) => d.id == 'maize_streak_virus') ?? diseases.first,
            confidence: 0.91,
          );
        }
        if (metrics.darkRatio > 0.1) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id.contains('blight') || d.id.contains('smut')) ??
                diseases.first,
            confidence: 0.89,
          );
        }
        return _DiseaseEvaluation(
          disease: find((d) =>
                  d.id.contains('armyworm') || d.id.contains('fall')) ??
              diseases.first,
          confidence: 0.86,
        );
      case 'tomato':
        if (metrics.yellowRatio > 0.12) {
          return _DiseaseEvaluation(
            disease: find((d) => d.id.contains('curl')) ?? diseases.first,
            confidence: 0.92,
          );
        }
        if (metrics.darkRatio > 0.08) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id.contains('blight') || d.id.contains('spot')) ??
                diseases.first,
            confidence: 0.91,
          );
        }
        break;
      case 'rice':
        if (metrics.darkRatio > 0.08) {
          return _DiseaseEvaluation(
            disease: find((d) => d.id.contains('blast')) ?? diseases.first,
            confidence: 0.91,
          );
        }
        if (metrics.yellowRatio > 0.1) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id.contains('mottle') || d.id.contains('blight')) ??
                diseases.first,
            confidence: 0.90,
          );
        }
        if (metrics.rustRatio > 0.08) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id.contains('brown_spot') || d.id.contains('spot')) ??
                diseases.first,
            confidence: 0.89,
          );
        }
        break;
      case 'soybeans':
        if (metrics.rustRatio > 0.08) {
          return _DiseaseEvaluation(
            disease: find((d) => d.id.contains('rust')) ?? diseases.first,
            confidence: 0.92,
          );
        }
        break;
      case 'cassava':
        if (metrics.yellowRatio > 0.1) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id.contains('mosaic') || d.id.contains('mite')) ??
                diseases.first,
            confidence: 0.91,
          );
        }
        if (metrics.darkRatio > 0.08) {
          return _DiseaseEvaluation(
            disease: find((d) =>
                    d.id.contains('blight') || d.id.contains('anthracnose')) ??
                diseases.first,
            confidence: 0.89,
          );
        }
        break;
      default:
        break;
    }

    return _DiseaseEvaluation(disease: diseases.first, confidence: 0.85);
  }
}

class _CropIdentification {
  const _CropIdentification({
    required this.crop,
    required this.confidence,
    required this.isConfident,
  });

  final Crop crop;
  final double confidence;
  final bool isConfident;
}

class _DiseaseEvaluation {
  const _DiseaseEvaluation({
    required this.disease,
    required this.confidence,
    this.isHealthy = false,
  });

  final Disease disease;
  final double confidence;
  final bool isHealthy;
}
