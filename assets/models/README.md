# Murya Hausa voice model

Three files belong in this folder:

| File | Status | Purpose |
| --- | --- | --- |
| `murya.onnx.json` | **committed** | Piper config: `phoneme_id_map`, 22 050 Hz, inference scales, 8-speaker map. |
| `MODEL_ATTRIBUTION.txt` | **committed** | CC BY-NC-SA 4.0 credit for the weights. |
| `murya.onnx` | **committed** (22,745,309 B) | INT8 QDQ ONNX graph (`onnx.quantize 0.1.0`, opset 15). |

`pubspec.yaml` registers this directory (`assets: - assets/models/`), so
`flutter pub get` bundles the graph and `HybridTtsService` starts the offline
Hausa voice automatically. If the file is ever removed the app still runs and
speaks through the device voice.

## Verify it before shipping

```bash
pip install -r tool/requirements-quantize.txt
python3 tool/verify_murya.py --wav /tmp/murya.wav
#   --threads 1   emulate a single-core phone
#   --speaker N   try another voice (0-7)
```

The script feeds five Hausa sentences through the app's own tokenizer and fails
if the audio is silent, clipped, or an implausible length. Current result:
`PASS`, 152–370 ms per sentence, RMS 0.06–0.08, peak < 0.38, no clipping, and
the eight speakers produce audibly different output.

> **Licence:** the weights are CC BY-NC-SA 4.0 — non-commercial, attribution,
> share-alike. Commercial use needs a separate licence from the author. See
> `MODEL_ATTRIBUTION.txt`.

## Getting `murya.onnx`

### Only if the graph has to be rebuilt — quantise the upstream release

```bash
# from the repository root

# 1. upstream FP32 weights (77.1 MB)
curl -L -o model.onnx      https://huggingface.co/adab-tech/murya-piper-hausa-tts/resolve/main/model.onnx
curl -L -o model.onnx.json https://huggingface.co/adab-tech/murya-piper-hausa-tts/resolve/main/model.onnx.json

# 2. quantise to INT8 (~21.7 MB) and smoke-test the result
python3 -m venv .venv && . .venv/bin/activate
pip install -r tool/requirements-quantize.txt
python tool/quantize_murya.py --model model.onnx --config model.onnx.json \
                              --mode qdq --out assets/models/murya.onnx

# 3. commit
git add assets/models/murya.onnx
```

The script prints RMS/peak/duration from a real Hausa phrase, so a silent or
clipped export is caught before it reaches a phone. If QDQ ever produces bad
audio, fall back to `--mode dynamic` (larger, safer) or `--mode fp16`.

## Model facts (verified from the upstream config)

| | |
| --- | --- |
| Architecture | Piper/VITS, ONNX, `phoneme_type: text` |
| Sample rate | 22 050 Hz, mono |
| Speakers | 8 — `F2`=0, `M3`=1, `M2`=2, `F4`=3, `M4`=4, `F1`=5, `M1`=6, `F3`=7 |
| Default voice | `M1` (id 6) — male, Standard Kano Hausa |
| Tokens | `^`=1 BOS, `_`=0 PAD, `$`=2 EOS, space=3, a…z=12…33, `ɓ`=34, `ɗ`=35, `ƙ`=36, `ƴ`=37, `p`=38, `q`=39, `v`=40, `x`=41 |
| Graph inputs | `input` (int64 `[1, n]`), `input_lengths` (int64 `[1]`), `scales` (float32 `[3]`), `sid` (int64 `[1]`) |
| Token layout | `BOS, id₁, PAD, id₂, PAD, … , idₙ, PAD, EOS` |

The Dart side of all of this lives in `lib/services/tts/murya_pcm.dart`
(tokeniser + WAV encoder) and is covered by `test/murya_tokenizer_test.dart`.
