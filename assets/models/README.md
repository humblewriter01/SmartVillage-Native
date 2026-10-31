# Murya Hausa voice model

Drop the two model files in this folder:

| File | Purpose |
| --- | --- |
| `murya.onnx` | The Piper/VITS-style ONNX graph that synthesises Hausa speech. |
| `murya.onnx.json` | The side-car config: `phoneme_id_map`, `audio.sample_rate`, `inference.*` scales, optional `num_speakers`/`speaker_id_map`. |

Once both files are here, `flutter pub get` picks the folder up through
`pubspec.yaml` (`assets: - assets/models/`) and `HybridTtsService` starts the
offline Hausa engine automatically.

Nothing else is required: if the files are missing, unreadable, or the model
fails to load, the app silently keeps using the Android device voice
(`flutter_tts`) for both languages, so a build without the model still works.

The model binaries are deliberately **git-ignored** (see `.gitignore`) because
of their size and licence terms. Keep this README in the folder so the
directory exists — Flutter refuses to build when a declared asset directory is
empty.

## Expected config fields

`MuryaConfig.parse` is tolerant; missing fields fall back to Piper defaults
(`22050 Hz`, `length_scale 1.0`, `noise_scale 0.667`, `noise_w 0.8`). It reads:

```json
{
  "audio": { "sample_rate": 22050 },
  "phoneme_id_map": { "a": [12], "ɓ": [41] },
  "characters": ["a", "b", "ɓ"],
  "input_names": ["input", "input_lengths", "scales"],
  "inference": {
    "noise_scale": 0.667,
    "length_scale": 1.0,
    "noise_w": 0.8
  },
  "num_speakers": 1,
  "speaker_id_map": { "default": 0 },
  "model": "murya"
}
```
