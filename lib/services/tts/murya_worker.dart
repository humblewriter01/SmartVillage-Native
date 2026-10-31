/// Background-isolate worker for the Murya Hausa ONNX voice.
///
/// Everything ONNX-related lives in this file and runs inside a dedicated
/// isolate so that:
/// * the UI thread never blocks while the model runs inference (spec C), and
/// * the ~22 MB INT8 model is loaded exactly once per app session.
library;

import 'dart:isolate';
import 'dart:typed_data';

import 'package:onnxruntime/onnxruntime.dart';

import 'murya_config.dart';
import 'murya_pcm.dart';

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
    message: config.isMultiSpeaker
        ? 'ready (${config.numSpeakers} speakers, default '
            '${config.defaultSpeakerName})'
        : 'ready',
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
    return float32ToWav(samples, config.sampleRate);
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
