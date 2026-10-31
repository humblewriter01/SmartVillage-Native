import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/livestock_data.dart';
import '../models/livestock.dart';
import '../services/history_service.dart';
import '../services/livestock_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Livestock / Dabbobi — weighted symptom checker for 9 animals.
/// Port of `LivestockScreen.tsx`.
class LivestockScreen extends StatefulWidget {
  const LivestockScreen({super.key});

  @override
  State<LivestockScreen> createState() => _LivestockScreenState();
}

class _LivestockScreenState extends State<LivestockScreen> {
  Animal _animal = livestockAnimals.first;
  final Set<String> _selected = <String>{};
  LivestockCheckResult? _result;

  void _selectAnimal(Animal animal) {
    setState(() {
      _animal = animal;
      _selected.clear();
      _result = null;
    });
  }

  void _toggle(String symptom) {
    setState(() {
      if (_selected.contains(symptom)) {
        _selected.remove(symptom);
      } else {
        _selected.add(symptom);
      }
      _result = null;
    });
  }

  Future<void> _diagnose() async {
    final state = AppScope.read(context);
    final result = LivestockService.diagnose(_animal.id, _selected.toList());
    setState(() => _result = result);

    if (result != null && result.hasMatch && result.likelyDisease != null) {
      await state.recordHistory(
        type: HistoryType.livestock,
        title: '${_animal.name} · ${result.likelyDisease!.name}',
        detail: result.likelyDisease!.treatment,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        SectionHeader(
          title: state.t('selectAnimalPrompt'),
          subtitle: hausa
              ? 'Dabbobi 9 da kaji — bincike mai nauyi (weighted scoring)'
              : '9 livestock & poultry species — weighted symptom scoring',
          icon: Icons.pets,
          accent: AppColors.livestock,
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: livestockAnimals.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final animal = livestockAnimals[index];
              final selected = animal.id == _animal.id;
              return GestureDetector(
                onTap: () => _selectAnimal(animal),
                child: Container(
                  width: 82,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.faint(AppColors.livestock, 0.12) : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.livestock
                          : const Color(0xFFE2E8F0),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(animal.emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(height: 4),
                      Text(
                        animal.displayName(hausa),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.15,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? AppColors.livestock
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SectionHeader(
          title: state.t('symptomsChecklist'),
          icon: Icons.fact_check_outlined,
          accent: AppColors.livestock,
          trailing: TextButton(
            onPressed: () => setState(() {
              _selected.clear();
              _result = null;
            }),
            child: Text(
              hausa ? 'Share' : 'Clear',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        ..._animal.commonSymptoms.asMap().entries.map((entry) {
          final index = entry.key;
          final symptom = entry.value;
          final checked = _selected.contains(symptom);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => _toggle(symptom),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: checked
                      ? AppColors.faint(AppColors.livestock, 0.09)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: checked
                        ? AppColors.faint(AppColors.livestock, 0.5)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Checkbox(
                      value: checked,
                      onChanged: (_) => _toggle(symptom),
                      activeColor: AppColors.livestock,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        _animal.symptomLabel(index, hausa),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight:
                              checked ? FontWeight.w700 : FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SpeakButton(
                      compact: true,
                      color: AppColors.textMuted,
                      textBuilder: () => _animal.symptomLabel(index, hausa),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _selected.isEmpty ? null : _diagnose,
          icon: const Icon(Icons.medical_services_outlined, size: 18),
          label: Text(
            '${state.t('diagnoseAnimal')} (${_selected.length})',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.livestock,
          ),
        ),
        if (_result != null) ...<Widget>[
          const SizedBox(height: 14),
          _LivestockResult(result: _result!, hausa: hausa),
        ],
        const SizedBox(height: 14),
        Text(
          hausa
              ? 'Wannan bincike ne na taimako kawai. Tuntuɓi likitan dabbobi kafin ka sha magani ko allura.'
              : 'This is a field aid only. Always confirm with a veterinarian before dosing or vaccinating.',
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.45,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _LivestockResult extends StatelessWidget {
  const _LivestockResult({required this.result, required this.hausa});

  final LivestockCheckResult result;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    if (!result.hasMatch) {
      return SectionCard(
        title: state.t('noMatchingDiseaseTitle'),
        accent: AppColors.warning,
        leading: const Icon(Icons.help_outline, color: AppColors.warning),
        child: Text(
          hausa
              ? result.noMatchMessageHa ?? state.t('noMatchingDiseaseDesc')
              : result.noMatchMessageEn ?? state.t('noMatchingDiseaseDesc'),
          style: const TextStyle(fontSize: 12.5, height: 1.45),
        ),
      );
    }

    final disease = result.likelyDisease!;
    final score = (result.confidence * 100).round();

    return Column(
      children: <Widget>[
        SectionCard(
          title: state.t('livestockResult'),
          subtitle: disease.displayName(hausa),
          accent: AppColors.livestock,
          leading: Text(
            result.animal.emoji,
            style: const TextStyle(fontSize: 26),
          ),
          trailing: SpeakButton(
            compact: true,
            color: AppColors.livestock,
            textBuilder: () =>
                '${disease.displayName(hausa)}. ${disease.localizedSymptoms(hausa)} '
                '${disease.localizedTreatment(hausa)} ${disease.localizedPrevention(hausa)}',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Pill(
                    label: '${state.t('confidence')}: $score%',
                    color: score >= 80 ? AppColors.success : AppColors.warning,
                    icon: Icons.speed,
                  ),
                  const SizedBox(width: 6),
                  Pill(
                    label: LivestockService.strengthLabel(
                      result.differentials.first.matchStrength,
                      hausa,
                    ),
                    color: AppColors.livestock,
                  ),
                ],
              ),
              if (disease.isUrgentContagious) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.faint(AppColors.danger, 0.09),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.faint(AppColors.danger, 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.t('quarantineWarning'),
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 20),
              InfoRow(
                label: state.t('matchedSymptomsLabel'),
                value: result.matchedSymptoms
                    .map((s) =>
                        LivestockService.symptomLabel(result.animal.id, s, hausa))
                    .join(', '),
              ),
              InfoRow(
                label: state.t('causes'),
                value: disease.localizedCauses(hausa),
              ),
              InfoRow(
                label: state.t('symptoms'),
                value: disease.localizedSymptoms(hausa),
              ),
              InfoRow(
                label: state.t('treatment'),
                value: disease.localizedTreatment(hausa),
                valueColor: AppColors.success,
              ),
              InfoRow(
                label: state.t('preventionTips'),
                value: disease.localizedPrevention(hausa),
                valueColor: AppColors.info,
              ),
              const SizedBox(height: 6),
              Text(
                state.t('consultVetNotice'),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (result.differentials.length > 1) ...<Widget>[
          const SizedBox(height: 12),
          SectionCard(
            title: state.t('differentialDiagnosesTitle'),
            subtitle: state.t('differentialDiagnosesSubtitle'),
            accent: AppColors.warning,
            child: Column(
              children: result.differentials
                  .skip(1)
                  .map(
                    (match) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              match.disease.displayName(hausa),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Pill(
                            label: '${match.score}%',
                            color: match.score >= 80
                                ? AppColors.success
                                : match.score >= 50
                                    ? AppColors.warning
                                    : AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}
