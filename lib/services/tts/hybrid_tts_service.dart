import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/translations.dart';
import '../text_preprocessor.dart';
import 'murya_tts_engine.dart';
import 'system_tts_engine.dart';
import 'tts_chunker.dart';
import 'tts_engine.dart';

/// Which backend produced the last utterance.
enum VoiceRoute { murya, system, mixed, none }

/// User-selectable voice profile (mirrors `developerVoice` / `systemVoice` in
/// the React drawer).
enum VoiceMode {
  natural('natural'),
  system('system');

  const VoiceMode(this.storageValue);

  final String storageValue;

  static VoiceMode fromStorage(String? value) =>
      value == 'system' ? VoiceMode.system : VoiceMode.natural;
}

/// Routes text to Murya (native Hausa ONNX voice) and/or the device voice.
///
/// Rules implemented here (spec step 3-B):
///
/// 1. **English mode** — raw text goes straight to [SystemTtsEngine].
/// 2. **Hausa mode** — text is normalised by [TextPreprocessor], then split
///    into Hausa / English chunks by [TtsChunker]. Hausa chunks go to Murya,
///    leftover English words to the device voice so they are not butchered.
/// 3. **Fallback** — if Murya throws or needs more than [muryaBudget] to
///    generate audio, the *entire remaining text* is delegated to
///    [SystemTtsEngine] and Murya is skipped for the rest of that utterance.
class HybridTtsService extends ChangeNotifier {
  HybridTtsService({
    SystemTtsEngine? system,
    MuryaTtsEngine? murya,
    this.muryaBudget = const Duration(seconds: 2),
  })  : system = system ?? SystemTtsEngine(),
        murya = murya ?? MuryaTtsEngine();

  final SystemTtsEngine system;
  final MuryaTtsEngine murya;

  /// Generation budget before falling back to the device voice.
  final Duration muryaBudget;

  /// Longest Hausa run handed to Murya in one call (see
  /// [TtsChunker.maxCharsPerRequest]).
  static const int maxCharsPerRequest = TtsChunker.maxCharsPerRequest;

  static const String _modeKey = 'smartvillage.voice_mode';
  static const String _speakerKey = 'smartvillage.murya_speaker';

  VoiceMode _mode = VoiceMode.natural;
  int? _speakerOverride;
  bool _isSpeaking = false;
  bool _muryaUsable = true;
  bool _warmStarted = false;
  VoiceRoute _lastRoute = VoiceRoute.none;
  String? _statusMessage;
  int _generation = 0;

  VoiceMode get mode => _mode;
  bool get isSpeaking => _isSpeaking;
  bool get muryaUsable => _muryaUsable;
  VoiceRoute get lastRoute => _lastRoute;
  String? get statusMessage => _statusMessage;

  /// Speaker id chosen by the user (Murya ships 8 voices).
  int? get speakerOverride => _speakerOverride;

  /// The voice that will actually be used once the model is loaded.
  int? get activeSpeaker => murya.speakerId;

  /// Voice names available once the model is warm (`M1`, `F2`, …).
  List<MapEntry<String, int>> get availableSpeakers => murya.config.speakers;

  String get activeSpeakerName => murya.config.defaultSpeakerName;

