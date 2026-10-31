import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/reminder_service.dart';
import '../state/app_state.dart';
import 'section_card.dart';

/// "Coming up" strip for harvest and planting alerts.
///
/// Reminders live entirely on the device, so this card is the place a farmer
/// actually sees them: due items first (with a *Did it* button that clears
/// them) followed by the next couple of upcoming ones.
class ReminderCard extends StatefulWidget {
  const ReminderCard({super.key, this.service});

  /// Injectable for tests.
  final ReminderService? service;

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard> {
  late final ReminderService _service = widget.service ?? ReminderService();

  List<StoredReminder> _due = const <StoredReminder>[];
  List<StoredReminder> _upcoming = const <StoredReminder>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final due = await _service.due(now: now);
    final upcoming = await _service.upcoming(now: now);
    if (!mounted) return;
    setState(() {
      _due = due;
      _upcoming = upcoming.take(3).toList(growable: false);
      _loading = false;
    });
  }

  Future<void> _dismiss(StoredReminder reminder) async {
    await _service.remove(reminder.key);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    if (_loading) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_due.isEmpty && _upcoming.isEmpty) {
      return SectionCard(
        title: hausa ? 'Tunatarwa' : 'Reminders',
        subtitle: hausa
            ? 'Babu wani abu a gabanta. Ƙara shuka a Gona domin samun tunatarwar girbi.'
            : 'Nothing scheduled. Add a planting in Gona to get harvest alerts.',
        leading: const Icon(
          Icons.notifications_none_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        child: const SizedBox.shrink(),
      );
    }

    return SectionCard(
      title: hausa ? 'Tunatarwa' : 'Reminders',
      subtitle: _due.isEmpty
          ? (hausa ? 'Masu zuwa nan gaba' : 'Coming up next')
          : (hausa
              ? 'Abubuwan da suka isa lokaci'
              : 'Due now — tap to clear when done'),
      leading: Icon(
        _due.isEmpty
            ? Icons.notifications_active_outlined
            : Icons.notifications_active_rounded,
        color: _due.isEmpty ? AppColors.primary : AppColors.warning,
        size: 20,
      ),
      trailing: IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        color: AppColors.textSecondary,
        tooltip: hausa ? 'Sabunta' : 'Refresh',
        visualDensity: VisualDensity.compact,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final reminder in _due)
            _ReminderRow(
              reminder: reminder,
              hausa: hausa,
              due: true,
              onDismiss: () => _dismiss(reminder),
            ),
          for (final reminder in _upcoming)
            _ReminderRow(
              reminder: reminder,
              hausa: hausa,
              due: false,
              onDismiss: () => _dismiss(reminder),
            ),
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.hausa,
    required this.due,
    required this.onDismiss,
  });

  final StoredReminder reminder;
  final bool hausa;
  final bool due;
  final VoidCallback onDismiss;

  String get _when {
    if (due) {
      final late = -reminder.daysLeft(DateTime.now());
      final lateLabel = late <= 0
          ? (hausa ? 'Yau' : 'Today')
          : (hausa ? 'Kwanaki $late da suka wuce' : '$late day(s) ago');
      return lateLabel;
    }
    final left = reminder.daysLeft(DateTime.now());
    return left <= 0
        ? (hausa ? 'Gobe' : 'Tomorrow')
        : (hausa ? 'Sauran kwanaki $left' : 'In $left day(s)');
  }

  @override
  Widget build(BuildContext context) {
    final accent = due ? AppColors.warning : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.faint(accent, 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.faint(accent, 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              due ? Icons.alarm_rounded : Icons.event_available_rounded,
              size: 16,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  reminder.titleFor(hausa),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reminder.bodyFor(hausa),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Pill(
                  label: _when,
                  color: accent,
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            color: AppColors.textMuted,
            tooltip: hausa ? 'An gama' : 'Done',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
