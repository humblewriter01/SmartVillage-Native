import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartvillage/services/tts/murya_config.dart';
import 'package:smartvillage/services/tts/murya_pcm.dart';

/// Minimal stand-in config that mirrors the real Murya layout
/// (`_`=0, `^`=1, `$`=2, space=3, a=12 …) so the token order can be asserted
/// without loading a 21 MB graph.
MuryaConfig _stubConfig() => const MuryaConfig(
      sampleRate: 22050,
      phonemeIdMap: <String, List<int>>{
        '_': <int>[0],
        '^': <int>[1],
        r'$': <int>[2],
        ' ': <int>[3],
        'a': <int>[12],
        'b': <int>[13],
        'n': <int>[25],
        's': <int>[28],
        'u': <int>[30],
        'ƙ': <int>[36],
      },
      characters: <String>[],
      inputNames: <String>['input', 'input_lengths', 'scales', 'sid'],
      lengthScale: 1,
      noiseScale: 0.667,
      noiseW: 0.8,
      numSpeakers: 8,
      speakerIdMap: <String, int>{'F2': 0, 'M3': 1, 'M2': 2, 'M1': 6, 'F3': 7},
      defaultSpeakerId: 6,
      padId: 0,
      bosId: 1,
      eosId: 2,
      phonemeType: 'text',
      languageCode: 'ha',
      modelName: 'murya',
    );

