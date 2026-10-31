import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/health_data.dart';
import '../models/health_condition.dart';
import '../services/health_service.dart';
import '../services/history_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Health / Lafiya — human symptom triage.
/// Port of `HealthScreen.tsx`.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final TextEditingController _controller = TextEditingController();
  HealthResult? _result;
  ManualHealthCondition? _selectedCondition;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final text = _controller.text.trim();
    final state = AppScope.read(context);

    if (text.isEmpty && _selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.t('symptomsHint'))),
      );
      return;
    }

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final result = _selectedCondition != null
        ? HealthService.checkCondition(_selectedCondition!.id)
        : HealthService.checkSymptoms(symptomsText: text);

    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });

    await state.recordHistory(
      type: HistoryType.health,
      title: result.displayCondition(state.isHausa),
      detail: result.displayAdvice(state.isHausa),
    );
  }

  Future<void> _pickCondition(bool hausa) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        maxChildSize: 0.94,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: <Widget>[
            Text(
              AppScope.read(context).t('manualHealthTitle'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            ...manualHealthConditions.map(
              (condition) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: _urgencyColor(condition.urgency).withAlpha(28),
                  child: Icon(
                    _urgencyIcon(condition.urgency),
                    size: 16,
                    color: _urgencyColor(condition.urgency),
                  ),
                ),
                title: Text(
                  condition.displayName(hausa),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  condition.localizedUrgency(hausa),
                  style: const TextStyle(fontSize: 10.5),
                ),
                onTap: () {
                  setState(() {
                    _selectedCondition = condition;
                    _controller.text = condition.localizedSymptoms(hausa);
                    _result = null;
                  });
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _urgencyColor(Urgency urgency) {
    switch (urgency) {
      case Urgency.critical:
        return AppColors.danger;
      case Urgency.high:
        return AppColors.warning;
      case Urgency.moderate:
        return AppColors.info;
      case Urgency.mild:
        return AppColors.success;
    }
  }

  static IconData _urgencyIcon(Urgency urgency) {
    switch (urgency) {
      case Urgency.critical:
        return Icons.emergency;
      case Urgency.high:
        return Icons.priority_high;
      case Urgency.moderate:
        return Icons.info_outline;
      case Urgency.mild:
        return Icons.check;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        SectionCard(
          title: hausa ? 'Bayyana Alamomin Lafiya' : 'Describe your symptoms',
          subtitle: hausa
              ? 'Rubuta ko faɗi da murya — Turanci ko Hausa'
              : 'Type or speak — English or Hausa are both understood',
          accent: AppColors.health,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.faint(AppColors.health, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.health_and_safety_outlined,
                color: AppColors.health, size: 18),
          ),
          child: Column(
            children: <Widget>[
              TextField(
                controller: _controller,
                maxLines: 4,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: state.t('healthSpeechHint'),
                  hintStyle: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final text = _controller.text.trim();
                        if (text.isEmpty) return;
                        state.speak(text);
                      },
                      icon: const Icon(Icons.volume_up_outlined, size: 16),
                      label: Text(
                        hausa ? 'Karanta' : 'Read aloud',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickCondition(hausa),
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: Text(
                        hausa ? 'Zaɓi da Hannu' : 'Pick condition',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _busy ? null : _check,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 18),
                label: Text(
                  hausa ? 'Duba Lafiya' : 'Check symptoms',
                  style: const TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.health,
                ),
              ),
            ],
          ),
        ),
        if (_selectedCondition != null) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Pill(
                label: _selectedCondition!.displayName(hausa),
                color: AppColors.health,
                icon: Icons.local_hospital,
              ),
              const SizedBox(width: 6),
              Pill(
                label: _selectedCondition!.localizedUrgency(hausa),
                color: _urgencyColor(_selectedCondition!.urgency),
                icon: _urgencyIcon(_selectedCondition!.urgency),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _selectedCondition = null),
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
        if (_result != null) ...<Widget>[
          const SizedBox(height: 14),
          _HealthResultPanel(result: _result!, hausa: hausa),
        ],
        const SizedBox(height: 14),
        SectionCard(
          title: state.t('chooseCondition'),
          subtitle: hausa
              ? 'Danna kowace cuta don ganin taimakon farko'
              : 'Tap a condition to see first aid & clinical advice',
          accent: AppColors.health,
          child: Column(
            children: manualHealthConditions
                .map(
                  (condition) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _urgencyIcon(condition.urgency),
                      size: 16,
                      color: _urgencyColor(condition.urgency),
                    ),
                    title: Text(
                      condition.displayName(hausa),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      HealthService.categoryLabel(condition.category, hausa),
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => _ConditionDialog(
                        condition: condition,
                        hausa: hausa,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.faint(AppColors.warning, 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.faint(AppColors.warning, 0.3)),
          ),
          child: Text(
            state.t('notMedical'),
            style: const TextStyle(fontSize: 10.5, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _HealthResultPanel extends StatelessWidget {
  const _HealthResultPanel({required this.result, required this.hausa});

  final HealthResult result;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final confidence = (result.confidence * 100).round();

    return SectionCard(
      title: state.t('healthResult'),
      subtitle: result.displayCondition(hausa),
      accent: confidence >= 85 ? AppColors.health : AppColors.warning,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.faint(AppColors.health, 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.vaccines_outlined,
            color: AppColors.health, size: 18),
      ),
      trailing: SpeakButton(
        compact: true,
        color: AppColors.health,
        textBuilder: () =>
            '${result.displayCondition(hausa)}. ${result.displayAdvice(hausa)} '
            '${result.displayUrgency(hausa)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Pill(
            label: '${state.t('urgency')}: ${result.displayUrgency(hausa)}',
            color: AppColors.danger,
            icon: Icons.emergency_outlined,
          ),
          const SizedBox(height: 10),
          Text(
            result.displayAdvice(hausa),
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
          if (result.firstAid != null) ...<Widget>[
            const Divider(height: 20),
            InfoRow(
              label: state.t('firstAidHomeCare'),
              value: hausa ? result.firstAidHausa! : result.firstAid!,
              valueColor: AppColors.success,
            ),
          ],
          InfoRow(
            label: state.t('confidence'),
            value: '$confidence%',
            valueColor: confidence >= 85 ? AppColors.success : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _ConditionDialog extends StatelessWidget {
  const _ConditionDialog({required this.condition, required this.hausa});

  final ManualHealthCondition condition;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final speech =
        '${condition.displayName(hausa)}. ${condition.localizedSymptoms(hausa)} '
        '${condition.localizedFirstAid(hausa)} ${condition.localizedClinicalAdvice(hausa)}';

    return AlertDialog(
      title: Text(
        condition.displayName(hausa),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Pill(
              label: condition.localizedUrgency(hausa),
              color: AppColors.danger,
              icon: Icons.emergency_outlined,
            ),
            const SizedBox(height: 10),
            Text(
              condition.localizedSymptoms(hausa),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              state.t('firstAidHomeCare'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.success,
              ),
            ),
            Text(
              condition.localizedFirstAid(hausa),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              state.t('advice'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.info,
              ),
            ),
            Text(
              condition.localizedClinicalAdvice(hausa),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              state.t('seekCare'),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.danger,
              ),
            ),
            Text(
              condition.localizedDangerSigns(hausa),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        SpeakButton(
          color: AppColors.primary,
          textBuilder: () => speech,
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(state.pick('Close', 'Rufe')),
        ),
      ],
    );
  }
}
