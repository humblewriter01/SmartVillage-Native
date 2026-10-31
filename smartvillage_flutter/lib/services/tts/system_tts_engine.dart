import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Thin wrapper around the device TTS engine (`flutter_tts`).
///
/// Responsibilities:
/// * English mode: speak the raw text untouched (spec rule B.1).
/// * Hausa mode: act as the fallback voice when Murya is missing, slow
///   (> 2 s) or crashes — the app must never go silent in the field.
class SystemTtsEngine implements TtsEngine {
  SystemTtsEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;
  String _lastLanguage = 'en-NG';

  @override
  String get id => 'system';

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.awaitSpeakCompletion(true);
    try {
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5); // flutter_tts maps 0.5 => ~150 wpm
    } catch (error) {
      debugPrint('[SystemTtsEngine] configuration failed: $error');
    }
    _configured = true;
  }

  @override
  Future<bool> isAvailable() async {
    try {
      final languages = await _tts.getLanguages;
      return languages is List && languages.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Device voices installed on rural Android phones are often English-only.
  /// Returns the list of ISO codes the platform reports.
  Future<List<String>> availableLanguages() async {
    try {
      final languages = await _tts.getLanguages;
      if (languages is List) {
        return languages.map((e) => e.toString()).toList(growable: false);
      }
    } catch (error) {
      debugPrint('[SystemTtsEngine] getLanguages failed: $error');
    }
    return const <String>[];
  }

  /// True when a Hausa voice pack is installed (most devices: false).
  Future<bool> hasHausaVoice() async {
    final languages = await availableLanguages();
    return languages.any((code) => code.toLowerCase().startsWith('ha'));
  }

  @override
  Future<void> speak(
    String text, {
    required String language,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    if (text.trim().isEmpty) return;
    await _configure();
    _lastLanguage = language;

    try {
      await _tts.setLanguage(language);
    } catch (error) {
      // Language pack missing -> retry with Nigerian English.
      debugPrint('[SystemTtsEngine] setLanguage($language) failed: $error');
      await _tts.setLanguage('en-NG');
    }

    try {
      // flutter_tts expects 0.0-1.0 where 0.5 is "normal"; clamp user rates.
      await _tts.setSpeechRate(rate.clamp(0.1, 1.0));
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
      await _tts.speak(text);
    } catch (error) {
      // Last-resort: English, because a wrong accent beats silence.
      if (!_lastLanguage.startsWith('en')) {
        try {
          await _tts.setLanguage('en-US');
          await _tts.speak(text);
          return;
        } catch (_) {
          // fall through
        }
      }
      throw TtsUnavailableException('System TTS failed: $error');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (error) {
      debugPrint('[SystemTtsEngine] stop failed: $error');
    }
  }

  @override
  Future<void> dispose() => stop();
}
