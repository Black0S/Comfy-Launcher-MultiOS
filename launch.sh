#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="comfyui"
VENV_PY="$REPO_DIR/.venv/bin/python"

if [ ! -d "$REPO_DIR" ]; then
  echo "❌ Directory $REPO_DIR not found. Run ./install.sh first."
  exit 1
fi

if [ -x "$VENV_PY" ]; then
  echo "🚀 Starting ComfyUI..."
  echo "   Open your browser at: http://127.0.0.1:8188"
  exec "$VENV_PY" "$REPO_DIR/main.py" \
    $( [ "$(uname)" != "Darwin" ] && command -v nvidia-smi >/dev/null 2>&1 && echo "--cuda-device 0" ) \
    "$@"
else
  echo "❌ Virtualenv not found in $REPO_DIR/.venv. Run ./install.sh to create it."
  exit 1
fi
