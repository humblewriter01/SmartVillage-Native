import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/soil_data.dart';
import '../models/soil.dart';
import '../services/soil_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Soil Health / Lafiyar Ƙasa.
/// Port of `SoilHealthScreen.tsx`: pH + moisture sliders evaluated against the
/// selected crop's envelope, with bilingual remediation advice.
class SoilHealthScreen extends StatefulWidget {
  const SoilHealthScreen({super.key});

  @override
  State<SoilHealthScreen> createState() => _SoilHealthScreenState();
}

class _SoilHealthScreenState extends State<SoilHealthScreen> {
  CropSoilRequirement _crop = cropSoilRequirements.first;
  double _ph = 6.4;
  double _moisture = 58;
  String _soilType = 'loamy';
  SoilConditionAdvice? _advice;

  @override
  void initState() {
    super.initState();
    _advice = SoilService.evaluate(
      cropId: _crop.cropId,
      ph: _ph,
      moisture: _moisture,
    );
  }

  void _evaluate() {
    setState(() {
      _advice = SoilService.evaluate(
        cropId: _crop.cropId,
        ph: _ph,
        moisture: _moisture,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final advice = _advice;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        SectionCard(
          title: hausa ? 'Auna Lafiyar Ƙasa' : 'Measure your soil',
          subtitle: hausa
              ? 'Zaɓi shuka, sannan shigar da pH da laima'
              : 'Pick the crop, then enter pH and moisture',
          accent: AppColors.soil,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.faint(AppColors.soil, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.terrain_outlined,
                color: AppColors.soil, size: 18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _crop.cropId,
                isExpanded: true,
                items: cropSoilRequirements
                    .map(
                      (requirement) => DropdownMenuItem<String>(
                        value: requirement.cropId,
                        child: Text(
                          '${requirement.emoji} ${requirement.displayName(hausa)}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  final requirement = soilRequirementById(value);
                  if (requirement == null) return;
                  setState(() {
                    _crop = requirement;
                    _ph = requirement.optimalPhMin;
                    _moisture = requirement.optimalMoistureMin;
                  });
                  _evaluate();
                },
                decoration: InputDecoration(
                  labelText: hausa ? 'Amfanin gona' : 'Crop',
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Text(
                    hausa ? 'Tsami (pH)' : 'Soil pH',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Pill(
                    label: _ph.toStringAsFixed(1),
                    color: AppColors.soil,
                    icon: Icons.science,
                  ),
                ],
              ),
              Slider(
                value: _ph,
                min: 3.5,
                max: 9,
                divisions: 55,
                activeColor: AppColors.soil,
                label: _ph.toStringAsFixed(1),
                onChanged: (value) => setState(() => _ph = value),
                onChangeEnd: (_) => _evaluate(),
              ),
              Row(
                children: <Widget>[
                  Text(
                    hausa ? 'Laima (%)' : 'Moisture (%)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Pill(
                    label: '${_moisture.round()}%',
                    color: AppColors.water,
                    icon: Icons.water_drop,
                  ),
                ],
              ),
              Slider(
                value: _moisture,
                min: 0,
                max: 100,
                divisions: 100,
                activeColor: AppColors.water,
                label: '${_moisture.round()}%',
                onChanged: (value) => setState(() => _moisture = value),
                onChangeEnd: (_) => _evaluate(),
              ),
              const SizedBox(height: 4),
              Text(
                hausa ? 'Nau\'in ƙasa' : 'Soil type',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <String>[
                  'sandy_loam',
                  'loamy',
                  'clay',
                  'sandy',
                ].map((type) {
                  return ChoiceChip(
                    selected: _soilType == type,
                    label: Text(
                      SoilService.soilTypeLabel(type, hausa),
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    onSelected: (_) => setState(() => _soilType = type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _evaluate,
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: Text(
                  hausa ? 'Bincika Ƙasa' : 'Evaluate soil',
                  style: const TextStyle(fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.soil,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _crop.localizedNotes(hausa),
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (advice != null) ...<Widget>[
          const SizedBox(height: 14),
          SectionCard(
            title: hausa ? 'Sakamakon Ƙasa' : 'Soil assessment',
            subtitle:
                '${SoilService.overallLabel(advice.overallRating, hausa)} · ${advice.overallScore}/100',
            accent: AppColors.soil,
            trailing: SpeakButton(
              compact: true,
              color: AppColors.soil,
              textBuilder: () =>
                  '${advice.phScoreText(hausa)}. ${advice.phAdvice(hausa)} '
                  '${advice.moistureText(hausa)}. ${advice.moistureAdvice(hausa)}',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: advice.overallScore / 100,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      advice.overallScore >= 70
                          ? AppColors.success
                          : advice.overallScore >= 50
                              ? AppColors.warning
                              : AppColors.danger,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InfoRow(
                  label: hausa ? 'Tsami' : 'pH status',
                  value: advice.phScoreText(hausa),
                ),
                Text(
                  advice.phAdvice(hausa),
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
                const Divider(height: 20),
                InfoRow(
                  label: hausa ? 'Laima' : 'Moisture',
                  value: advice.moistureText(hausa),
                ),
                Text(
                  advice.moistureAdvice(hausa),
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SectionCard(
          title: hausa ? 'Bukatun Kowace Shuka' : 'Crop requirements',
          accent: AppColors.soil,
          child: Column(
            children: cropSoilRequirements
                .map(
                  (requirement) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        Text(
                          requirement.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            requirement.displayName(hausa),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          'pH ${requirement.optimalPhMin.toStringAsFixed(1)}-${requirement.optimalPhMax.toStringAsFixed(1)}'
                          ' · ${requirement.optimalMoistureMin.round()}-${requirement.optimalMoistureMax.round()}%',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
