/// Background-isolate worker for the Murya Hausa ONNX voice.
///
/// Everything ONNX-related lives in this file and runs inside a dedicated
/// isolate so that:
/// * the UI thread never blocks while the model runs inference (spec C), and
/// * the ~60 MB model is loaded exactly once per app session.
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'murya_config.dart';

/// Message sent from the UI isolate to start the worker.
class MuryaInitRequest {
  MuryaInitRequest({
    required this.sendPort,
    required this.modelBytes,
    required this.configJson,
  });

  final SendPort sendPort;
  final Uint8List modelBytes;
  final String? configJson;
}

class MuryaSynthesisRequest {
  MuryaSynthesisRequest({
    required this.id,
    required this.tokenIds,
    this.speakerId,
  });

  final int id;
  final List<int> tokenIds;
  final int? speakerId;
}

/// Result payload returned from the worker.
class MuryaWorkerReply {
  MuryaWorkerReply({
    required this.type,
    this.id,
    this.wav,
    this.message,
    this.error,
    this.sampleRate,
    this.port,
  });

  /// `ready`, `audio`, `error`, `log`.
  final String type;
  final int? id;
  final Uint8List? wav;
  final String? message;
  final String? error;
  final int? sampleRate;

  /// Handshake port; only present on the `ready` reply.
  final SendPort? port;
}

const String _kReady = 'ready';
const String _kAudio = 'audio';
const String _kError = 'error';
const String _kLog = 'log';

/// Entry point executed inside the background isolate.
Future<void> muryaIsolateMain(MuryaInitRequest request) async {
  final mainSend = request.sendPort;

  void log(String message) {
    mainSend.send(MuryaWorkerReply(type: _kLog, message: message));
  }

  OrtSession? session;
  MuryaConfig config = MuryaConfig.defaults();
  List<String> inputNames = const <String>[];

  try {
    config = MuryaConfig.parse(request.configJson);
    OrtEnv.instance.init();
    final options = OrtSessionOptions();
    session = OrtSession.fromBuffer(request.modelBytes, options);
    inputNames = session.inputNames ?? const <String>[];
    if (inputNames.isEmpty) inputNames = config.inputNames;
    log('Murya model loaded (${inputNames.join(', ')})');
  } catch (error) {
    mainSend.send(MuryaWorkerReply(
      type: _kError,
      error: 'Failed to load murya.onnx: $error',
    ));
    return;
  }

  final receivePort = ReceivePort();
  mainSend.send(MuryaWorkerReply(
    type: _kReady,
    message: 'ready',
    sampleRate: config.sampleRate,
    port: receivePort.sendPort,
  ));

  await for (final dynamic raw in receivePort) {
    if (raw is! MuryaSynthesisRequest) continue;

    try {
      final wav = _synthesize(
        session: session!,
        config: config,
        inputNames: inputNames,
        request: raw,
      );
      mainSend.send(MuryaWorkerReply(
        type: _kAudio,
        id: raw.id,
        wav: wav,
        sampleRate: config.sampleRate,
      ));
    } catch (error) {
      mainSend.send(MuryaWorkerReply(
        type: _kError,
        id: raw.id,
        error: 'Murya inference failed: $error',
      ));
    }
  }
}

