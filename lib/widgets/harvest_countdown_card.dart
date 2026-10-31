import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/harvest_service.dart';
import '../state/app_state.dart';
import 'section_card.dart';
import 'speak_button.dart';

/// Home-screen harvest countdown.
///
/// Port of `HomeHarvestCountdown.tsx`: shows every planted crop with days
/// elapsed / remaining, a progress bar, the current growth stage and the
/// crop-specific "harvest readiness" tip, plus a quick-add sheet.
class HarvestCountdownCard extends StatelessWidget {
  const HarvestCountdownCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final plantings = state.plantings;

    return SectionCard(
      title: hausa ? 'Ƙididdigar Kwanakin Girbi' : 'Harvest Countdown',
      subtitle: hausa
          ? 'Bibiyar kwanakin da suka rage kafin girbi'
          : 'Days left to harvest, growth stage & readiness signs',
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.faint(AppColors.calendar, 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.timelapse, color: AppColors.calendar, size: 18),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SpeakButton(
            compact: true,
            color: AppColors.calendar,
            textBuilder: () => hausa
                ? 'Ƙididdigar Kwanakin Girbi. Bibiyar kwanakin da suka rage kafin girbin albasa, masara, da sauran amfanin gona.'
                : 'Harvest Countdown. Track days left to harvest, maturity stages and readiness signs.',
          ),
          IconButton(
            onPressed: () => _openAddSheet(context),
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.primary, size: 22),
            tooltip: hausa ? 'Ƙara sabon shuka' : 'Add planting',
          ),
        ],
      ),
      child: plantings.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                hausa
                    ? 'Babu shukar da aka yi rajista. Danna + don ƙara.'
                    : 'No plantings tracked yet. Tap + to add one.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : Column(
              children: plantings
                  .take(3)
                  .map((crop) => _PlantingRow(crop: crop, hausa: hausa))
                  .toList(growable: false),
            ),
    );
  }

  static Future<void> _openAddSheet(BuildContext context) async {
    final state = AppScope.read(context);
    final hausa = state.isHausa;

    String selectedCropId = HarvestService.presets.first.cropId;
    DateTime plantingDate = DateTime.now();
    final labelController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hausa ? 'Ƙara Sabon Shuka' : 'Add a New Planting',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCropId,
                    items: HarvestService.presets
                        .map(
                          (preset) => DropdownMenuItem<String>(
                            value: preset.cropId,
                            child: Text(
                              '${preset.displayName(hausa)} · ${preset.maturityDays} ${hausa ? 'kwanaki' : 'days'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedCropId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(
                      labelText: hausa ? 'Sunan Gona' : 'Field name',
                      hintText: hausa ? 'Gonar Fadama' : 'Fadama plot',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: plantingDate,
                        firstDate: DateTime.now()
                            .subtract(const Duration(days: 365)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => plantingDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      '${hausa ? 'Ranar shuka' : 'Planting date'}: '
                      '${DateUtilsX.formatShortDate(plantingDate, hausa)}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: () {
                      final preset = HarvestService.presetFor(selectedCropId) ??
                          HarvestService.presets.first;
                      state.addPlanting(
                        PlantedCrop(
                          id: 'crop-${DateTime.now().millisecondsSinceEpoch}',
                          cropId: preset.cropId,
                          name: preset.name,
                          hausaName: preset.hausaName,
                          fieldLabel: labelController.text.trim().isEmpty
                              ? '${preset.hausaName} (${preset.name})'
                              : labelController.text.trim(),
                          plantingDate: plantingDate,
                          maturityDays: preset.maturityDays,
                          criticalTipsEn: preset.criticalTipsEn,
                          criticalTipsHa: preset.criticalTipsHa,
                        ),
                      );
                      Navigator.of(sheetContext).pop();
                    },
                    child: Text(hausa ? 'Adana Shuka' : 'Save planting'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlantingRow extends StatelessWidget {
  const _PlantingRow({required this.crop, required this.hausa});

  final PlantedCrop crop;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final status = HarvestService.status(crop);
    final state = AppScope.of(context);
    final ready = status.isHarvestReady;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ready
            ? AppColors.faint(AppColors.success, 0.07)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready
              ? AppColors.faint(AppColors.success, 0.35)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${crop.displayName(hausa)} · ${crop.fieldLabel}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ready
                          ? (hausa ? 'Lokacin girbi ya yi!' : 'Harvest ready!')
                          : '${status.daysRemaining} ${hausa ? 'kwanaki sun rage' : 'days remaining'}'
                              ' · ${status.stage(hausa)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ready ? AppColors.success : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SpeakButton(
                compact: true,
                color: AppColors.primary,
                textBuilder: () => hausa
                    ? 'Ƙididdigar girbin ${crop.hausaName}: Kwanaki ${status.daysRemaining} suka rage kafin girbi. Kashi ${status.progressPercent} na girman shuka ya cika. Mataki: ${status.stageHa}. Shawara: ${crop.criticalTipsHa}'
                    : 'Harvest countdown for ${crop.name}: ${status.daysRemaining} days remaining until harvest. ${status.progressPercent}% maturity reached. Stage: ${status.stageEn}. Note: ${crop.criticalTipsEn}',
              ),
              IconButton(
                onPressed: () => state.removePlanting(crop.id),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.textMuted),
                tooltip: hausa ? 'Goge' : 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: status.progressPercent / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                ready ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Text(
                '${status.progressPercent}%',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                DateUtilsX.formatShortDate(status.harvestDate, hausa),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '💡 ${crop.tip(hausa)}',
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
