/// Pure-Dart half of the Murya pipeline: text → Piper token ids, and
/// `Float32` samples → 16-bit PCM WAV.
///
/// Deliberately free of any plugin import (`onnxruntime`, `audioplayers`) so it
/// can be unit-tested on the host without a device, and so the isolate worker
/// stays a thin wrapper around ONNX Runtime.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'murya_config.dart';

/// Converts Hausa text into the token ids the ONNX graph expects.
///
/// The layout is the one every Piper export is trained on
/// (`piper.cpp::phonemes_to_ids`):
///
/// ```text
///   BOS  id_1  PAD  id_2  PAD  ...  id_n  PAD  EOS
/// ```
///
/// Getting this wrong is the classic reason a Piper model "runs" but produces
/// noise or silence, so the ordering is covered by `test/murya_tokenizer_test.dart`.
///
/// Characters missing from `phoneme_id_map` are dropped rather than replaced:
/// the pre-processor has already expanded digits, removed hyphens and spelled
/// loanwords, so anything left over is punctuation the model cannot voice.
List<int> buildTokenIds(String text, MuryaConfig config) {
  if (text.trim().isEmpty) return const <int>[];

  final map = config.phonemeIdMap;
  if (map.isEmpty) return _charLevelIds(text, config);

  final ids = <int>[];

  List<int>? rowOf(String key) {
    final row = map[key];
    return row == null || row.isEmpty ? null : row;
  }

  final pad = rowOf('_') ?? <int>[config.padId];
  final bos = rowOf('^') ?? <int>[config.bosId];
  final eos = rowOf(r'$') ?? <int>[config.eosId];

  var voiced = 0;
  ids.addAll(bos);

  // Iterating runes (not UTF-16 units) keeps hooked letters — ɓ ɗ ƙ ƴ — whole.
  for (final rune in text.toLowerCase().runes) {
    var char = String.fromCharCode(rune);

    // Normalise the typographic apostrophes that survive text input.
    if (char == '\u2019' || char == '\u2018' || char == '\u02bc') {
      char = "'";
    }

    final row = rowOf(char);
    if (row == null) continue;

    ids.addAll(row);
    ids.addAll(pad);
    voiced++;
  }

  // Nothing pronounceable (e.g. "..."): report emptiness so the caller can fall
  // back instead of asking the model to vocalise pure silence.
  if (voiced == 0) return const <int>[];

  ids.addAll(eos);
  return ids;
}

/// Fallback for character models that ship a vocabulary list but no id map.
List<int> _charLevelIds(String text, MuryaConfig config) {
  if (config.characters.isEmpty) return const <int>[];

  final index = <String, int>{};
  for (var i = 0; i < config.characters.length; i++) {
    index[config.characters[i]] = i;
  }

  return text
      .toLowerCase()
      .runes
      .map((rune) => index[String.fromCharCode(rune)])
      .whereType<int>()
      .toList(growable: false);
}

/// Minimal 16-bit mono PCM WAV encoder (no plugin, no native bridge).
///
/// `audioplayers` can play raw bytes, but a self-describing WAV container means
/// the platform decoder gets the sample rate and channel count right without us
/// guessing.
Uint8List float32ToWav(List<double> samples, int sampleRate) {
  final byteData = ByteData(44 + samples.length * 2);
  final dataLength = samples.length * 2;

  void writeString(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      byteData.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  byteData.setUint32(4, 36 + dataLength, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  byteData.setUint32(16, 16, Endian.little); // PCM chunk size
  byteData.setUint16(20, 1, Endian.little); // audio format = PCM
  byteData.setUint16(22, 1, Endian.little); // mono
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  byteData.setUint16(32, 2, Endian.little); // block align
  byteData.setUint16(34, 16, Endian.little); // bits per sample
  writeString(36, 'data');
  byteData.setUint32(40, dataLength, Endian.little);

  var offset = 44;
  for (final sample in samples) {
    // Clamp before scaling: VITS occasionally overshoots past ±1.0.
    final clamped = math.max(-1.0, math.min(1.0, sample));
    byteData.setInt16(offset, (clamped * 32767).round(), Endian.little);
    offset += 2;
  }

  return byteData.buffer.asUint8List();
}
