import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../data/crop_data.dart';
import '../data/knowledge_data.dart';
import '../models/crop.dart';
import '../services/crop_service.dart';
import '../services/history_service.dart';
import '../services/media_service.dart';
import '../state/app_state.dart';
import '../widgets/camera_capture_screen.dart';
import '../widgets/harvest_countdown_card.dart';
import '../widgets/leaf_illustration.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Crop / Gona — leaf diagnosis + harvest tracker.
/// Port of `CropScreen.tsx`.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final MediaService _media = MediaService();

  Crop _selectedCrop = cropReferenceData.first;
  Uint8List? _photo;
  bool _analyzing = false;
  CropResult? _result;
  String? _manualDiseaseId;
  final TextEditingController _symptomsController = TextEditingController();

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _captureCamera() async {
    final bytes = await CameraCaptureScreen.open(
      context,
      title: AppScope.read(context).pick('Leaf Scanner', 'Duba Ganyen Shuka'),
      guideText: AppScope.read(context).pick(
        'Fill the frame with a single affected leaf.',
        'Cika firam ɗin da ganye ɗaya da cutar ta shafa.',
      ),
    );
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = bytes;
      _result = null;
      _manualDiseaseId = null;
    });
  }

  Future<void> _captureGallery() async {
    final bytes = await _media.pickFromGallery();
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = bytes;
      _result = null;
      _manualDiseaseId = null;
    });
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null) {
      _toast(AppScope.read(context).t('noPhoto'));
      return;
    }
    setState(() => _analyzing = true);
    await Future<void>.delayed(const Duration(milliseconds: 24));

    CropResult result;
    final symptoms = _symptomsController.text.trim();
    if (_manualDiseaseId != null) {
      result = CropService.diagnoseSelection(
        cropId: _selectedCrop.id,
        suspectedDiseaseId: _manualDiseaseId,
        symptomsText: symptoms.isEmpty ? null : symptoms,
      );
    } else if (symptoms.isNotEmpty) {
      result = CropService.diagnoseBySymptoms(
        symptoms,
        targetCropId: _selectedCrop.id,
      );
    } else {
      result = await CropService.analyzeImage(
        photo,
        targetCropId: _selectedCrop.id,
      );
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _analyzing = false;
    });

    final state = AppScope.read(context);
    if (result.referenceDetail != null) {
      await state.recordHistory(
        type: HistoryType.crop,
        title: '${_selectedCrop.crop} · ${result.referenceDetail!.name}',
        detail: result.advice,
      );
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final harvestTab = state.cropHarvestTab;

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          color: AppColors.surface,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _SubTab(
                  label: hausa ? 'Binciken Cuta' : 'Diagnosis',
                  icon: Icons.local_florist_outlined,
                  selected: !harvestTab,
                  onTap: () => state.goToTab(TabId.crop),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SubTab(
                  label: hausa ? 'Kwanakin Girbi' : 'Harvest Tracker',
                  icon: Icons.timelapse,
                  selected: harvestTab,
                  onTap: () => state.openHarvestTracker(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: harvestTab ? const _HarvestTab() : _buildDiagnosis(hausa),
        ),
      ],
    );
  }

  Widget _buildDiagnosis(bool hausa) {
    final state = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        SectionHeader(
          title: hausa ? '1. Zaɓi Nau\'in Shuka' : '1. Select your crop',
          subtitle: hausa
              ? 'Ana duba cututtukan wannan shuka kaɗai'
              : 'Only diseases of the selected crop are evaluated',
          icon: Icons.spa_outlined,
          accent: AppColors.crop,
        ),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cropReferenceData.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final crop = cropReferenceData[index];
              final selected = crop.id == _selectedCrop.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedCrop = crop;
                  _result = null;
                  _manualDiseaseId = null;
                }),
                child: Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primarySoft : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      LeafIllustration(
                        leafColor: crop.leafColor,
                        emoji: crop.emoji,
                        size: 42,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        crop.displayName(hausa),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.15,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected
                              ? AppColors.primary
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
        const SizedBox(height: 8),
        Text(
          _selectedCrop.localizedDescription(hausa),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        SectionHeader(
          title: hausa ? '2. Hoton Ganye' : '2. Leaf photo',
          subtitle: hausa
              ? 'Ɗauki hoto a haske mai kyau'
              : 'Take a clear photo in good light',
          icon: Icons.photo_camera_outlined,
          accent: AppColors.crop,
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _captureCamera,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(state.t('takePhoto')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.crop,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _captureGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(state.t('gallery')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
          ],
        ),
        if (_photo != null) ...<Widget>[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: <Widget>[
                Image.memory(_photo!, height: 210, fit: BoxFit.cover),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    onPressed: () => setState(() {
                      _photo = null;
                      _result = null;
                    }),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x99000000),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _symptomsController,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            labelText: hausa ? 'Alamomi (na zaɓi)' : 'Symptoms (optional)',
            hintText: state.t('cropSpeechHint'),
            hintStyle: const TextStyle(fontSize: 11),
            suffixIcon: IconButton(
              onPressed: () {
                final text = _symptomsController.text.trim();
                if (text.isEmpty) return;
                state.speak(text);
              },
              icon: const Icon(Icons.volume_up_outlined, size: 18),
              tooltip: hausa ? 'Karanta da murya' : 'Read aloud',
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _analyzing ? null : _analyze,
          icon: _analyzing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search, size: 18),
          label: Text(_analyzing ? state.t('analyzing') : state.t('analyze')),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _openManualPicker(hausa),
          icon: const Icon(Icons.checklist, size: 16),
          label: Text(state.t('selectManually')),
        ),
        if (_result != null) ...<Widget>[
          const SizedBox(height: 10),
          _CropResultPanel(
            result: _result!,
            crop: _selectedCrop,
            hausa: hausa,
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: state.t('referenceLibraryTitle'),
          subtitle: hausa
              ? 'Duba dukkan cututtuka da magungunan wannan shuka'
              : 'Browse every disease recorded for this crop',
          accent: AppColors.info,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.faint(AppColors.info, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book, color: AppColors.info, size: 18),
          ),
          child: Column(
            children: _selectedCrop.diseases
                .take(6)
                .map(
                  (disease) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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
                          ? (hausa ? 'Shuka mai lafiya' : 'Healthy plant')
                          : disease.affectedParts.join(', '),
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _showDiseaseDetails(disease, hausa),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          state.t('notMedical'),
          style: const TextStyle(
            fontSize: 10,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Future<void> _openManualPicker(bool hausa) async {
    final state = AppScope.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: <Widget>[
                Text(
                  state.t('manualSelectorTitle'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.t('chooseDisease'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ..._selectedCrop.diseases.map(
                  (disease) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: LeafIllustration(
                      leafColor: disease.leafColor,
                      spotColor: disease.spotColor,
                      showSpots: !disease.isHealthy,
                      size: 36,
                    ),
                    title: Text(
                      disease.displayName(hausa),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      disease.localizedSymptoms(hausa),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, height: 1.3),
                    ),
                    onTap: () {
                      setState(() {
                        _manualDiseaseId = disease.id;
                        _result = CropService.diagnoseSelection(
                          cropId: _selectedCrop.id,
                          suspectedDiseaseId: disease.id,
                        );
                      });
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDiseaseDetails(Disease disease, bool hausa) {
    final info = diseaseDetails[disease.id];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
          children: <Widget>[
            Row(
              children: <Widget>[
                LeafIllustration(
                  leafColor: disease.leafColor,
                  spotColor: disease.spotColor,
                  showSpots: !disease.isHealthy,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    disease.displayName(hausa),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SpeakButton(
                  compact: true,
                  color: AppColors.primary,
                  textBuilder: () =>
                      '${disease.displayName(hausa)}. ${disease.localizedSymptoms(hausa)} ${disease.localizedTreatment(hausa)}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailBlock(
              title: AppScope.read(context).t('affectedParts'),
              body: disease.affectedParts.isEmpty
                  ? AppScope.read(context).pick('None', 'Babu')
                  : disease.affectedParts.join(', '),
            ),
            _DetailBlock(
              title: AppScope.read(context).t('causes'),
              body: disease.localizedCauses(hausa),
            ),
            _DetailBlock(
              title: AppScope.read(context).t('symptoms'),
              body: disease.localizedSymptoms(hausa),
            ),
            _DetailBlock(
              title: AppScope.read(context).t('treatment'),
              body: disease.localizedTreatment(hausa),
              color: AppColors.success,
            ),
            _DetailBlock(
              title: AppScope.read(context).t('preventionTips'),
              body: disease.localizedPrevention(hausa),
              color: AppColors.info,
            ),
            if (info != null)
              _DetailBlock(
                title: AppScope.read(context).t('organicAlternative'),
                body: info.organicAlternative,
                color: AppColors.soil,
              ),
          ],
        ),
      ),
    );
  }
}

class _HarvestTab extends StatelessWidget {
  const _HarvestTab();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        const HarvestCountdownCard(),
        const SizedBox(height: 14),
        SectionCard(
          title: hausa ? 'Shawarar Girbi' : 'Harvest readiness signs',
          subtitle: hausa
              ? 'Alamomin da ke nuna lokacin girbi ya yi'
              : 'Crop-by-crop signs that harvest is due',
          accent: AppColors.calendar,
          child: Column(
            children: state.plantings
                .map(
                  (crop) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${crop.displayName(hausa)} — ${crop.fieldLabel}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          crop.tip(hausa),
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.4,
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
        const SizedBox(height: 14),
        Text(
          hausa
              ? 'Ana ƙididdige girbi ne daga ranar shuka da kwanakin balaga na kowace shuka. Danna + a kanin katin don ƙara sabuwar shuka.'
              : 'Countdowns are calculated from the planting date and each crop\'s maturity window. Tap + on the card above to add a new planting.',
          style: const TextStyle(
            fontSize: 11,
            height: 1.45,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  const _SubTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropResultPanel extends StatelessWidget {
  const _CropResultPanel({
    required this.result,
    required this.crop,
    required this.hausa,
  });

  final CropResult result;
  final Crop crop;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final disease = result.referenceDetail;
    final confidence = (result.topConfidence * 100).round();

    if (result.needsCropSelection) {
      return SectionCard(
        title: hausa ? 'Zaɓi Shuka' : 'Select a crop',
        accent: AppColors.warning,
        child: Text(
          result.displayAdvice(hausa),
          style: const TextStyle(fontSize: 12.5, height: 1.45),
        ),
      );
    }

    return SectionCard(
      title: state.t('cropResult'),
      subtitle: disease == null ? null : disease.displayName(hausa),
      accent: disease?.isHealthy ?? false ? AppColors.success : AppColors.warning,
      leading: LeafIllustration(
        leafColor: disease?.leafColor ?? crop.leafColor,
        spotColor: disease?.spotColor,
        showSpots: !(disease?.isHealthy ?? false),
        size: 44,
        emoji: crop.emoji,
      ),
      trailing: SpeakButton(
        compact: true,
        color: AppColors.primary,
        textBuilder: () => result.displayAdvice(hausa),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Pill(
                label: '${state.t('confidence')}: $confidence%',
                color: confidence >= 80 ? AppColors.success : AppColors.warning,
                icon: Icons.insights,
              ),
              const SizedBox(width: 6),
              Pill(
                label: crop.displayName(hausa),
                color: AppColors.crop,
                icon: Icons.spa,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.displayAdvice(hausa),
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
          if (confidence < 60) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.faint(AppColors.warning, 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.faint(AppColors.warning, 0.35),
                ),
              ),
              child: Text(
                state.t('lowConfidenceWarning'),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF92400E),
                  height: 1.4,
                ),
              ),
            ),
          ],
          if (disease != null) ...<Widget>[
            const Divider(height: 20),
            InfoRow(
              label: state.t('affectedParts'),
              value: disease.affectedParts.isEmpty
                  ? state.pick('None', 'Babu')
                  : disease.affectedParts.join(', '),
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
          ],
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.body,
    this.color = AppColors.primary,
  });

  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 13,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}
