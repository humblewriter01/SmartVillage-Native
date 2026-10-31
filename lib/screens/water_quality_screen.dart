import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/history_service.dart';
import '../services/media_service.dart';
import '../services/water_quality_service.dart';
import '../state/app_state.dart';
import '../widgets/camera_capture_screen.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Water / Ruwa — offline visual water-safety screening.
/// Port of `WaterQualityScreen.tsx`.
class WaterQualityScreen extends StatefulWidget {
  const WaterQualityScreen({super.key});

  @override
  State<WaterQualityScreen> createState() => _WaterQualityScreenState();
}

class _WaterQualityScreenState extends State<WaterQualityScreen> {
  final MediaService _media = MediaService();
  Uint8List? _photo;
  WaterQualityResult? _result;
  bool _analyzing = false;

  Future<void> _capture() async {
    final bytes = await CameraCaptureScreen.open(
      context,
      title: AppScope.read(context).pick('Water Sample', 'Hoton Ruwa'),
      guideText: AppScope.read(context).pick(
        'Fill a clear glass with water and hold it against a plain background.',
        'Cika gilashin ruwa mai haske ka rike shi a gaban wani abu mara tsari.',
      ),
      accent: AppColors.water,
    );
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = bytes;
      _result = null;
    });
  }

  Future<void> _gallery() async {
    final bytes = await _media.pickFromGallery();
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = bytes;
      _result = null;
    });
  }

  Future<void> _analyze() async {
    final photo = _photo;
    if (photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppScope.read(context).t('noPhoto'))),
      );
      return;
    }
    final state = AppScope.read(context);
    setState(() => _analyzing = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final result = await WaterQualityService.analyze(photo);
    if (!mounted) return;
    setState(() {
      _result = result;
      _analyzing = false;
    });
    await state.recordHistory(
      type: HistoryType.water,
      title: result.displayVerdict(state.isHausa),
      detail: result.displayAdvice(state.isHausa),
    );
  }

  void _useSample(WaterQualityResult sample) {
    setState(() {
      _photo = null;
      _result = sample;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        SectionCard(
          title: hausa ? 'Duba Tsabtar Ruwa' : 'Water Quality Check',
          subtitle: hausa
              ? 'Ɗauki hoton ruwa a kofi: Mai Kyau ko Tafasa Kafin Sha'
              : 'Photograph water in a glass: safe to drink or boil first',
          accent: AppColors.water,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.faint(AppColors.water, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.water_drop_outlined,
                color: AppColors.water, size: 18),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _capture,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text(state.t('takePhoto')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.water,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _gallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(state.t('gallery')),
                    ),
                  ),
                ],
              ),
              if (_photo != null) ...<Widget>[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_photo!, height: 200, fit: BoxFit.cover),
                ),
              ],
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
                    : const Icon(Icons.science_outlined, size: 18),
                label: Text(_analyzing ? state.t('analyzing') : state.t('analyze')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.water,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          state.t('tryTestWaterSamples'),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ActionChip(
              avatar: const Text('🚰', style: TextStyle(fontSize: 13)),
              label: Text(
                hausa ? 'Rijiyar borehole' : 'Clean borehole',
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: () => _useSample(
                WaterQualityService.cleanBoreholeResult(),
              ),
            ),
            ActionChip(
              avatar: const Text('🌊', style: TextStyle(fontSize: 13)),
              label: Text(
                hausa ? 'Ruwan kogi' : 'Turbid river',
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: () => _useSample(
                WaterQualityService.turbidRiverResult(),
              ),
            ),
            ActionChip(
              avatar: const Text('🟢', style: TextStyle(fontSize: 13)),
              label: Text(
                hausa ? 'Ruwa mai ciyawa' : 'Algae water',
                style: const TextStyle(fontSize: 11),
              ),
              onPressed: () => _useSample(WaterQualityService.algaeResult()),
            ),
          ],
        ),
        if (_result != null) ...<Widget>[
          const SizedBox(height: 14),
          _WaterResultPanel(result: _result!, hausa: hausa),
        ],
        const SizedBox(height: 14),
        Text(
          hausa
              ? 'Wannan gwajin gani ne kawai. Ba ya gano kwayoyin cuta marasa gani — idan akwai shakka, a tafasa ruwan.'
              : 'This is a visual screening only. It cannot detect invisible pathogens — when in doubt, boil the water.',
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

class _WaterResultPanel extends StatelessWidget {
  const _WaterResultPanel({required this.result, required this.hausa});

  final WaterQualityResult result;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final color = result.isClean ? AppColors.success : AppColors.warning;

    return SectionCard(
      title: state.t('waterResult'),
      subtitle: result.displayVerdict(hausa),
      accent: color,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.faint(color, 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          result.isClean ? Icons.verified_outlined : Icons.warning_amber_rounded,
          color: color,
          size: 18,
        ),
      ),
      trailing: SpeakButton(
        compact: true,
        color: color,
        textBuilder: () =>
            '${result.displayVerdict(hausa)}. ${result.displayAdvice(hausa)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Pill(
                label: result.isClean
                    ? state.t('cleanWater')
                    : state.t('notCleanWater'),
                color: color,
                icon: result.isClean ? Icons.check : Icons.boil,
              ),
              const SizedBox(width: 6),
              Pill(
                label: '${result.turbidityScore} NTU',
                color: AppColors.water,
                icon: Icons.opacity,
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(
            label: state.t('colorAnalysis'),
            value: result.displayColor(hausa),
          ),
          InfoRow(
            label: state.t('particles'),
            value: result.hasParticles
                ? state.pick('Suspended particles seen', 'An ga barbashi a ciki')
                : state.pick('None seen', 'Ba a gani ba'),
            valueColor: result.hasParticles ? AppColors.warning : AppColors.success,
          ),
          InfoRow(
            label: state.t('turbidity'),
            value: '${result.turbidityScore} / 100',
          ),
          const Divider(height: 20),
          Text(
            result.displayAdvice(hausa),
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.faint(AppColors.water, 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  result.guidelines.standard,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.water,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'WHO: ${result.guidelines.whoLimit}\nNSDWQ: ${result.guidelines.nsdwqLimit}\n'
                  '${result.guidelines.advice(hausa)}',
                  style: const TextStyle(fontSize: 10.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
