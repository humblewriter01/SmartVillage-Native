#!/usr/bin/env python3
"""Quantise the Murya (Piper/VITS) Hausa voice for low-end Android devices.

Upstream ships a 77.1 MB FP32 ONNX graph
(https://huggingface.co/adab-tech/murya-piper-hausa-tts). On a 2 GB RAM phone
that is a ~1 s load and too much resident memory, so this script produces the
~21.7 MB INT8 graph that ships in `assets/models/`.

Usage
-----
    pip install -r tool/requirements-quantize.txt

    # 1. download the upstream files first (see assets/models/README.md)
    #    model.onnx  model.onnx.json
    python tool/quantize_murya.py \
        --model  model.onnx \
        --config model.onnx.json \
        --mode   qdq \
        --out    assets/models/murya.onnx

    # 2. sanity-check the result, then listen to it in the app
    python tool/quantize_murya.py --verify assets/models/murya.onnx \
        --config assets/models/murya.onnx.json

Modes
-----
  qdq      Static INT8 with calibration (default). Quantises Convolutions as
           well as MatMuls, which is what actually gets a VITS graph down to
           ~1/4 size. Calibration uses synthetic token sequences drawn from the
           app's own Hausa lexicon — no audio corpus needed.
  dynamic  Weight-only dynamic INT8. Safest for audio quality but only covers
           MatMul/Gemm/LSTM, so a Conv-heavy VITS shrinks by much less than 4x.
  fp16     Half precision (~38.5 MB). Near-transparent quality, moderate win.

The script always finishes by running the quantised graph on a real phrase and
reporting RMS/peak/duration, so a broken (silent or clipped) export is caught
before it reaches a phone.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import logging
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants that mirror lib/services/tts/murya_pcm.dart
# ---------------------------------------------------------------------------

PAD = "_"
BOS = "^"
EOS = "$"

#: Phrases used both for calibration and for the final smoke test. Kept short
#: and phonetically broad on purpose (hooked letters, digraphs, punctuation).
CALIBRATION_PHRASES = [
    "Sannu da zuwa SmartVillage.",
    "Fesa maganin a gonar albasa da sassafe.",
    "Masara tana da cutar tsatsa a ganye.",
    "Shayar da gonar tumatir kowace rana.",
    "Awaki suna da gudawa, a ba su magani.",
    "Ruwan rijiya ya yi datti, a tace shi.",
    "Lokacin shuka shinkafa ya yi a fadama.",
    "Ƙasar tana da tsami, a zuba tokar itace.",
    "Ciwon zazzabi da sanyi, je asibiti.",
    "Girbi dawa idan hatsi ya bushe sosai.",
    "Dabbobi suna buƙatar allurar rigakafi.",
    "Yanayin rana zai yi zafi sosai yau.",
    "Tsuntsaye suna cin hatsi a gona.",
    "A duba lafiyar ƴaƴa kowace wata.",
]

SMOKE_TEST_PHRASE = "Sannu, barka da zuwa SmartVillage. Yau za mu duba gonar ka."


@contextlib.contextmanager
def quiet_ort():
    """Silence ORT's generic "please pre-process" advice; keep real errors."""
    root = logging.getLogger()
    previous = root.level
    root.setLevel(logging.ERROR)
    try:
        yield
    finally:
        root.setLevel(previous)


# ---------------------------------------------------------------------------
# Tokenisation (must match the Dart implementation exactly)
# ---------------------------------------------------------------------------


def build_token_ids(text: str, config: dict) -> list[int]:
    """Characters -> phoneme ids with Piper's BOS / pad / EOS layout."""
    phoneme_map: dict[str, list[int]] = config.get("phoneme_id_map") or {}
    if not phoneme_map:
        raise SystemExit("config has no phoneme_id_map; cannot tokenise")

    def row(key: str) -> list[int]:
        found = phoneme_map.get(key)
        return list(found) if found else []

    pad = row(PAD) or [0]
    ids: list[int] = list(row(BOS))

    for char in text.lower():
        if char == "’" or char == "‘":
            char = "'"
        found = phoneme_map.get(char)
        if not found:
            # Unknown glyphs are dropped rather than substituted, otherwise the
            # model pronounces filler.
            continue
        ids.extend(found)
        ids.extend(pad)

    ids.extend(row(EOS))
    return ids


def resolve_speaker(config: dict, requested: int | None) -> int | None:
    if requested is not None:
        return requested
    speaker_map: dict[str, int] = config.get("speaker_id_map") or {}
    if not speaker_map:
        return 0 if int(config.get("num_speakers", 1)) > 1 else None
    # M1 / Malam Garba is the default narration voice in the app.
    for name in ("M1", "M2", "M3", "M4"):
        if name in speaker_map:
            return int(speaker_map[name])
    return int(next(iter(speaker_map.values())))


# ---------------------------------------------------------------------------
# Graph input plumbing
# ---------------------------------------------------------------------------

INPUT_ALIASES = {
    "tokens": ("input", "input_ids", "tokens", "x", "text"),
    "lengths": ("input_lengths", "lengths", "x_lengths"),
    "scales": ("scales",),
    "speaker": ("sid", "speaker_id", "speaker"),
}


