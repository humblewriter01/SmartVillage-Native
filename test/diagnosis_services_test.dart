import 'package:flutter_test/flutter_test.dart';
import 'package:smartvillage/services/crop_service.dart';
import 'package:smartvillage/services/health_service.dart';
import 'package:smartvillage/services/livestock_service.dart';
import 'package:smartvillage/services/planting_calendar_service.dart';
import 'package:smartvillage/services/soil_service.dart';

void main() {
  group('livestock weighted scoring', () {
    test('hallmark symptom gives a strong match', () {
      final result = LivestockService.diagnose(
        'chicken',
        <String>['Twisted neck / neurological signs'],
      );
      expect(result, isNotNull);
      expect(result!.hasMatch, isTrue);
      expect(result.likelyDisease, isNotNull);
      expect(
        result.likelyDisease!.name.toLowerCase(),
        contains('newcastle'),
      );
      expect(result.differentials.first.score, greaterThanOrEqualTo(50));
    });

    test('unknown symptoms never fabricate a diagnosis', () {
      final result = LivestockService.diagnose(
        'chicken',
        <String>['The bird is dancing salsa'],
      );
      expect(result, isNotNull);
      expect(result!.hasMatch, isFalse);
      expect(result.likelyDisease, isNull);
      expect(result.noMatchMessageEn, isNotEmpty);
    });

    test('empty selection returns null', () {
      expect(LivestockService.diagnose('goat', <String>[]), isNull);
      expect(LivestockService.diagnose('unknown-animal', <String>['x']), isNull);
    });

    test('scores are ordered and capped at 100', () {
      final result = LivestockService.diagnose('goat', <String>[
        'Sores & ulcers around mouth',
        'Foul watery diarrhea',
        'High fever & nasal discharge',
      ]);
      expect(result, isNotNull);
      for (var i = 1; i < result!.differentials.length; i++) {
        expect(
          result.differentials[i - 1].score,
          greaterThanOrEqualTo(result.differentials[i].score),
        );
      }
      expect(result.differentials.first.score, lessThanOrEqualTo(100));
      expect(result.differentials.length, lessThanOrEqualTo(3));
    });
  });

  group('crop diagnosis', () {
    test('manual selection returns the chosen disease', () {
      final result = CropService.diagnoseSelection(
        cropId: 'maize',
        suspectedDiseaseId: 'maize_rust',
      );
      expect(result.referenceDetail?.id, 'maize_rust');
      expect(result.cropId, 'maize');
      expect(result.topConfidence, greaterThan(0.9));
    });

    test('symptoms are scoped to the selected crop', () {
      final result = CropService.diagnoseBySymptoms(
        'ganye yana da tabo purple blotch',
        targetCropId: 'onion',
      );
      expect(result.cropId, 'onion');
      expect(
        result.predictions.first.label.startsWith('onion'),
        isTrue,
        reason: result.predictions.first.label,
      );
    });

    test('no crop mentioned asks for a manual selection', () {
      final result =
          CropService.diagnoseBySymptoms('the plant looks unwell today');
      expect(result.needsCropSelection, isTrue);
    });

    test('manual selection without a disease returns the crop assessment', () {
      final result = CropService.diagnoseSelection(cropId: 'tomato');
      expect(result.cropId, 'tomato');
      expect(result.predictions.first.label, isNotEmpty);
    });
  });

  group('human health triage', () {
    test('snakebite is recognised in Hausa', () {
      final result = HealthService.checkSymptoms(symptomsText: 'cizon maciji a kafa');
      expect(result.condition.toLowerCase(), contains('snakebite'));
      expect(result.urgency, isNotEmpty);
    });

    test('malaria symptoms map to malaria', () {
      final result = HealthService.checkSymptoms(
        symptomsText: 'zazzabi mai zafi da rawar sanyi',
      );
      expect(result.condition.toLowerCase(), contains('malaria'));
    });

    test('empty input asks for symptoms', () {
      final result = HealthService.checkSymptoms(symptomsText: '');
      expect(result.confidence, 0);
      expect(result.condition, contains('No Symptoms'));
    });

    test('manual condition lookup works', () {
      final result = HealthService.checkCondition('cholera_diarrhea');
      expect(result.conditionHausa, isNotEmpty);
      expect(result.firstAid, isNotNull);
    });
  });

  group('soil evaluation', () {
    test('optimal values score highly', () {
      final advice = SoilService.evaluate(cropId: 'maize', ph: 6.2, moisture: 60);
      expect(advice.phStatus, 'optimal');
      expect(advice.moistureStatus, 'optimal');
      expect(advice.overallScore, greaterThanOrEqualTo(90));
      expect(advice.overallRating, 'excellent');
    });

    test('acid soil is flagged with remedies', () {
      final advice =
          SoilService.evaluate(cropId: 'soybeans', ph: 4.8, moisture: 40);
      expect(advice.phStatus, 'strongly_acidic');
      expect(advice.phAdviceEn.toLowerCase(), contains('lime'));
      expect(advice.phAdviceHa, isNotEmpty);
    });

    test('waterlogging is ignored for rice', () {
      final rice = SoilService.evaluate(cropId: 'rice', ph: 6.0, moisture: 88);
      final maize =
          SoilService.evaluate(cropId: 'maize', ph: 6.0, moisture: 88);
      expect(rice.moistureStatus, 'optimal');
      expect(maize.moistureStatus, 'waterlogged');
    });
  });

  group('planting calendar', () {
    test('month windows wrap around December', () {
      expect(PlantingCalendarService.isMonthInWindow(1, 11, 2), isTrue);
      expect(PlantingCalendarService.isMonthInWindow(6, 11, 2), isFalse);
    });

    test('season detection', () {
      expect(PlantingCalendarService.currentSeason(7).name, contains('Rainy'));
      expect(
        PlantingCalendarService.currentSeason(12).harmattanWarning,
        isTrue,
      );
    });

    test('recommendations cover every crop', () {
      final recommendations =
          PlantingCalendarService.recommendationsFor(DateTime(2026, 11, 15));
      expect(recommendations.length, 13);
    });
  });
}
