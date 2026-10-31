import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/history_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// History / Tarihi.
/// Port of `HistoryScreen.tsx`.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final records = state.history;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        SectionHeader(
          title: state.t('history'),
          subtitle: hausa
              ? 'Duk binciken da aka adana a wayar'
              : 'Every evaluation saved on this device',
          icon: Icons.history,
          trailing: records.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: state.clearHistory,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: Text(
                    state.t('clearAll'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
        ),
        if (records.isEmpty)
          SectionCard(
            accent: AppColors.textMuted,
            child: Column(
              children: <Widget>[
                const Icon(Icons.inbox_outlined,
                    size: 34, color: AppColors.textMuted),
                const SizedBox(height: 8),
                Text(
                  state.t('noHistory'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...records.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SectionCard(
                accent: _typeColor(record.type),
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(record.emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            record.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SpeakButton(
                          compact: true,
                          color: _typeColor(record.type),
                          textBuilder: () => record.detail,
                        ),
                        IconButton(
                          onPressed: () => state.deleteHistory(record.id),
                          icon: const Icon(Icons.close,
                              size: 16, color: AppColors.textMuted),
                          visualDensity: VisualDensity.compact,
                          tooltip: state.t('deleteRecord'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.detail,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${record.createdAt.day}/${record.createdAt.month}/${record.createdAt.year} '
                      '${record.createdAt.hour.toString().padLeft(2, '0')}:'
                      '${record.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          state.pick(
            'Records never leave your phone. They are stored offline in app storage.',
            'Bayanan ba sa barin wayarka. Ana adana su a cikin manhajar ba tare da intanet ba.',
          ),
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  static Color _typeColor(HistoryType type) {
    switch (type) {
      case HistoryType.crop:
        return AppColors.crop;
      case HistoryType.health:
        return AppColors.health;
      case HistoryType.water:
        return AppColors.water;
      case HistoryType.livestock:
        return AppColors.livestock;
      case HistoryType.mapPin:
        return AppColors.map;
      case HistoryType.soil:
        return AppColors.soil;
    }
  }
}