Uint8List _synthesize({
  required OrtSession session,
  required MuryaConfig config,
  required List<String> inputNames,
  required MuryaSynthesisRequest request,
}) {
  final ids = Int64List.fromList(request.tokenIds);
  final inputs = <String, OrtValue>{};

  // Build every graph input the session declares. Piper exports three inputs
  // (input, input_lengths, scales); character models often declare one.
  for (final name in inputNames) {
    switch (name) {
      case 'input':
      case 'input_ids':
      case 'tokens':
      case 'x':
      case 'text':
        inputs[name] = OrtValueTensor.createTensorWithDataList(
          ids,
          <int>[1, ids.length],
        );
        break;
      case 'input_lengths':
      case 'lengths':
      case 'x_lengths':
        final lengths = Int64List.fromList(<int>[ids.length]);
        inputs[name] = OrtValueTensor.createTensorWithDataList(
          lengths,
          <int>[1],
        );
        break;
      case 'scales':
        final scales = Float32List.fromList(<double>[
          config.noiseScale,
          config.lengthScale,
          config.noiseW,
        ]);
        inputs[name] = OrtValueTensor.createTensorWithDataList(
          scales,
          <int>[3],
        );
        break;
      case 'sid':
      case 'speaker_id':
      case 'speaker':
        final sid = Int64List.fromList(
          <int>[request.speakerId ?? config.defaultSpeakerId ?? 0],
        );
        inputs[name] = OrtValueTensor.createTensorWithDataList(
          sid,
          <int>[1],
        );
        break;
      default:
        // Unknown input: assume it wants the token sequence.
        inputs[name] = OrtValueTensor.createTensorWithDataList(
          ids,
          <int>[1, ids.length],
        );
    }
  }

  if (inputs.isEmpty) {
    inputs['input'] = OrtValueTensor.createTensorWithDataList(
      ids,
      <int>[1, ids.length],
    );
  }

  final runOptions = OrtRunOptions();
  List<OrtValue?> outputs = const <OrtValue?>[];
  try {
    outputs = session.run(runOptions, inputs);
    if (outputs == null || outputs.isEmpty) {
      throw StateError('model returned no output');
    }

    final first = outputs.first;
    final raw = first?.value;
    final samples = _extractFloat32(raw);
    if (samples.isEmpty) {
      throw StateError('model returned empty audio');
    }
    return _float32ToWav(samples, config.sampleRate);
  } finally {
    for (final input in inputs.values) {
      input.release();
    }
    // Output tensors hold native memory too: release them or a long reading
    // session leaks tens of megabytes.
    for (final output in outputs) {
      output?.release();
    }
    runOptions.release();
  }
}

/// Accepts the many shapes ONNX runtimes return for audio tensors.
List<double> _extractFloat32(dynamic value) {
  if (value == null) return const <double>[];

  if (value is Float32List) return value.map((e) => e.toDouble()).toList();

  if (value is List) {
    final flat = <double>[];
    void walk(dynamic node) {
      if (node == null) return;
      if (node is num) {
        flat.add(node.toDouble());
      } else if (node is List) {
        for (final child in node) {
          walk(child);
        }
      } else if (node is Float32List || node is Int32List) {
        for (final child in (node as List)) {
          if (child is num) flat.add(child.toDouble());
        }
      }
    }

    walk(value);
    return flat;
  }

  return const <double>[];
}

/// Minimal 16-bit PCM WAV encoder (no plugin, no native bridge).
Uint8List _float32ToWav(List<double> samples, int sampleRate) {
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
    final clamped = math.max(-1.0, math.min(1.0, sample));
    byteData.setInt16(
      offset,
      (clamped * 32767).round(),
      Endian.little,
    );
    offset += 2;
  }

  return byteData.buffer.asUint8List();
}

/// Simple grapheme-level tokenizer used when the model does not ship a phoneme
/// table. Exposed for tests.
@visibleForTesting
List<int> debugTokenize(String text, MuryaConfig config) =>
    buildTokenIds(text, config);

/// Converts Hausa text into the token ids the ONNX graph expects.
List<int> buildTokenIds(String text, MuryaConfig config) {
  final ids = <int>[];

  if (config.phonemeIdMap.isNotEmpty) {
    final lookup = config.phonemeIdMap.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );

    void add(String phoneme) {
      final row = lookup[phoneme] ?? lookup[phoneme.toLowerCase()];
      if (row == null || row.isEmpty) return;
      ids.addAll(row);
      // Piper intersperses the pad token between phonemes.
      if (phoneme.trim().isNotEmpty) ids.add(MuryaConfig.padId);
    }

    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty) {
        add(' ');
        continue;
      }
      add(char);
      // Handle digraphs written with an apostrophe/glottal mark.
      if (char == '\'') add('ˈ');
    }
    return ids.isEmpty ? _charLevel(text, config) : ids;
  }

  return _charLevel(text, config);
}

List<int> _charLevel(String text, MuryaConfig config) {
  if (config.characters.isEmpty) {
    // Deterministic fallback alphabet: stable across sessions so the model
    // receives consistent ids even without metadata.
    const fallback =
        " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?;:'-"
        "ɓɗƙƴƁƊƘƳ";
    final index = <String, int>{};
    for (var i = 0; i < fallback.length; i++) {
      index[fallback[i]] = i + 1;
    }
    return text
        .split('')
        .map((c) => index[c] ?? index[' '] ?? 0)
        .where((id) => id > 0)
        .toList(growable: false);
  }

  final index = <String, int>{};
  for (var i = 0; i < config.characters.length; i++) {
    index[config.characters[i]] = i;
  }
  return text
      .split('')
      .map((c) => index[c])
      .whereType<int>()
      .toList(growable: false);
}
