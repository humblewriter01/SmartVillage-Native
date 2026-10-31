import 'package:flutter_test/flutter_test.dart';
import 'package:smartvillage/data/livestock_data.dart';
import 'package:smartvillage/models/livestock.dart';
import 'package:smartvillage/services/livestock_service.dart';

void main() {
  Animal animal(String id) =>
      livestockAnimals.firstWhere((Animal a) => a.id == id);

  AnimalDisease disease(String id) =>
      livestockDiseases.firstWhere((AnimalDisease d) => d.id == id);

  group('disease symptoms', () {
    test('English keeps the canonical symptom keys', () {
      final Animal chicken = animal('chicken');
      final AnimalDisease newcastle = disease('newcastle_chicken');
      expect(
        newcastle.localizedSymptoms(chicken, false),
        newcastle.keySymptoms.join(', '),
      );
    });

    test('Hausa resolves through the animal vocabulary by position', () {
      // The dataset never translated disease symptoms separately; every key is
      // one of the animal's bilingual symptoms, so the Hausa text is the
      // animal's Hausa label at the same index.
      final Animal chicken = animal('chicken');
      final AnimalDisease newcastle = disease('newcastle_chicken');
      expect(
        newcastle.localizedSymptoms(chicken, true),
        'Lankwasa wuya ko juyawar kai, Numfashi mai sautin gurnani, '
        'Gudawa mai launin kore ko jini, Mutuwar kaji ba gaira ba dalili, '
        'Ragewar kwayayen kwai',
      );
    });

    test('every disease resolves every symptom in both languages', () {
      for (final AnimalDisease d in livestockDiseases) {
        final Animal owner = animal(d.animalId);
        for (final String symptom in d.keySymptoms) {
          expect(
            owner.commonSymptoms.contains(symptom),
            isTrue,
            reason: '${d.id}: "$symptom" is not one of ${owner.id} symptoms',
          );
        }
        final String hausaText = d.localizedSymptoms(owner, true);
        expect(hausaText, isNotEmpty, reason: d.id);
        // Nothing may fall back to the English key in Hausa mode.
        for (final String symptom in d.keySymptoms) {
          expect(
            hausaText.contains(symptom),
            isFalse,
            reason: '${d.id}: "${symptom}" was not translated',
          );
        }
      }
    });

    test('symptomLabel agrees with the service helper', () {
      final Animal chicken = animal('chicken');
      final String symptom = chicken.commonSymptoms.first;
      expect(
        chicken.symptomLabel(0, true),
        LivestockService.symptomLabel('chicken', symptom, true),
      );
    });

    test('unknown symptom text is passed through untouched', () {
      final Animal chicken = animal('chicken');
      final AnimalDisease custom = AnimalDisease(
        id: 'custom',
        animalId: 'chicken',
        name: 'Custom',
        hausaName: 'Na musamman',
        keySymptoms: const <String>['Not in the animal list'],
        weightedSymptoms: const <SymptomWeight>[],
        causes: 'c',
        causesHausa: 'c',
        treatment: 't',
        treatmentHausa: 't',
        prevention: 'p',
        preventionHausa: 'p',
        isUrgentContagious: false,
      );
      expect(
        custom.localizedSymptoms(chicken, true),
        'Not in the animal list',
      );
    });
  });
}
