/// Common contract for every voice backend used by SmartVillage.
library;

abstract class TtsEngine {
  /// Human readable identifier used in the Voice Profile screen.
  String get id;

  /// Whether this engine can currently produce audio on this device.
  Future<bool> isAvailable();

  /// Speaks [text]. Completes when the utterance finishes (or when the engine
  /// is unable to synthesise, in which case it throws).
  ///
  /// [rate] follows the `flutter_tts` scale where `0.5` is conversational
  /// speed — the default, because farm and health advice has to be understood
  /// on the first listen.
  Future<void> speak(
    String text, {
    required String language,
    double rate = 0.5,
    double pitch = 1.0,
  });

  Future<void> stop();

  Future<void> dispose();
}

class TtsUnavailableException implements Exception {
  TtsUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'TtsUnavailableException: $message';
}

class MuryaUnavailableException extends TtsUnavailableException {
  MuryaUnavailableException(super.message);
}

class MuryaTimeoutException extends TtsUnavailableException {
  MuryaTimeoutException(super.message);
}
