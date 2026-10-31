import 'dart:convert';

/// Parsed `assets/models/murya.onnx.json` metadata.
///
/// Murya is distributed as a Piper/VITS ONNX graph plus a JSON side-car
/// describing the phoneme table, sample rate, inference scales and speaker map.
/// The parser is deliberately tolerant: a missing field falls back to the Piper
/// default so an updated model file keeps working without code changes.
///
/// The shipped config (`adab-tech/murya-piper-hausa-tts`) has:
/// * `phoneme_type: "text"` — characters map straight to ids, no espeak step,
/// * `pad "_" = 0`, `bos "^" = 1`, `eos "$" = 2`, space = 3,
/// * `num_speakers: 8` with `{"F2":0,"M3":1,"M2":2,"F4":3,"M4":4,"F1":5,"M1":6,"F3":7}`,
/// * 22,050 Hz output.
class MuryaConfig {
  const MuryaConfig({
    required this.sampleRate,
    required this.phonemeIdMap,
    required this.characters,
    required this.inputNames,
    required this.lengthScale,
    required this.noiseScale,
    required this.noiseW,
    required this.numSpeakers,
    required this.speakerIdMap,
    required this.defaultSpeakerId,
    required this.padId,
    required this.bosId,
    required this.eosId,
    required this.phonemeType,
    required this.languageCode,
    required this.modelName,
  });

  final int sampleRate;

  /// `{ "a": [12], "ɓ": [34], ... }` — character/phoneme to token-id rows.
  final Map<String, List<int>> phonemeIdMap;

  /// Character-level models may list their vocabulary here instead.
  final List<String> characters;

  /// Declared graph input names (empty -> auto-detect at runtime).
  final List<String> inputNames;

  final double lengthScale;
  final double noiseScale;
  final double noiseW;

  final int numSpeakers;

  /// `{ "M1": 6, "F1": 5, ... }` — voice name to speaker id.
  final Map<String, int> speakerIdMap;

  /// Speaker used when the caller does not pick one.
  final int? defaultSpeakerId;

  /// Piper control tokens.
  final int padId;
  final int bosId;
  final int eosId;

  /// `"text"` for this model (characters are the phonemes).
  final String phonemeType;

  final String languageCode;
  final String modelName;

  /// Voice name of [defaultSpeakerId], e.g. `M1` (used in the UI).
  String get defaultSpeakerName {
    final wanted = defaultSpeakerId;
    if (wanted == null) return 'default';
    for (final entry in speakerIdMap.entries) {
      if (entry.value == wanted) return entry.key;
    }
    return 'speaker-$wanted';
  }

  /// True when the graph expects a `sid` input.
  bool get isMultiSpeaker => numSpeakers > 1;

  /// Human readable list for the voice sheet, ordered by speaker id.
  List<MapEntry<String, int>> get speakers {
    final entries = speakerIdMap.entries.toList(growable: false);
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  static MuryaConfig defaults() => const MuryaConfig(
        sampleRate: 22050,
        phonemeIdMap: <String, List<int>>{},
        characters: <String>[],
        inputNames: <String>['input', 'input_lengths', 'scales'],
        lengthScale: 1.0,
        noiseScale: 0.667,
        noiseW: 0.8,
        numSpeakers: 1,
        speakerIdMap: <String, int>{},
        defaultSpeakerId: null,
        padId: 0,
        bosId: 1,
        eosId: 2,
        phonemeType: 'text',
        languageCode: 'ha',
        modelName: 'murya',
      );

  factory MuryaConfig.parse(String? jsonText) {
    final fallback = MuryaConfig.defaults();
    if (jsonText == null || jsonText.trim().isEmpty) return fallback;

    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map) return fallback;
      json = decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return fallback;
    }

    Map<String, dynamic>? asMap(Object? value) =>
        value is Map ? value.map((k, v) => MapEntry(k.toString(), v)) : null;