  /// True when the native model assets are present and the isolate is up.
  bool get muryaReady => murya.isReady;

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = VoiceMode.fromStorage(prefs.getString(_modeKey));
      _speakerOverride = prefs.getInt(_speakerKey);
      murya.setSpeaker(_speakerOverride);
      notifyListeners();
    } catch (error) {
      debugPrint('[HybridTts] prefs load failed: $error');
    }
  }

  Future<void> setMode(VoiceMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.storageValue);
    } catch (error) {
      debugPrint('[HybridTts] prefs save failed: $error');
    }
  }

  /// Selects one of Murya's eight voices. Persisted for the next launch.
  Future<void> setSpeaker(int? id) async {
    _speakerOverride = id;
    murya.setSpeaker(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_speakerKey);
      } else {
        await prefs.setInt(_speakerKey, id);
      }
    } catch (error) {
      debugPrint('[HybridTts] speaker save failed: $error');
    }
  }

  /// Loads the ONNX model ahead of time (e.g. when Hausa is selected) so the
  /// first tap is not delayed by cold-start.
  Future<void> warmUpMurya() async {
    if (_warmStarted || !_muryaUsable) return;
    _warmStarted = true;
    try {
      await murya.warmUp();
      murya.setSpeaker(_speakerOverride);
      _statusMessage = murya.config.isMultiSpeaker
          ? 'Murya ready (${murya.config.numSpeakers} voices, '
              '${murya.config.defaultSpeakerName})'
          : 'Murya ready';
    } catch (error) {
      _muryaUsable = false;
      _statusMessage = '$error';
      debugPrint('[HybridTts] Murya unavailable, device voice only: $error');
    }
    notifyListeners();
  }

  /// Speaks [text] honouring the active language and voice profile.
  Future<void> speak(
    String text, {
    required AppLanguage language,
    VoiceMode? modeOverride,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await stop();
    final generation = ++_generation;
    final mode = modeOverride ?? _mode;
    _isSpeaking = true;
    _lastRoute = VoiceRoute.none;
    notifyListeners();

    try {
      if (!language.isHausa || mode == VoiceMode.system) {
        // Rule B.1 — English mode passes raw text untouched.
        _lastRoute = VoiceRoute.system;
        await system.speak(trimmed, language: language.ttsLocale);
      } else {
        await _speakHausa(trimmed, generation);
      }
    } catch (error) {
      debugPrint('[HybridTts] speak failed: $error');
      _statusMessage = 'Voice error: $error';
      // Never leave the user in silence if the platform voice can help.
      try {
        await system.speak(trimmed, language: 'en-NG');
        _lastRoute = VoiceRoute.system;
      } catch (_) {
        // Nothing else we can do offline.
      }
    } finally {
      if (generation == _generation) {
        _isSpeaking = false;
        notifyListeners();
      }
    }
  }

  Future<void> _speakHausa(String text, int generation) async {
    final preprocessed = TextPreprocessor.normalize(text);
    final chunks = TtsChunker.split(preprocessed);

    if (chunks.isEmpty) {
      _lastRoute = VoiceRoute.system;
      await system.speak(preprocessed, language: 'ha-NG');
      return;
    }

    // Long runs are split into sentence-sized pieces so one slow synthesis
    // cannot burn the whole budget on a weak device.
    final parts = <TtsChunk>[];
    for (final chunk in chunks) {
      if (chunk.isHausa) {
        parts.addAll(TtsChunker.splitForSynthesis(chunk));
      } else {
        parts.add(chunk);
      }
    }

    var usedMurya = false;
    var usedSystem = false;

    for (var i = 0; i < parts.length; i++) {
      if (generation != _generation) return; // superseded by a newer request
      final chunk = parts[i];

      final mustUseSystem = !chunk.isHausa || !_muryaUsable;
      if (mustUseSystem) {
        usedSystem = true;
        _lastRoute = usedMurya ? VoiceRoute.mixed : VoiceRoute.system;
        await system.speak(
          chunk.text,
          language: chunk.isHausa ? 'ha-NG' : 'en-NG',
        );
        continue;
      }

      try {
        final wav = await murya.synthesize(chunk.text).timeout(muryaBudget);
        if (generation != _generation) return;
        usedMurya = true;
        _lastRoute = usedSystem ? VoiceRoute.mixed : VoiceRoute.murya;
        await murya.playWav(wav);
      } catch (error) {
        _muryaUsable = false;
        _statusMessage = error is MuryaTimeoutException
            ? 'Murya took > ${muryaBudget.inSeconds}s — using device voice'
            : 'Murya unavailable — using device voice';
        debugPrint('[HybridTts] falling back: $error');

        // Rule B.3 — hand the ENTIRE remaining text to the device voice.
        final remaining = parts
            .sublist(i)
            .map((c) => c.text)
            .join(' ')
            .trim();
        _lastRoute = usedMurya ? VoiceRoute.mixed : VoiceRoute.system;
        try {
          await system.speak(remaining, language: 'ha-NG');
        } catch (_) {
          await system.speak(remaining, language: 'en-NG');
        }
        notifyListeners();
        return;
      }
    }

    if (usedMurya && usedSystem) {
      _lastRoute = VoiceRoute.mixed;
    } else if (usedMurya) {
      _lastRoute = VoiceRoute.murya;
    } else if (usedSystem) {
      _lastRoute = VoiceRoute.system;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _generation++;
    _isSpeaking = false;
    await Future.wait<void>(<Future<void>>[
      murya.stop().catchError((Object error) {
        debugPrint('[HybridTts] murya stop: $error');
      }),
      system.stop(),
    ]);
    notifyListeners();
  }

  /// Full-text plan the router would use, handy for the Voice Profile screen
  /// and for widget tests.
  List<TtsChunk> previewChunks(String text, AppLanguage language) {
    if (!language.isHausa) {
      return <TtsChunk>[
        TtsChunk(text: text, language: ChunkLanguage.english),
      ];
    }
    return TtsChunker.split(TextPreprocessor.normalize(text));
  }

  @override
  void dispose() {
    // Fire and forget: the platform channels clean up asynchronously.
    murya.dispose();
    system.dispose();
    super.dispose();
  }
}
