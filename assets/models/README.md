# Murya Hausa voice model

Three files belong in this folder:

| File | Status | Purpose |
| --- | --- | --- |
| `murya.onnx.json` | **committed** | Piper config: `phoneme_id_map`, 22 050 Hz, inference scales, 8-speaker map. |
| `MODEL_ATTRIBUTION.txt` | **committed** | CC BY-NC-SA 4.0 credit for the weights. |
| `murya.onnx` | **~21.7 MB, must be added** | INT8 ONNX graph. Either commit it or let CI fetch it (see below). |

`pubspec.yaml` already registers this directory (`assets: - assets/models/`), so
once the graph is here `flutter pub get` bundles it and `HybridTtsService`
starts the offline Hausa voice automatically. If the file is absent the app
still runs and speaks through the device voice.

> **Licence:** the weights are CC BY-NC-SA 4.0 — non-commercial, attribution,
> share-alike. Commercial use needs a separate licence from the author. See
> `MODEL_ATTRIBUTION.txt`.

## Getting `murya.onnx`

### Option A — let CI fetch a prebuilt file

Set `MURYA_ONNX_URL` (and, if needed, `MURYA_ONNX_JSON_URL`) in Codemagic. The
`Prepare Murya voice model` step in `codemagic.yaml` downloads it if it is not
already committed, validates the ONNX magic byte and size, and fails clearly if
the download is truncated.

### Option B — quantise the upstream release yourself (recommended)

```bash
cd smartvillage_flutter

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
