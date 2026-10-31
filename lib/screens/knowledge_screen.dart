import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/knowledge_data.dart';
import '../models/knowledge.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Knowledge / Ilimi — offline farming & health guidance.
/// Port of `KnowledgeScreen.tsx`.
class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final TextEditingController _search = TextEditingController();
  KnowledgeCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final query = _search.text.trim().toLowerCase();

    final items = knowledgeItems.where((item) {
      final matchesCategory = _category == null || item.category == _category;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.titleHa.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query) ||
          item.bodyHa.toLowerCase().contains(query);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: state.t('search'),
            hintStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 18),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            ChoiceChip(
              selected: _category == null,
              label: Text(
                state.t('allGuidance'),
                style: const TextStyle(fontSize: 10.5),
              ),
              onSelected: (_) => setState(() => _category = null),
            ),
            ...KnowledgeCategory.values.map(
              (category) => ChoiceChip(
                selected: _category == category,
                label: Text(
                  _categoryLabel(category, state),
                  style: const TextStyle(fontSize: 10.5),
                ),
                onSelected: (_) => setState(() => _category = category),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SectionCard(
              title: item.displayTitle(hausa),
              subtitle: _categoryLabel(item.category, state),
              accent: _categoryColor(item.category),
              trailing: SpeakButton(
                compact: true,
                color: _categoryColor(item.category),
                textBuilder: () => item.displayBody(hausa),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.displayBody(hausa),
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.verified_outlined,
                          size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${state.t('sourceBasis')}: ${item.source}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Text(
                state.pick('No matching guidance', 'Babu shawara da ta dace'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _categoryLabel(KnowledgeCategory category, AppState state) {
    switch (category) {
      case KnowledgeCategory.crop:
        return state.t('cropsCategory');
      case KnowledgeCategory.health:
        return state.t('healthCategory');
      case KnowledgeCategory.farm:
        return state.t('farmCategory');
      case KnowledgeCategory.water:
        return state.t('waterCategory');
      case KnowledgeCategory.poultry:
        return state.t('poultryCategory');
    }
  }

  static Color _categoryColor(KnowledgeCategory category) {
    switch (category) {
      case KnowledgeCategory.crop:
        return AppColors.crop;
      case KnowledgeCategory.health:
        return AppColors.health;
      case KnowledgeCategory.farm:
        return AppColors.calendar;
      case KnowledgeCategory.water:
        return AppColors.water;
      case KnowledgeCategory.poultry:
        return AppColors.livestock;
    }
  }
}