def _alias_group(name: str) -> str:
    for group, aliases in INPUT_ALIASES.items():
        if name in aliases:
            return group
    return "tokens"


def make_feed(
    input_names: list[str],
    ids: list[int],
    scales: tuple[float, float, float],
    speaker: int | None,
) -> dict:
    import numpy as np

    feed: dict = {}
    for name in input_names:
        group = _alias_group(name)
        if group == "tokens":
            feed[name] = np.array([ids], dtype=np.int64)
        elif group == "lengths":
            feed[name] = np.array([len(ids)], dtype=np.int64)
        elif group == "scales":
            feed[name] = np.array(scales, dtype=np.float32)
        else:
            feed[name] = np.array([speaker or 0], dtype=np.int64)
    return feed


def scales_from(config: dict, length_scale: float | None) -> tuple[float, float, float]:
    inference = config.get("inference") or {}
    return (
        float(inference.get("noise_scale", 0.667)),
        float(length_scale if length_scale is not None else inference.get("length_scale", 1.0)),
        float(inference.get("noise_w", 0.8)),
    )


class PhraseCalibrationReader:
    """Feeds synthetic Hausa token sequences to the static quantiser."""

    def __init__(self, input_names: list[str], config: dict, scales) -> None:
        self._inputs = input_names
        self._config = config
        self._scales = scales
        self._speaker = resolve_speaker(config, None)
        self._phrases = list(CALIBRATION_PHRASES)
        for phrase in CALIBRATION_PHRASES:
            self._phrases.append(phrase * 2)  # longer utterance coverage
        self._index = 0

    def get_next(self) -> dict | None:
        if self._index >= len(self._phrases):
            return None
        ids = build_token_ids(self._phrases[self._index], self._config)
        self._index += 1
        return make_feed(self._inputs, ids, self._scales, self._speaker)

    def rewind(self) -> None:
        self._index = 0


# ---------------------------------------------------------------------------
# Quantisation
# ---------------------------------------------------------------------------


def quantise_qdq(src: Path, dst: Path, config: dict, scales, input_names: list[str]) -> None:
    from onnxruntime.quantization import (
        CalibrationMethod,
        QuantFormat,
        QuantType,
        quantize_static,
    )

    reader = PhraseCalibrationReader(input_names, config, scales)
    with quiet_ort():
        quantize_static(
            model_input=str(src),
            model_output=str(dst),
            calibration_data_reader=reader,
            quant_format=QuantFormat.QDQ,
            per_channel=True,
            reduce_range=False,
            activation_type=QuantType.QUInt8,
            weight_type=QuantType.QInt8,
            calibrate_method=CalibrationMethod.MinMax,
            extra_options={
                # Keep softmax / layer-norm style ops in float: quantising them
                # is what turns a VITS voice into a robot with a cold.
                "OpTypesToExcludeOutputQuantization": ["Softmax", "Sigmoid", "Tanh"],
                "ActivationSymmetric": False,
                "WeightSymmetric": True,
            },
        )


def quantise_dynamic(src: Path, dst: Path) -> None:
    from onnxruntime.quantization import QuantType, quantize_dynamic

    with quiet_ort():
        quantize_dynamic(
            model_input=str(src),
            model_output=str(dst),
            weight_type=QuantType.QUInt8,
            per_channel=True,
            reduce_range=False,
        )


def convert_fp16(src: Path, dst: Path) -> None:
    try:
        import onnx
        from onnxconverter_common import float16
    except ImportError:
        raise SystemExit(
            "fp16 mode needs onnxconverter-common:\n"
            "    pip install onnxconverter-common"
        )

    model = onnx.load(str(src))
    with quiet_ort():
        converted = float16.convert_float_to_float16(
            model,
            keep_io_types=True,
            # These ops misbehave in fp16 on ARM and are cheap to keep in fp32.
            op_block_list=["Resize", "NonMaxSuppression", "MultiHeadAttention", "Range"],
        )
    onnx.checker.check_model(converted)
    onnx.save(converted, str(dst))


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------


