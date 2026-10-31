import 'package:flutter_test/flutter_test.dart';
import 'package:smartvillage/data/calendar_data.dart';
import 'package:smartvillage/data/crop_data.dart';
import 'package:smartvillage/data/health_data.dart';
import 'package:smartvillage/data/knowledge_data.dart';
import 'package:smartvillage/data/livestock_data.dart';
import 'package:smartvillage/data/map_data.dart';
import 'package:smartvillage/data/soil_data.dart';
import 'package:smartvillage/data/translations_data.dart';

void main() {
  group('crop library', () {
    test('ships 13 crops', () {
      expect(cropReferenceData.length, 13);
    });

    test('ships 69 diseases', () {
      final total = cropReferenceData
          .fold<int>(0, (sum, crop) => sum + crop.diseases.length);
      expect(total, 69);
    });

    test('every crop has at least one healthy reference and bilingual copy', () {
      for (final crop in cropReferenceData) {
        expect(crop.diseases, isNotEmpty, reason: crop.id);
        expect(crop.hausaName, isNotEmpty, reason: crop.id);
        expect(crop.descriptionHausa, isNotEmpty, reason: crop.id);
        for (final disease in crop.diseases) {
          expect(disease.name, isNotEmpty);
          expect(disease.hausaName, isNotEmpty);
          expect(disease.treatment, isNotEmpty);
          expect(disease.treatmentHausa, isNotEmpty);
        }
      }
    });

    test('lookup helpers work', () {
      expect(cropById('onion')?.crop, 'Onion');
      expect(cropById('does-not-exist'), isNull);
      expect(diseaseById('maize_rust')?.name, contains('Rust'));
      expect(cropForDisease('maize_rust')?.id, 'maize');
    });
  });

  group('livestock library', () {
    test('ships 9 animals', () {
      expect(livestockAnimals.length, 9);
    });

    test('every animal has symptoms in both languages', () {
      for (final animal in livestockAnimals) {
        expect(animal.commonSymptoms, isNotEmpty, reason: animal.id);
        expect(
          animal.commonSymptomsHausa.length,
          animal.commonSymptoms.length,
          reason: animal.id,
        );
      }
    });

    test('ship 36 diseases and every one belongs to a known animal', () {
      expect(livestockDiseases.length, 36);
      for (final disease in livestockDiseases) {
        expect(animalById(disease.animalId), isNotNull, reason: disease.id);
        expect(disease.weightedSymptoms, isNotEmpty, reason: disease.id);
        for (final weighted in disease.weightedSymptoms) {
          expect(weighted.weight, inInclusiveRange(1, 3));
        }
      }
    });
  });

  group('health, calendar, knowledge, soil, map', () {
    test('10 human health conditions', () {
      expect(manualHealthConditions.length, 10);
      for (final condition in manualHealthConditions) {
        expect(condition.firstAid, isNotEmpty);
        expect(condition.firstAidHausa, isNotEmpty);
        expect(condition.dangerSigns, isNotEmpty);
      }
    });

    test('13 crop calendars with planting windows', () {
      expect(cropCalendar.length, 13);
      for (final crop in cropCalendar) {
        expect(crop.plantingWindows, isNotEmpty, reason: crop.id);
        expect(crop.harvestEndMonth, inInclusiveRange(1, 12), reason: crop.id);
        expect(crop.harvestStartMonth, inInclusiveRange(1, 12), reason: crop.id);
        expect(crop.carePeriodWeeks, greaterThan(0), reason: crop.id);
        expect(crop.carePeriodWeeks, lessThanOrEqualTo(12), reason: crop.id);
      }
    });

    test('knowledge base and disease monographs', () {
      expect(knowledgeItems.length, 35);
      expect(diseaseDetails.length, 17);
      expect(cropLabels.length, 20);
    });

    test('9 soil envelopes', () {
      expect(cropSoilRequirements.length, 9);
      for (final requirement in cropSoilRequirements) {
        expect(requirement.optimalPhMin, lessThanOrEqualTo(requirement.optimalPhMax));
        expect(
          requirement.optimalMoistureMin,
          lessThanOrEqualTo(requirement.optimalMoistureMax),
        );
      }
    });

    test('seed map pins are inside Nigeria', () {
      expect(initialCommunityPins, isNotEmpty);
      for (final pin in initialCommunityPins) {
        expect(pin.latitude, inInclusiveRange(4.0, 14.0));
        expect(pin.longitude, inInclusiveRange(2.0, 15.0));
      }
    });
  });

  group('translations', () {
    test('English and Hausa expose the same keys', () {
      final en = appTranslations['en']!;
      final ha = appTranslations['ha']!;
      expect(en.length, ha.length);
      for (final key in en.keys) {
        expect(ha.containsKey(key), isTrue, reason: key);
        expect(ha[key], isNotEmpty, reason: key);
      }
    });

    test('core labels exist', () {
      final en = appTranslations['en']!;
      for (final key in <String>[
        'appName',
        'home',
        'crop',
        'health',
        'livestock',
        'water',
      ]) {
        expect(en.containsKey(key), isTrue, reason: key);
      }
    });
  });
}
