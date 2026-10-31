/// Human health triage models.
///
/// Mirrors `src/services/healthService.ts`
/// (`ManualHealthCondition`, `HealthResult`).
library;

enum HealthCategory { infectious, respiratory, emergency, environmental, skin }

enum Urgency { critical, high, moderate, mild }

class ManualHealthCondition {
  const ManualHealthCondition({
    required this.id,
    required this.condition,
    required this.conditionHausa,
    required this.category,
    required this.urgency,
    required this.urgencyLabel,
    required this.urgencyLabelHausa,
    required this.symptoms,
    required this.symptomsHausa,
    required this.firstAid,
    required this.firstAidHausa,
    required this.clinicalAdvice,
    required this.clinicalAdviceHausa,
    required this.dangerSigns,
    required this.dangerSignsHausa,
  });

  final String id;
  final String condition;
  final String conditionHausa;
  final HealthCategory category;
  final Urgency urgency;
  final String urgencyLabel;
  final String urgencyLabelHausa;
  final String symptoms;
  final String symptomsHausa;
  final String firstAid;
  final String firstAidHausa;
  final String clinicalAdvice;
  final String clinicalAdviceHausa;
  final String dangerSigns;
  final String dangerSignsHausa;

  String displayName(bool hausa) => hausa ? conditionHausa : condition;
  String localizedUrgency(bool hausa) =>
      hausa ? urgencyLabelHausa : urgencyLabel;
  String localizedSymptoms(bool hausa) => hausa ? symptomsHausa : symptoms;
  String localizedFirstAid(bool hausa) => hausa ? firstAidHausa : firstAid;
  String localizedClinicalAdvice(bool hausa) =>
      hausa ? clinicalAdviceHausa : clinicalAdvice;
  String localizedDangerSigns(bool hausa) =>
      hausa ? dangerSignsHausa : dangerSigns;
}

class HealthResult {
  const HealthResult({
    required this.condition,
    required this.conditionHausa,
    required this.advice,
    required this.adviceHausa,
    required this.urgency,
    required this.urgencyHausa,
    required this.confidence,
    this.firstAid,
    this.firstAidHausa,
  });

  final String condition;
  final String conditionHausa;
  final String advice;
  final String adviceHausa;
  final String urgency;
  final String urgencyHausa;
  final double confidence;
  final String? firstAid;
  final String? firstAidHausa;

  String displayCondition(bool hausa) => hausa ? conditionHausa : condition;
  String displayAdvice(bool hausa) => hausa ? adviceHausa : advice;
  String displayUrgency(bool hausa) => hausa ? urgencyHausa : urgency;
}
