import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../state/app_state.dart';
import '../utils/translations.dart';

/// Global English / Hausa switch shown in the header.
///
/// Switching language immediately re-renders every screen (all copy comes from
/// the translation table or the bilingual datasets) and pre-warms the Murya
/// voice so the first Hausa sentence is instant.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Segment(
            label: 'EN',
            selected: state.language == AppLanguage.english,
            onTap: () => state.setLanguage(AppLanguage.english),
          ),
          _Segment(
            label: 'HA',
            selected: state.language == AppLanguage.hausa,
            onTap: () => state.setLanguage(AppLanguage.hausa),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
