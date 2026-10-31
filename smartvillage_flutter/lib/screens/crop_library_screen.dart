import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/crop_data.dart';
import '../data/knowledge_data.dart';
import '../models/crop.dart';
import '../state/app_state.dart';
import '../widgets/leaf_illustration.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Crop Disease Reference Library / Laburaren Cututtuka.
/// Port of `CropReferenceLibraryScreen.tsx`.
class CropLibraryScreen extends StatefulWidget {
  const CropLibraryScreen({super.key});

  @override
  State<CropLibraryScreen> createState() => _CropLibraryScreenState();
}

class _CropLibraryScreenState extends State<CropLibraryScreen> {
  final TextEditingController _search = TextEditingController();

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

    final crops = cropReferenceData.where((crop) {
      if (query.isEmpty) return true;
      return crop.crop.toLowerCase().contains(query) ||
          crop.hausaName.toLowerCase().contains(query) ||
          crop.diseases.any(
            (disease) =>
                disease.name.toLowerCase().contains(query) ||
                disease.hausaName.toLowerCase().contains(query),
          );
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
        const SizedBox(height: 12),
        Text(
          hausa
              ? 'Dukkan cututtuka 69 a cikin amfanin gona 13 — hoto, alamomi, magani da rigakafi.'
              : 'All 69 diseases across 13 crops — pictures, symptoms, treatment and prevention.',
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...crops.map(
          (crop) => _CropLibraryCard(crop: crop, hausa: hausa, query: query),
        ),
      ],
    );
  }
}

class _CropLibraryCard extends StatelessWidget {
  const _CropLibraryCard({
    required this.crop,
    required this.hausa,
    required this.query,
  });

  final Crop crop;
  final bool hausa;
  final String query;

  @override
  Widget build(BuildContext context) {
    final diseases = query.isEmpty
        ? crop.diseases
        : crop.diseases
            .where(
              (disease) =>
                  disease.name.toLowerCase().contains(query) ||
                  disease.hausaName.toLowerCase().contains(query),
            )
            .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        title: '${crop.emoji} ${crop.displayName(hausa)}',
        subtitle: crop.localizedDescription(hausa),
        accent: AppColors.crop,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(
            children: diseases
                .map(
                  (disease) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    leading: LeafIllustration(
                      leafColor: disease.leafColor,
                      spotColor: disease.spotColor,
                      showSpots: !disease.isHealthy,
                      size: 34,
                    ),
                    title: Text(
                      disease.displayName(hausa),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      disease.affectedParts.isEmpty
                          ? (hausa ? 'Shuka mai lafiya' : 'Healthy foliage')
                          : '${hausa ? 'Ya shafa' : 'Affects'}: ${disease.affectedParts.join(', ')}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    children: <Widget>[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.start,
                        children: <Widget>[
                          SpeakButton(
                            color: AppColors.primary,
                            label: hausa ? 'Saurara' : 'Listen',
                            textBuilder: () =>
                                '${disease.displayName(hausa)}. ${disease.localizedSymptoms(hausa)} '
                                '${disease.localizedTreatment(hausa)} ${disease.localizedPrevention(hausa)}',
                          ),
                          Pill(
                            label: crop.displayName(hausa),
                            color: AppColors.crop,
                            icon: Icons.spa,
                          ),
                          if (disease.isHealthy)
                            Pill(
                              label: hausa ? 'Mai lafiya' : 'Healthy',
                              color: AppColors.success,
                              icon: Icons.check,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InfoRow(
                        label: AppScope.read(context).t('causes'),
                        value: disease.localizedCauses(hausa),
                      ),
                      InfoRow(
                        label: AppScope.read(context).t('symptoms'),
                        value: disease.localizedSymptoms(hausa),
                      ),
                      InfoRow(
                        label: AppScope.read(context).t('treatment'),
                        value: disease.localizedTreatment(hausa),
                        valueColor: AppColors.success,
                      ),
                      InfoRow(
                        label: AppScope.read(context).t('preventionTips'),
                        value: disease.localizedPrevention(hausa),
                        valueColor: AppColors.info,
                      ),
                      if (diseaseDetails[disease.id] != null)
                        InfoRow(
                          label: AppScope.read(context).t('organicAlternative'),
                          value:
                              diseaseDetails[disease.id]!.organicAlternative,
                          valueColor: AppColors.soil,
                        ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