    int asInt(Object? value, int fallbackValue) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallbackValue;
      return fallbackValue;
    }

    double asDouble(Object? value, double fallbackValue) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallbackValue;
      return fallbackValue;
    }

    // ---- phoneme table ----------------------------------------------------
    final phonemeMap = <String, List<int>>{};
    final rawMap = json['phoneme_id_map'] ?? json['phonemeIdMap'];
    if (rawMap is Map) {
      rawMap.forEach((key, value) {
        if (value is List) {
          phonemeMap[key.toString()] = value
              .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
              .toList(growable: false);
        } else if (value is num) {
          phonemeMap[key.toString()] = <int>[value.toInt()];
        }
      });
    }

    final characters = <String>[];
    final rawChars = json['characters'];
    if (rawChars is List) {
      characters.addAll(rawChars.map((c) => c.toString()));
    } else if (rawChars is Map) {
      // VITS: { "char": id } maps.
      rawChars.forEach((key, _) => characters.add(key.toString()));
    }

    // ---- graph inputs -----------------------------------------------------
    final inputNames = <String>[];
    final rawInputs = json['input_names'] ?? json['inputNames'];
    if (rawInputs is List) {
      inputNames.addAll(rawInputs.map((e) => e.toString()));
    }

    // ---- speakers ---------------------------------------------------------
    final speakerMap = <String, int>{};
    final rawSpeakers = json['speaker_id_map'] ?? json['speakerIdMap'];
    if (rawSpeakers is Map) {
      rawSpeakers.forEach((key, value) {
        speakerMap[key.toString()] = asInt(value, 0);
      });
    }
    final numSpeakers =
        asInt(json['num_speakers'] ?? json['numSpeakers'], 1);

    int? speakerOf(Object? value) {
      if (value == null) return null;
      if (value is String) return speakerMap[value] ?? int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    final requestedSpeaker = speakerOf(json['speaker_id'] ?? json['speakerId']);
    final defaultSpeakerId = requestedSpeaker ??
        (speakerMap.isNotEmpty
            // M1 is the male Kano narration voice used by the app by default.
            ? (speakerMap['M1'] ?? speakerMap.values.first)
            : (numSpeakers > 1 ? 0 : null));

    // ---- control tokens ---------------------------------------------------
    int controlId(String token, int fallbackId) {
      final row = phonemeMap[token];
      return row != null && row.isNotEmpty ? row.first : fallbackId;
    }

    final inference = asMap(json['inference']);
    final audio = asMap(json['audio']);
    final language = asMap(json['language']);

    return MuryaConfig(
      sampleRate: asInt(
        audio?['sample_rate'] ?? json['sample_rate'] ?? json['sampleRate'],
        fallback.sampleRate,
      ),
      phonemeIdMap: phonemeMap,
      characters: characters,
      inputNames: inputNames,
      lengthScale: asDouble(
        inference?['length_scale'] ??
            json['length_scale'] ??
            json['lengthScale'],
        fallback.lengthScale,
      ),
      noiseScale: asDouble(
        inference?['noise_scale'] ??
            json['noise_scale'] ??
            json['noiseScale'],
        fallback.noiseScale,
      ),
      noiseW: asDouble(
        inference?['noise_w'] ?? json['noise_w'] ?? json['noiseW'],
        fallback.noiseW,
      ),
      numSpeakers: numSpeakers,
      speakerIdMap: speakerMap,
      defaultSpeakerId: defaultSpeakerId,
      padId: controlId('_', fallback.padId),
      bosId: controlId('^', fallback.bosId),
      eosId: controlId(r'$', fallback.eosId),
      phonemeType:
          (json['phoneme_type'] ?? json['phonemeType'] ?? 'text').toString(),
      languageCode:
          (language?['code'] ?? json['language'] ?? 'ha').toString(),
      modelName: (json['model_name'] ?? json['modelName'] ?? 'murya').toString(),
    );
  }
}
