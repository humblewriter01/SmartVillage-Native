#!/usr/bin/env python3
"""Verify that the committed Murya graph really synthesises Hausa speech.

Runs the same pipeline the app uses (`TextPreprocessor` -> character ids in
Piper's BOS/PAD/EOS layout -> ONNX Runtime) so a broken, truncated or
mis-exported `assets/models/murya.onnx` is caught on a laptop instead of on a
farmer's phone.

    pip install -r tool/requirements-quantize.txt
    python3 tool/verify_murya.py                    # full check
    python3 tool/verify_murya.py --threads 1        # pessimistic phone timings
    python3 tool/verify_murya.py --wav /tmp/out.wav # listen to it yourself

Exit code 0 = the model is usable, 1 = it is not, 2 = prerequisites missing.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MODEL = REPO_ROOT / "assets" / "models" / "murya.onnx"
DEFAULT_CONFIG = REPO_ROOT / "assets" / "models" / "murya.onnx.json"

#: Sentences representative of what SmartVillage actually speaks. Order matters
#: only for readability in the report.
PHRASES = [
    ("greeting", "Sannu da zuwa SmartVillage."),
    ("crop advice", "Fesa maganin a gonar albasa da sassafe."),
    ("disease", "Masara tana da cutar tsatsa a ganye, a fesa mancozeb."),
    ("health triage", "Idan cizon maciji ya same ka, je asibiti da gaggawa."),
    ("water", "Ruwan rijiya ya yi datti, a tace shi kafin a sha."),
]

#: Sanity bounds for 22,050 Hz Hausa speech.
MIN_SECONDS_PER_TOKEN = 0.008   # below this the model is outputting noise
MAX_SECONDS_PER_TOKEN = 0.120   # above this something is stuck in a loop
MIN_RMS = 0.005
MAX_PEAK = 0.999


def build_ids(text: str, config: dict) -> list[int]:
    """Mirror of lib/services/tts/murya_pcm.dart::buildTokenIds."""
    id_map = config.get("phoneme_id_map") or {}
    if not id_map:
        raise SystemExit("config has no phoneme_id_map")

    def row(key: str) -> list[int]:
        found = id_map.get(key)
        return list(found) if found else []

    pad = row("_") or [0]
    ids = list(row("^"))
    voiced = 0
    for char in text.lower():
        if char in ("\u2019", "\u2018", "\u02bc"):
            char = "'"
        found = id_map.get(char)
        if not found:
            continue
        ids.extend(found)
        ids.extend(pad)
        voiced += 1
    if voiced == 0:
        return []
    ids.extend(row("$"))
    return ids


def default_speaker(config: dict) -> int:
    """Mirror of MuryaConfig: prefer M1, else the first mapped speaker."""
    speakers = config.get("speaker_id_map") or {}
    if "M1" in speakers:
        return int(speakers["M1"])
    if speakers:
        return int(next(iter(speakers.values())))
    return 0


def wav_bytes(audio, sample_rate: int) -> bytes:
    import struct

    clipped = [max(-1.0, min(1.0, float(s))) for s in audio]
    pcm = struct.pack("<%dh" % len(clipped), *(int(s * 32767) for s in clipped))
    header = b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVEfmt "
    header += struct.pack("<IHHIIHH", 16, 1, 1, sample_rate, sample_rate * 2, 2, 16)
    header += b"data" + struct.pack("<I", len(pcm))
    return header + pcm


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--threads", type=int, default=0,
                        help="intra-op threads (0 = ORT default, 1 = weak phone)")
    parser.add_argument("--speaker", type=int, default=None)
    parser.add_argument("--wav", type=Path, default=None,
                        help="write the last phrase to a WAV file")
    args = parser.parse_args(argv)

    try:
        import numpy as np
        import onnxruntime as ort
    except ImportError as error:
        print(f"missing dependency: {error}\n"
              "    pip install -r tool/requirements-quantize.txt", file=sys.stderr)
        return 2

    for path in (args.model, args.config):
        if not path.exists():
            print(f"error: {path} not found", file=sys.stderr)
            return 2

    config = json.loads(args.config.read_text(encoding="utf-8"))
    sample_rate = int(config.get("audio", {}).get("sample_rate", 22050))
    speaker = args.speaker if args.speaker is not None else default_speaker(config)
    size_mb = args.model.stat().st_size / 1024 / 1024

    options = ort.SessionOptions()
    if args.threads:
        options.intra_op_num_threads = args.threads
        options.inter_op_num_threads = 1
    options.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL

    print("=== Murya model verification ===================================")
    print(f"graph         : {args.model.relative_to(REPO_ROOT)} ({size_mb:.1f} MB)")
    print(f"config        : {sample_rate} Hz, {config.get('num_speakers', 1)} speakers, "
          f"phoneme_type={config.get('phoneme_type', '?')}")

    load_start = time.time()
    session = ort.InferenceSession(str(args.model), options,
                                   providers=["CPUExecutionProvider"])
    load_ms = (time.time() - load_start) * 1000
    inputs = [i.name for i in session.get_inputs()]
    print(f"loaded in     : {load_ms:.0f} ms")
    print(f"graph inputs  : {inputs}")

    failures: list[str] = []

    # ---- structural checks ------------------------------------------------
    for required in ("input", "input_lengths", "scales"):
        if required not in inputs:
            failures.append(f"graph has no '{required}' input (found {inputs})")
    if "sid" not in inputs and int(config.get("num_speakers", 1)) > 1:
        failures.append("multi-speaker config but the graph has no 'sid' input")

    # ---- run every phrase -------------------------------------------------
    print(f"\nspeaker       : {speaker}\n")
    print(f"{'phrase':<14} {'tokens':>6} {'samples':>8} {'seconds':>8} "
          f"{'rms':>7} {'peak':>6} {'infer':>8}")
    print("-" * 66)

    total_audio = 0.0
    total_infer = 0.0
    last_audio = None

    for label, text in PHRASES:
        ids = build_ids(text, config)
        if not ids:
            failures.append(f"{label}: tokenizer produced no ids for \"{text}\"")
            continue

        feed = {
            "input": np.array([ids], dtype=np.int64),
            "input_lengths": np.array([len(ids)], dtype=np.int64),
            "scales": np.array([
                float(config.get("inference", {}).get("noise_scale", 0.667)),
                float(config.get("inference", {}).get("length_scale", 1.0)),
                float(config.get("inference", {}).get("noise_w", 0.8)),
            ], dtype=np.float32),
        }
        if "sid" in inputs:
            feed["sid"] = np.array([speaker], dtype=np.int64)

        started = time.time()
        audio = np.asarray(session.run(None, feed)[0], dtype=np.float32).reshape(-1)
        infer_ms = (time.time() - started) * 1000

        seconds = audio.size / sample_rate
        rms = float(np.sqrt(np.mean(audio ** 2))) if audio.size else 0.0
        peak = float(np.max(np.abs(audio))) if audio.size else 0.0
        print(f"{label:<14} {len(ids):>6} {audio.size:>8} {seconds:>8.2f} "
              f"{rms:>7.4f} {peak:>6.3f} {infer_ms:>6.0f}ms")

        total_audio += seconds
        total_infer += infer_ms
        last_audio = audio

        if audio.size == 0:
            failures.append(f"{label}: empty audio")
            continue
        if rms < MIN_RMS:
            failures.append(f"{label}: silent output (rms {rms:.4f})")
        if peak > MAX_PEAK:
            failures.append(f"{label}: clipping (peak {peak:.3f})")
        per_token = seconds / len(ids)
        if not (MIN_SECONDS_PER_TOKEN <= per_token <= MAX_SECONDS_PER_TOKEN):
            failures.append(
                f"{label}: {seconds:.2f}s for {len(ids)} tokens is implausible "
                f"({per_token * 1000:.1f} ms/token)")

    # ---- speaker variation -------------------------------------------------
    if int(config.get("num_speakers", 1)) > 1 and "sid" in inputs:
        text = "Sannu da zuwa."
        renders = {}
        for sid in (default_speaker(config), 0, 7):
            ids = build_ids(text, config)
            feed = {
                "input": np.array([ids], dtype=np.int64),
                "input_lengths": np.array([len(ids)], dtype=np.int64),
                "scales": np.array([0.667, 1.0, 0.8], dtype=np.float32),
                "sid": np.array([sid], dtype=np.int64),
            }
            renders[sid] = np.asarray(session.run(None, feed)[0],
                                      dtype=np.float32).reshape(-1)
        keys = list(renders)
        same = all(
            renders[keys[0]].size == renders[k].size
            and np.allclose(renders[keys[0]][:1000], renders[k][:1000], atol=1e-3)
            for k in keys[1:]
        )
        print(f"\nmulti-speaker : {'FAIL - all speakers sound identical' if same else 'OK - voices differ'}")
        if same:
            failures.append("sid input has no effect on the output")

    print("-" * 66)
    print(f"audio         : {total_audio:.2f} s total, "
          f"{total_infer / max(len(PHRASES), 1):.0f} ms mean inference")
    print(f"generation budget: 2000 ms (app falls back to the device voice past this)")

    if last_audio is not None and args.wav:
        args.wav.parent.mkdir(parents=True, exist_ok=True)
        args.wav.write_bytes(wav_bytes(last_audio, sample_rate))
        print(f"wrote         : {args.wav}")

    print("=" * 66)
    if failures:
        print("FAILED:")
        for failure in failures:
            print(f"  * {failure}")
        return 1
    print("PASS - the committed graph speaks Hausa with the app's tokenizer.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
