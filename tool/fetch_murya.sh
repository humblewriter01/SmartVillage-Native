#!/usr/bin/env bash
# Fetch the upstream Murya (Piper/VITS) Hausa voice and quantise it to INT8.
#
#   ./tool/fetch_murya.sh              # download + quantise into assets/models/
#   ./tool/fetch_murya.sh --dynamic    # safer/larger quantisation mode
#   ./tool/fetch_murya.sh --keep       # keep the 77 MB upstream files afterwards
#
# Requires: curl, python3 (+ venv), ~500 MB free disk, an internet connection
# to huggingface.co. See assets/models/README.md for the licence terms.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

HF_BASE="https://huggingface.co/adab-tech/murya-piper-hausa-tts/resolve/main"
MODE="qdq"
KEEP=0
for arg in "$@"; do
  case "$arg" in
    --qdq|--dynamic|--fp16) MODE="${arg#--}" ;;
    --keep) KEEP=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

VENV="$REPO_ROOT/tool/.quantize-cache/venv"
PY="$VENV/bin/python"

command -v python3 >/dev/null || { echo "error: python3 not found" >&2; exit 1; }

if [ ! -x "$PY" ]; then
  echo "==> creating python venv in tool/.quantize-cache/venv"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --upgrade pip
  "$VENV/bin/pip" install --quiet -r tool/requirements-quantize.txt
fi

if [ ! -f model.onnx ] || [ ! -f model.onnx.json ]; then
  echo "==> downloading upstream weights (77.1 MB)"
  curl -fL --retry 3 --connect-timeout 30 -o model.onnx      "$HF_BASE/model.onnx"
  curl -fL --retry 3 --connect-timeout 30 -o model.onnx.json "$HF_BASE/model.onnx.json"
fi

# Guard against a captive-portal HTML page saved as "model.onnx".
MAGIC=$(head -c 1 model.onnx | od -An -tu1 | tr -d ' \n')
if [ "$MAGIC" != "8" ]; then
  echo "error: model.onnx is not an ONNX protobuf (first byte $MAGIC)." >&2
  echo "       A proxy or login page probably intercepted the download." >&2
  exit 1
fi

echo "==> quantising ($MODE)"
"$PY" tool/quantize_murya.py \
  --model model.onnx \
  --config model.onnx.json \
  --mode "$MODE" \
  --out assets/models/murya.onnx

# Keep the config authoritative: the shipped one is the upstream copy.
if ! cmp -s model.onnx.json assets/models/murya.onnx.json; then
  echo "==> upstream config differs from assets/models/murya.onnx.json"
  echo "    diff it before committing: the tokenizer depends on phoneme_id_map."
  diff -u assets/models/murya.onnx.json model.onnx.json || true
fi

if [ "$KEEP" -eq 0 ]; then
  rm -f model.onnx model.onnx.json
  echo "==> removed upstream scratch files (use --keep to retain them)"
fi

SIZE=$(wc -c < assets/models/murya.onnx | tr -d ' ')
echo
echo "Done: assets/models/murya.onnx ($((SIZE / 1024 / 1024)) MB)"
echo "Next:"
echo "  flutter pub get && flutter run      # About → voice status should say Murya ready"
echo "  git add assets/models/murya.onnx    # only if you want CI to bundle it"
