import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'murya_config.dart';
import 'murya_worker.dart';
import 'tts_engine.dart';

/// Native Hausa voice (Murya) running on onnxruntime.
///
/// * The ONNX graph is loaded once, inside a background isolate, so inference
///   never touches the UI thread.
/// * Output (Float32 PCM) is wrapped into a WAV container and played with
///   `audioplayers` — no extra audio plugin needed.
/// * Every failure path raises [MuryaUnavailableException] so the hybrid
///   service can transparently fall back to the device voice.
class MuryaTtsEngine implements TtsEngine {
  MuryaTtsEngine({
    AudioPlayer? player,
    this.modelAsset = 'assets/models/murya.onnx',
    this.configAsset = 'assets/models/murya.onnx.json',
  }) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final String modelAsset;
  final String configAsset;

  Isolate? _isolate;
  SendPort? _commandPort;
  ReceivePort? _replyPort;
  final Map<int, Completer<Uint8List>> _pending =
      <int, Completer<Uint8List>>{};
  /// Recreated for every load attempt: a failed attempt must not leave a
  /// completed completer behind for the next one.
  Completer<void> _readyCompleter = Completer<void>();

  int _nextRequestId = 1;
  bool _loading = false;
  String? _lastError;
  MuryaConfig _config = MuryaConfig.defaults();
  int _sampleRate = 22050;

  @override
  String get id => 'murya';

  /// Why the engine is unavailable, when it is.
  String? get lastError => _lastError;

  bool get isReady => _commandPort != null && _readyCompleter.isCompleted;

  int get sampleRate => _sampleRate;

  MuryaConfig get config => _config;

  /// Loads the model exactly once. Safe to call repeatedly.
  Future<void> warmUp() async {
    if (isReady) return;
    if (_loading) {
      await _readyCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {},
      );
      if (_commandPort == null) {
        throw MuryaUnavailableException(
          _lastError ?? 'Murya model is still loading',
        );
      }
      return;
    }

    _loading = true;
    try {
      final modelBytes = await _loadAssetBytes(modelAsset);
      final configJson = await _tryLoadString(configAsset);
      _config = MuryaConfig.parse(configJson);
      _sampleRate = _config.sampleRate;

      _readyCompleter = Completer<void>();
      _replyPort?.close();
      _replyPort = ReceivePort();
      _replyPort!.listen(_handleReply);

      _isolate = await Isolate.spawn(
        muryaIsolateMain,
        MuryaInitRequest(
          sendPort: _replyPort!.sendPort,
          modelBytes: modelBytes,
          configJson: configJson,
        ),
        debugName: 'murya-onnx-worker',
        errorsAreFatal: false,
      );

      await _readyCompleter.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () {},
      );
      if (_commandPort == null) {
        throw MuryaUnavailableException(
          _lastError ?? 'Murya isolate did not become ready within 25s',
        );
      }
    } catch (error) {
      _lastError = error.toString();
      _teardown();
      rethrow;
    } finally {
      _loading = false;
    }
  }

  Future<Uint8List> _loadAssetBytes(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (bytes.isEmpty) {
        throw MuryaUnavailableException('$asset is empty');
      }
      return bytes;
    } catch (error) {
      throw MuryaUnavailableException(
        '$asset could not be loaded ($error). '
        'Drop murya.onnx + murya.onnx.json into assets/models/ and re-run '
        '`flutter pub get && flutter run`.',
      );
    }
  }

  Future<String?> _tryLoadString(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } catch (_) {
      return null;
    }
  }

  void _handleReply(dynamic message) {
    if (message is! MuryaWorkerReply) return;
    switch (message.type) {
      case 'ready':
        _commandPort = message.port;
        if (message.sampleRate != null) _sampleRate = message.sampleRate!;
        if (!_readyCompleter.isCompleted) _readyCompleter.complete();
        break;
      case 'audio':
        final completer = _pending.remove(message.id);
        final wav = message.wav;
        if (completer != null) {
          if (wav == null) {
            completer.completeError(
              MuryaUnavailableException('Murya returned no audio bytes'),
            );
          } else {
            completer.complete(wav);
          }
        }
        break;
      case 'error':
        _lastError = message.error;
        debugPrint('[Murya] ${message.error}');
        final completer = _pending.remove(message.id);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(
            MuryaUnavailableException(message.error ?? 'unknown Murya error'),
          );
        }
        if (!_readyCompleter.isCompleted &&
            (message.id == null || _pending.isEmpty)) {
          // Initialisation failure: unblock the waiter; warmUp() then sees a
          // null command port and raises the typed exception.
          _readyCompleter.complete();
        }
        break;
      case 'log':
        debugPrint('[Murya] ${message.message}');
        break;
      default:
        break;
    }
  }

  /// Synthesises [text] to WAV bytes. Throws when the model is unavailable.
  Future<Uint8List> synthesize(String text) async {
    await warmUp();
    final port = _commandPort;
    if (port == null) {
      throw MuryaUnavailableException(
        _lastError ?? 'Murya isolate is not running',
      );
    }

    final ids = buildTokenIds(text, _config);
    if (ids.isEmpty) {
      throw MuryaUnavailableException('Nothing to synthesise for "$text"');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<Uint8List>();
    _pending[requestId] = completer;
    port.send(
      MuryaSynthesisRequest(
        id: requestId,
        tokenIds: ids,
        speakerId: _config.defaultSpeakerId,
      ),
    );

    final preview =
        text.length > 24 ? '${text.substring(0, 24)}...' : text;
    try {
      return await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      _pending.remove(requestId);
      throw MuryaTimeoutException(
        'Murya inference timed out for "$preview"',
      );
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        await warmUp();
        return isReady;
      } catch (_) {
        return false;
      }
    }
    return isReady;
  }

  /// Plays already-synthesised WAV bytes (used by the hybrid router so the
  /// 2-second generation budget can be enforced separately from playback).
  Future<void> playWav(Uint8List wav) async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.play(BytesSource(wav, mimeType: 'audio/wav'));
  }

  /// Speaks [text] with the native Hausa voice.
  ///
  /// The [language] argument is accepted for interface parity; Murya only
  /// speaks Hausa.
  @override
  Future<void> speak(
    String text, {
    required String language,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    final wav = await synthesize(text);
    // audioplayers 6.x accepts raw bytes; a WAV container is self-describing.
    await playWav(wav);
  }

  @override
  Future<void> stop() async {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          MuryaUnavailableException('cancelled'),
        );
      }
    }
    _pending.clear();
    try {
      await _player.stop();
    } catch (error) {
      debugPrint('[Murya] player stop failed: $error');
    }
  }

  void _teardown() {
    _commandPort = null;
    _replyPort?.close();
    _replyPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  @override
  Future<void> dispose() async {
    await stop();
    _teardown();
    try {
      await _player.dispose();
    } catch (error) {
      debugPrint('[Murya] player dispose failed: $error');
    }
  }
}