void main() {
  group('Piper token layout', () {
    test('wraps the phrase in BOS/PAD/EOS', () {
      expect(
        buildTokenIds('ba', _stubConfig()),
        <int>[1, 13, 0, 12, 0, 2],
      );
    });

    test('keeps hooked letters whole', () {
      expect(
        buildTokenIds('ƙa', _stubConfig()),
        <int>[1, 36, 0, 12, 0, 2],
      );
    });

    test('lower-cases and pads repeated characters', () {
      expect(
        buildTokenIds('Sannu', _stubConfig()),
        <int>[1, 28, 0, 12, 0, 25, 0, 25, 0, 30, 0, 2],
      );
    });

    test('drops characters the model cannot voice', () {
      // Digits/emoji never reach the model: the pre-processor expands them,
      // and anything left is skipped rather than read as noise.
      expect(buildTokenIds('7', _stubConfig()), isEmpty);
      expect(buildTokenIds('   ', _stubConfig()), isEmpty);
      expect(buildTokenIds('', _stubConfig()), isEmpty);
    });

    test('normalises typographic apostrophes', () {
      final config = _stubConfig();
      final straight = buildTokenIds("'a", config);
      // The stub has no apostrophe id, so both must collapse to the same ids.
      expect(buildTokenIds('\u2019a', config), straight);
      expect(straight, <int>[1, 12, 0, 2]);
    });

    test('returns empty when no phoneme map is available', () {
      final bare = MuryaConfig.defaults();
      expect(buildTokenIds('ba', bare), isEmpty);
    });
  });

  group('config parsing', () {
    test('reads the shipped murya.onnx.json', () {
      final file = File('assets/models/murya.onnx.json');
      expect(file.existsSync(), isTrue,
          reason: 'assets/models/murya.onnx.json must be committed');

      final config = MuryaConfig.parse(file.readAsStringSync());

      expect(config.sampleRate, 22050);
      expect(config.numSpeakers, 8);
      expect(config.phonemeType, 'text');
      expect(config.languageCode, 'ha');
      expect(config.padId, 0);
      expect(config.bosId, 1);
      expect(config.eosId, 2);
      expect(config.phonemeIdMap['a'], <int>[12]);
      expect(config.phonemeIdMap['ɓ'], <int>[34]);
      expect(config.phonemeIdMap['ƙ'], <int>[36]);
      expect(config.lengthScale, 1.0);
      expect(config.noiseScale, 0.667);
      expect(config.noiseW, 0.8);

      // M1 is the male Kano narration voice the app defaults to.
      expect(config.defaultSpeakerId, 6);
      expect(config.defaultSpeakerName, 'M1');
      expect(config.isMultiSpeaker, isTrue);
      expect(config.speakers.first.key, 'F2');
      expect(config.speakers.last.key, 'F3');
    });

    test('tokenises a real phrase with the shipped config', () {
      final config = MuryaConfig.parse(
        File('assets/models/murya.onnx.json').readAsStringSync(),
      );
      final ids = buildTokenIds('ba', config);
      expect(ids, <int>[1, 13, 0, 12, 0, 2]);
      expect(buildTokenIds('ƙasa', config),
          <int>[1, 36, 0, 12, 0, 28, 0, 12, 0, 2]);
    });

    test('falls back to defaults on broken JSON', () {
      final config = MuryaConfig.parse('{not json');
      expect(config.sampleRate, 22050);
      expect(config.numSpeakers, 1);
      expect(config.defaultSpeakerId, isNull);
      expect(config.padId, 0);
    });

    test('accepts a speaker chosen by name', () {
      final config = MuryaConfig.parse(
        '{"phoneme_id_map":{"_":[0],"^":[1],"\$":[2],"a":[12]},'
        '"num_speakers":8,'
        '"speaker_id_map":{"M1":6,"F1":5},'
        '"speaker_id":"F1"}',
      );
      expect(config.defaultSpeakerId, 5);
      expect(config.defaultSpeakerName, 'F1');
    });
  });

  group('shipped model asset', () {
    // Guards CI: the graph is 21.7 MB, so a truncated upload or an LFS pointer
    // would otherwise only fail on a phone at speech time.
    final model = File('assets/models/murya.onnx');

    test('murya.onnx is committed', () {
      expect(model.existsSync(), isTrue,
          reason: 'assets/models/murya.onnx must be in the repository');
    });

    test('murya.onnx is a plausible INT8 graph', () {
      if (!model.existsSync()) return;
      final size = model.lengthSync();
      expect(size, greaterThan(15 * 1024 * 1024),
          reason: 'far smaller than the 21.7 MB quantised graph');
      expect(size, lessThan(80 * 1024 * 1024),
          reason: 'larger than the 77 MB FP32 upstream export');

      final raf = model.openSync();
      try {
        final header = raf.readSync(32);
        // ONNX is protobuf; field 1 (ir_version) is a varint, so byte 0 is 0x08.
        expect(header.first, 0x08, reason: 'not an ONNX protobuf');
        final ascii = String.fromCharCodes(header);
        expect(ascii.contains('onnx'), isTrue,
            reason: 'expected the onnx producer string in the header');
      } finally {
        raf.closeSync();
      }
    });

    test('the graph and the config agree on speakers and rate', () {
      if (!model.existsSync()) return;
      final config = MuryaConfig.parse(
        File('assets/models/murya.onnx.json').readAsStringSync(),
      );
      expect(config.sampleRate, 22050);
      expect(config.numSpeakers, 8);
      expect(config.speakers.length, 8);
      expect(config.defaultSpeakerName, 'M1');
      expect(config.phonemeIdMap.length, greaterThanOrEqualTo(42));
    });
  });

  group('WAV encoding', () {
    test('writes a valid 16-bit mono header', () {
      final samples = <double>[0.0, 0.5, -0.5, 1.5, -1.5];
      final wav = float32ToWav(samples, 22050);
      final data = ByteData.sublistView(wav);

      expect(wav.length, 44 + samples.length * 2);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');

      expect(data.getUint16(20, Endian.little), 1); // PCM
      expect(data.getUint16(22, Endian.little), 1); // mono
      expect(data.getUint32(24, Endian.little), 22050);
      expect(data.getUint16(34, Endian.little), 16); // bits per sample
      expect(data.getUint32(40, Endian.little), samples.length * 2);
      expect(data.getUint32(4, Endian.little), 36 + samples.length * 2);
    });

    test('clamps out-of-range samples instead of wrapping', () {
      final wav = float32ToWav(<double>[1.5, -1.5], 22050);
      final data = ByteData.sublistView(wav);
      expect(data.getInt16(44, Endian.little), 32767);
      expect(data.getInt16(46, Endian.little), -32767);
    });

    test('handles an empty buffer', () {
      final wav = float32ToWav(const <double>[], 22050);
      expect(wav.length, 44);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    });
  });
}
