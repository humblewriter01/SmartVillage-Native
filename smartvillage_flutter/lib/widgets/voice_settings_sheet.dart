import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/text_preprocessor.dart';
import '../services/tts/hybrid_tts_service.dart';
import '../services/tts/tts_chunker.dart';
import '../state/app_state.dart';

/// Voice profile sheet: pick Murya (natural Hausa) or the device voice, see
/// whether the ONNX model loaded, and preview the text pre-processor + chunker.
Future<void> showVoiceSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _VoiceSettingsSheet(),
  );
}

class _VoiceSettingsSheet extends StatefulWidget {
  const _VoiceSettingsSheet();

  @override
  State<_VoiceSettingsSheet> createState() => _VoiceSettingsSheetState();
}

class _VoiceSettingsSheetState extends State<_VoiceSettingsSheet> {
  final TextEditingController _controller = TextEditingController(
    text:
        '7 mancozeb sprays on onion at the farm — use Emamectin benzoate if armyworm returns ⚠️',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tts = state.tts;
    final hausa = state.isHausa;
    final chunks = tts.previewChunks(_controller.text, state.language);
    final normalized = TextPreprocessor.normalize(_controller.text);

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hausa ? 'Saitin Murya' : 'Voice Profile',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              hausa
                  ? 'Zaɓi muryar da kake so: Murya ta Hausa (ONNX) ko muryar waya.'
                  : 'Choose the natural Hausa model or the device voice.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            _ModeTile(
              selected: tts.mode == VoiceMode.natural,
              title: hausa ? 'Muryar Gida mai Dumi (Murya)' : 'Natural Voice (Murya)',
              subtitle: hausa
                  ? 'Hausa ta gaske daga ONNX a waya, ba tare da intanet ba'
                  : 'Native Hausa ONNX model — runs fully on-device',
              badge: tts.muryaReady
                  ? (hausa ? 'A shirye' : 'Loaded')
                  : (hausa ? 'Babu fayil ɗin model' : 'Model not loaded'),
              badgeColor: tts.muryaReady ? AppColors.success : AppColors.warning,
              onTap: () async {
                await tts.setMode(VoiceMode.natural);
                await tts.warmUpMurya();
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 8),
            _ModeTile(
              selected: tts.mode == VoiceMode.system,
              title: hausa ? "Muryar Na'urar Waya" : 'Device Voice',
              subtitle: hausa
                  ? 'Muryar Android (tana iya karanta Hausa idan an saka fakitin)'
                  : 'Uses the phone TTS engine (English or installed Hausa pack)',
              badge: null,
              badgeColor: AppColors.info,
              onTap: () async {
                await tts.setMode(VoiceMode.system);
                if (mounted) setState(() {});
              },
            ),
            if (tts.muryaReady && tts.availableSpeakers.isNotEmpty) ...<Widget>[
              const Divider(height: 26),
              Text(
                hausa ? 'Muryar Murya (sauti 8)' : 'Murya voice',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hausa
                    ? 'M1 da M2 muryoyin maza ne, F1 zuwa F4 na mata. Zaɓi wanda ya fi so.'
                    : 'M1–M4 are male, F1–F4 female. Pick the voice farmers find clearest.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tts.availableSpeakers
                    .map(
                      (speaker) => ChoiceChip(
                        label: Text(
                          speaker.key,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        selected: tts.activeSpeaker == speaker.value,
                        onSelected: (_) async {
                          await tts.setSpeaker(speaker.value);
                          if (mounted) setState(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
            const Divider(height: 26),
            Text(
              hausa ? 'Gwada mai sarrafa rubutu' : 'Text pre-processor preview',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(fontSize: 12.5),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'normalize()',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    normalized.isEmpty ? '…' : normalized,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: chunks
                  .map(
                    (chunk) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.faint(
                          chunk.isHausa ? AppColors.success : AppColors.info,
                          0.1,
                        ),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: AppColors.faint(
                            chunk.isHausa ? AppColors.success : AppColors.info,
                            0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        '${chunk.isHausa ? 'MURYA' : 'SYSTEM'} · ${chunk.text}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: chunk.isHausa
                              ? AppColors.success
                              : AppColors.info,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => state.speak(_controller.text),
                    icon: const Icon(Icons.volume_up, size: 18),
                    label: Text(hausa ? 'Saurara' : 'Listen'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => state.stopSpeaking(),
                  icon: const Icon(Icons.stop, size: 18),
                  label: Text(hausa ? 'Dakata' : 'Stop'),
                ),
              ],
            ),
            if (tts.statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  tts.statusMessage!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.badgeColor,
    this.badge,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final String? badge;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.faint(badgeColor, 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Kept for tests: verifies the public chunker surface is reachable from UI.
List<TtsChunk> debugChunks(String text) => TtsChunker.split(text);
