import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/tts/hybrid_tts_service.dart';
import '../state/app_state.dart';

/// "Listen / Saurara" button.
///
/// Tap → the hybrid router picks Murya (Hausa) or the device voice (English),
/// pre-processes the text and applies the 2-second fallback rule. Tap again to
/// stop playback.
class SpeakButton extends StatefulWidget {
  const SpeakButton({
    super.key,
    required this.textBuilder,
    this.label,
    this.compact = false,
    this.color = Colors.white,
    this.background,
  });

  /// Called at tap-time so the spoken text always reflects fresh results.
  final String Function() textBuilder;
  final String? label;
  final bool compact;
  final Color color;
  final Color? background;

  @override
  State<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<SpeakButton> {
  bool _speaking = false;

  Future<void> _toggle() async {
    final state = AppScope.read(context);
    if (_speaking) {
      await state.stopSpeaking();
      if (mounted) setState(() => _speaking = false);
      return;
    }

    setState(() => _speaking = true);
    try {
      await state.speak(widget.textBuilder());
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final background = widget.background ?? AppColors.faint(color, 0.16);
    final label = widget.label ?? (AppScope.of(context).isHausa ? 'Saurara' : 'Listen');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 9 : 12,
            vertical: widget.compact ? 5 : 7,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.faint(color, 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                _speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                size: widget.compact ? 14 : 16,
                color: color,
              ),
              if (!widget.compact) ...<Widget>[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows which engine handled the last utterance (useful while tuning Murya).
class VoiceRouteBadge extends StatelessWidget {
  const VoiceRouteBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tts = state.tts;
    final route = tts.lastRoute;

    String label;
    Color color;
    switch (route) {
      case VoiceRoute.murya:
        label = 'Murya (native Hausa)';
        color = AppColors.success;
        break;
      case VoiceRoute.system:
        label = state.pick('Device voice', "Muryar na'ura");
        color = AppColors.info;
        break;
      case VoiceRoute.mixed:
        label = state.pick('Mixed: Murya + device', 'Gauraye: Murya + na\'ura');
        color = AppColors.warning;
        break;
      case VoiceRoute.none:
        label = state.pick('Voice idle', 'Murya a kwance');
        color = AppColors.textMuted;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.graphic_eq, size: 13, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
