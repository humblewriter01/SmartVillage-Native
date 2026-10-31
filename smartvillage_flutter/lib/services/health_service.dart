import '../data/health_data.dart';
import '../models/health_condition.dart';

/// Human symptom triage.
///
/// Port of `healthService.checkSymptoms()` from the React blueprint: a
/// deterministic, offline rule chain (never a fabricated AI diagnosis) that
/// maps spoken/typed symptoms — English **or** Hausa — onto one of the
/// documented conditions, and otherwise returns generic guidance.
class HealthService {
  const HealthService._();

  static List<ManualHealthCondition> get conditions => manualHealthConditions;

  static ManualHealthCondition? condition(String id) =>
      healthConditionById(id);

  static HealthResult checkSymptoms({
    required String symptomsText,
    bool hasPhoto = false,
  }) {
    final query = symptomsText.toLowerCase().trim();

    if (query.isNotEmpty) {
      HealthResult? matched;

      // 1. Snakebite / animal bite
      if (_has(query, <String>['snake', 'maciji', 'viper', 'cobra', 'bitten'])) {
        matched = _fromCondition('snakebite', 0.95);
      }
      // 2. Cholera / acute watery diarrhea
      else if (_has(query, <String>['cholera', 'kwalara']) ||
          (_has(query, <String>['diarrhea', 'diarrhoea', 'gudawa', 'zawo']) &&
              _has(query, <String>['watery', 'ruwa', 'vomit', 'amai']))) {
        matched = _fromCondition('cholera_diarrhea', 0.92);
      }
      // 3. Meningitis
      else if (_has(query, <String>['sankarau']) ||
          (_has(query, <String>['stiff', 'tauri']) &&
              _has(query, <String>['neck', 'wuya']))) {
        matched = _fromCondition('meningitis', 0.94);
      }
      // 4. Measles
      else if (_has(query, <String>['measles', 'kyanda']) ||
          (_has(query, <String>['red eyes', 'idon', 'ido']) &&
              _has(query, <String>['rash', 'kuraje']))) {
        matched = _fromCondition('measles', 0.91);
      }
      // 5. Pneumonia / fast breathing
      else if (_has(query, <String>[
        'pneumonia',
        'numfashi',
        'kirji',
        'breath',
        'chest',
      ])) {
        matched = _fromCondition('pneumonia', 0.89);
      }
      // 6. Heat exhaustion / sunstroke
      else if (_has(query, <String>[
        'sunstroke',
        'zafin rana',
        'heat',
        'rana',
        'faint',
        'jiri',
        'suma',
      ])) {
        matched = _fromCondition('heat_exhaustion', 0.87);
      }
      // 7. Typhoid
      else if (_has(query, <String>['typhoid', 'taifot']) ||
          (_has(query, <String>['fever', 'zazzabi']) &&
              _has(query, <String>['belly', 'ciki', 'abdomen']))) {
        matched = _fromCondition('typhoid_fever', 0.88);
      }
      // 8. Malaria / general fever
      else if (_has(query, <String>[
        'malaria',
        'fever',
        'chill',
        'zazzabi',
        'sanyi',
        'sauro',
      ])) {
        matched = _fromCondition('malaria', 0.90);
      }
      // 9. Skin rash / scabies
      else if (_has(query, <String>[
        'scabies',
        'makero',
        'rash',
        'itch',
        'kaikayi',
        'kurji',
        'fata',
      ])) {
        matched = _fromCondition('scabies_skin', 0.86);
      }

      if (matched != null) return matched;

      return HealthResult(
        condition: 'Health Symptoms Require Review',
        conditionHausa: 'Alamomin suna Bukatar Duban Likita',
        advice: 'You reported: "$symptomsText". Keep hydrated with clean water, '
            'note when symptoms started, and visit the nearest health '
            'dispensary for examination.',
        adviceHausa: 'Ka faɗi cewa: "$symptomsText". Sha ruwa mai tsafta sosai, '
            'rubuta ranar da matsalar ta fara, kuma garzaya asibitin kusa '
            'domin dubawa.',
        urgency: 'Visit Local Clinic or Health Post',
        urgencyHausa: 'Je Asibiti ko Wurin Shan Magani na Kusa',
        confidence: 0.70,
      );
    }

    if (hasPhoto) {
      return const HealthResult(
        condition: 'Visible Skin or Health Observation',
        conditionHausa: 'Duba Matsalar Fata ko Kurji',
        advice: 'Keep affected skin clean and dry with mild soap. Avoid '
            'scratching or applying motor oil/battery acid remedies. Have a '
            'health worker inspect in person.',
        adviceHausa: 'Wanke wurin da ruwa mai tsabta da sabulu marar zafi. '
            'Kada a shafa man inji ko maganin da ba a sani ba. Nemi likita ya duba.',
        urgency: 'Clinical Review Recommended',
        urgencyHausa: 'A Nemi Likita ya Duba a Asibiti',
        confidence: 0.75,
      );
    }

    return const HealthResult(
      condition: 'No Symptoms Provided',
      conditionHausa: 'Babu Alamomin da aka Bayyana',
      advice: 'Please describe symptoms using voice or select a health '
          'condition manually.',
      adviceHausa: 'Da fatan za a faɗi alamomin rashin lafiya da murya ko '
          'zaɓi da kanka.',
      urgency: 'Routine',
      urgencyHausa: 'Babu Gaggawa',
      confidence: 0.0,
    );
  }

  /// Result for a condition chosen from the manual picker.
  static HealthResult checkCondition(String conditionId) {
    final match = healthConditionById(conditionId);
    if (match == null) return checkSymptoms(symptomsText: '');
    return _build(match, 0.93);
  }

  static bool _has(String query, List<String> keywords) =>
      keywords.any((keyword) => query.contains(keyword));

  static HealthResult? _fromCondition(String id, double confidence) {
    final match = healthConditionById(id);
    if (match == null) return null;
    return _build(match, confidence);
  }

  static HealthResult _build(ManualHealthCondition match, double confidence) =>
      HealthResult(
        condition: match.condition,
        conditionHausa: match.conditionHausa,
        advice: '${match.firstAid} ${match.clinicalAdvice}',
        adviceHausa: '${match.firstAidHausa} ${match.clinicalAdviceHausa}',
        urgency: match.urgencyLabel,
        urgencyHausa: match.urgencyLabelHausa,
        confidence: confidence,
        firstAid: match.firstAid,
        firstAidHausa: match.firstAidHausa,
      );

  static String categoryLabel(HealthCategory category, bool hausa) {
    switch (category) {
      case HealthCategory.infectious:
        return hausa ? 'Cututtuka masu yaduwa' : 'Infectious';
      case HealthCategory.respiratory:
        return hausa ? 'Numfashi' : 'Respiratory';
      case HealthCategory.emergency:
        return hausa ? 'Gaggawa' : 'Emergency';
      case HealthCategory.environmental:
        return hausa ? 'Yanayi da Zafi' : 'Environmental';
      case HealthCategory.skin:
        return hausa ? 'Fata' : 'Skin';
    }
  }
}
