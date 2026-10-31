import 'dart:convert';

/// Parsed `assets/models/murya.onnx.json` metadata.
///
/// Murya is distributed as a Piper/VITS-style ONNX graph plus a JSON side-car
/// that describes the phoneme table, sample rate and inference scales. The
/// parser is deliberately tolerant: if a field is missing we fall back to the
/// Piper defaults so an updated model file keeps working without code changes.
class MuryaConfig {
  MuryaConfig({
    required this.sampleRate,
    required this.phonemeIdMap,
    required this.characters,
    required this.inputNames,
    required this.lengthScale,
    required this.noiseScale,
    required this.noiseW,
    required this.numSpeakers,
    required this.defaultSpeakerId,
    required this.modelName,
  });

  final int sampleRate;

  /// `{ "a": [12], "ɓ": [41], ... }` — phoneme to token-id rows.
  final Map<String, List<int>> phonemeIdMap;

  /// Character-level models list their vocabulary here instead.
  final List<String> characters;

  /// Declared graph input names (empty -> auto-detect at runtime).
  final List<String> inputNames;

  final double lengthScale;
  final double noiseScale;
  final double noiseW;
  final int numSpeakers;
  final int? defaultSpeakerId;
  final String modelName;

  static const int padId = 0;

  static MuryaConfig defaults() => MuryaConfig(
        sampleRate: 22050,
        phonemeIdMap: const <String, List<int>>{},
        characters: const <String>[],
        inputNames: const <String>['input', 'input_lengths', 'scales'],
        lengthScale: 1.0,
        noiseScale: 0.667,
        noiseW: 0.8,
        numSpeakers: 1,
        defaultSpeakerId: null,
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

    final phonemeMap = <String, List<int>>{};
    final rawMap = json['phoneme_id_map'] ?? json['phonemeIdMap'];
    if (rawMap is Map) {
      rawMap.forEach((key, value) {
        if (value is List) {
          phonemeMap[key.toString()] = value
              .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
              .toList(growable: false);
        } else if (value is int) {
          phonemeMap[key.toString()] = <int>[value];
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

    final inputNames = <String>[];
    final rawInputs = json['input_names'] ?? json['inputNames'];
    if (rawInputs is List) {
      inputNames.addAll(rawInputs.map((e) => e.toString()));
    }

    double asDouble(dynamic value, double fallbackValue) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallbackValue;
      return fallbackValue;
    }

    int asInt(dynamic value, int fallbackValue) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallbackValue;
      return fallbackValue;
    }

    final inference = json['inference'] is Map ? json['inference'] as Map : null;

    return MuryaConfig(
      sampleRate: asInt(json['audio'] is Map ? json['audio']['sample_rate'] : json['sample_rate'] ?? json['sampleRate'], fallback.sampleRate),
      phonemeIdMap: phonemeMap,
      characters: characters,
      inputNames: inputNames,
      lengthScale: asDouble(
        inference?['length_scale'] ?? json['length_scale'] ?? json['lengthScale'],
        fallback.lengthScale,
      ),
      noiseScale: asDouble(
        inference?['noise_scale'] ?? json['noise_scale'] ?? json['noiseScale'],
        fallback.noiseScale,
      ),
      noiseW: asDouble(
        inference?['noise_w'] ?? json['noise_w'] ?? json['noiseW'],
        fallback.noiseW,
      ),
      numSpeakers: asInt(json['num_speakers'] ?? json['numSpeakers'], 1),
      defaultSpeakerId: json['speaker_id'] == null && json['speakerId'] == null
          ? null
          : asInt(json['speaker_id'] ?? json['speakerId'], 0),
      modelName: (json['model_name'] ?? json['modelName'] ?? 'murya').toString(),
    );
  }
}