def verify(model_path: Path, config_path: Path, speaker: int | None, length_scale: float | None) -> bool:
    import numpy as np
    import onnxruntime as ort

    config = json.loads(Path(config_path).read_text(encoding="utf-8"))
    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    input_names = [i.name for i in session.get_inputs()]
    ids = build_token_ids(SMOKE_TEST_PHRASE, config)
    feed = make_feed(
        input_names,
        ids,
        scales_from(config, length_scale),
        resolve_speaker(config, speaker),
    )

    outputs = session.run(None, feed)
    audio = np.asarray(outputs[0], dtype=np.float32).reshape(-1)
    sample_rate = int(config.get("audio", {}).get("sample_rate", 22050))

    rms = float(np.sqrt(np.mean(np.square(audio)))) if audio.size else 0.0
    peak = float(np.max(np.abs(audio))) if audio.size else 0.0
    seconds = audio.size / sample_rate if sample_rate else 0.0
    clipped = float(np.mean(np.abs(audio) >= 0.999)) if audio.size else 0.0

    print("--- verification -------------------------------------------------")
    print(f"inputs        : {input_names}")
    print(f"tokens        : {len(ids)}")
    print(f"samples       : {audio.size}  ({seconds:.2f} s @ {sample_rate} Hz)")
    print(f"rms / peak    : {rms:.4f} / {peak:.4f}")
    print(f"clipped share : {clipped * 100:.2f} %")

    ok = True
    if audio.size == 0:
        print("FAIL: model returned no audio")
        ok = False
    if rms < 1e-4:
        print("FAIL: output is silent — the graph did not run correctly")
        ok = False
    if peak > 1.0:
        print("FAIL: output exceeds [-1, 1]; WAV encoding would clip")
        ok = False
    if seconds < 0.4:
        print("WARN: under 0.4 s for a 13-word sentence — check length_scale")
    if clipped > 0.01:
        print("WARN: more than 1 % of samples are clipped")
    if ok:
        print("OK: quantised graph produces audio of a plausible shape/level")
        print("    Listen in the app (About → voice status) before shipping.")
    return ok


# ---------------------------------------------------------------------------


def human(size: int) -> str:
    return f"{size / 1024 / 1024:.1f} MB"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", type=Path, default=Path("model.onnx"), help="upstream FP32 ONNX graph")
    parser.add_argument("--config", type=Path, default=Path("model.onnx.json"), help="upstream model config")
    parser.add_argument("--out", type=Path, default=Path("assets/models/murya.onnx"), help="output path")
    parser.add_argument("--mode", choices=("qdq", "dynamic", "fp16"), default="qdq")
    parser.add_argument("--speaker", type=int, default=None, help="speaker id override (default M1)")
    parser.add_argument("--length-scale", type=float, default=None, help="overrides inference.length_scale")
    parser.add_argument("--verify", type=Path, default=None, metavar="MODEL",
                        help="only run the smoke test on an existing model")
    parser.add_argument("--no-verify", action="store_true", help="skip the smoke test after quantising")
    args = parser.parse_args(argv)

    if args.verify is not None:
        try:
            return 0 if verify(
                args.verify, args.config, args.speaker, args.length_scale
            ) else 1
        except Exception as error:  # noqa: BLE001
            print(f"verification failed: {error}", file=sys.stderr)
            return 1

    if not args.model.exists():
        print(f"error: {args.model} not found.\n"
              "Download model.onnx + model.onnx.json from\n"
              "  https://huggingface.co/adab-tech/murya-piper-hausa-tts/tree/main\n"
              "then re-run this script.", file=sys.stderr)
        return 2
    if not args.config.exists():
        print(f"error: {args.config} not found (needed for the phoneme map).", file=sys.stderr)
        return 2

    config = json.loads(args.config.read_text(encoding="utf-8"))
    scales = scales_from(config, args.length_scale)
    args.out.parent.mkdir(parents=True, exist_ok=True)

    import onnxruntime as ort

    probe = ort.InferenceSession(str(args.model), providers=["CPUExecutionProvider"])
    input_names = [i.name for i in probe.get_inputs()]
    print(f"source model  : {args.model}  ({human(args.model.stat().st_size)})")
    print(f"graph inputs  : {input_names}")
    print(f"mode          : {args.mode}")

    try:
        if args.mode == "qdq":
            quantise_qdq(args.model, args.out, config, scales, input_names)
        elif args.mode == "dynamic":
            quantise_dynamic(args.model, args.out)
        else:
            convert_fp16(args.model, args.out)
    except Exception as error:  # noqa: BLE001 - report, do not traceback at users
        print(f"\nconversion failed ({args.mode}): {error}", file=sys.stderr)
        if args.mode == "fp16":
            print(
                "fp16 conversion cannot rewrite graphs that contain explicit "
                "Cast(to=float) nodes — a known limitation of "
                "onnxconverter-common. Use --mode qdq or --mode dynamic.",
                file=sys.stderr,
            )
        return 1

    src_size = args.model.stat().st_size
    dst_size = args.out.stat().st_size
    print(f"output model  : {args.out}  ({human(dst_size)}, "
          f"{src_size / max(dst_size, 1):.2f}x smaller)")

    if dst_size > 30 * 1024 * 1024:
        print("note: still above 30 MB — 'dynamic' only covers MatMul/Gemm. "
              "Use --mode qdq for the ~21.7 MB INT8 target.")

    if args.no_verify:
        return 0
    try:
        ok = verify(args.out, args.config, args.speaker, args.length_scale)
    except Exception as error:  # noqa: BLE001
        print(f"\nverification failed: {error}", file=sys.stderr)
        print("The quantised graph is not loadable/runnable. Fall back to "
              "--mode dynamic.", file=sys.stderr)
        return 1
    if not ok:
        print("\nQuantisation produced an unusable graph. Try:\n"
              "  * --mode dynamic   (safer, larger)\n"
              "  * --mode fp16      (~38 MB, near-lossless)")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
