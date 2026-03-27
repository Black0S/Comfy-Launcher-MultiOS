#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# OS SELECTION
# ─────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PyTorch Updater — Select your OS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1) Fedora / RHEL / CentOS   (CUDA)"
echo "  2) Arch Linux               (CUDA)"
echo "  3) Ubuntu / Debian          (CUDA)"
echo "  4) macOS                    (CPU nightly)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -rp "Your choice [1-4]: " OS_CHOICE

case "$OS_CHOICE" in
  1) OS_TYPE="fedora" ;;
  2) OS_TYPE="arch"   ;;
  3) OS_TYPE="ubuntu" ;;
  4) OS_TYPE="macos"  ;;
  *)
    echo "❌ Invalid choice. Exiting."
    exit 1
    ;;
esac
echo "✅ Selected: $OS_TYPE"
echo ""

# ─────────────────────────────────────────────────────────────
# PRE-CHECKS
# ─────────────────────────────────────────────────────────────
if [ ! -d "comfyui" ]; then
  echo "❌ Directory 'comfyui' not found. Run ./install.sh first."
  exit 1
fi

if [ ! -d "comfyui/.venv" ]; then
  echo "❌ Virtualenv 'comfyui/.venv' not found. Run ./install.sh first."
  exit 1
fi

VENV_PY="comfyui/.venv/bin/python"

echo "==> Updating pip..."
"$VENV_PY" -m pip install --upgrade pip

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─────────────────────────────────────────────────────────────
# PYTORCH INSTALLATION
# ─────────────────────────────────────────────────────────────
if [ "$OS_TYPE" = "macos" ]; then
  echo "🔄 Updating PyTorch (nightly, CPU — macOS)..."
  "$VENV_PY" -m pip install --pre torch torchvision \
    --index-url https://download.pytorch.org/whl/nightly/cpu
else
  echo "🔄 Updating PyTorch (stable, CUDA 13.0 — Linux)..."
  "$VENV_PY" -m pip install torch torchvision torchaudio \
    --extra-index-url https://download.pytorch.org/whl/cu130
fi

echo ""
echo "✅ Update complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Installed versions:"

if [ "$OS_TYPE" = "macos" ]; then
  "$VENV_PY" -c "
import torch
print(f'PyTorch:        {torch.__version__}')
print(f'MPS available:  {torch.backends.mps.is_available()}')
if torch.backends.mps.is_available():
    print('GPU:            Apple Silicon (MPS)')
else:
    print('GPU:            N/A (CPU only)')
"
else
  "$VENV_PY" -c "
import torch
print(f'PyTorch:        {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'CUDA version:   {torch.version.cuda}')
    print(f'GPU:            {torch.cuda.get_device_name(0)}')
    print(f'VRAM:           {torch.cuda.get_device_properties(0).total_memory // 1024**2} MB')
"
fi
