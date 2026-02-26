#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="comfyui"
REPO_URL="https://github.com/comfyanonymous/ComfyUI.git"
VENV_DIR="$REPO_DIR/.venv"

echo "==> Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. You should install it from https://brew.sh/ then re-run this script."
  exit 1
fi

echo "==> Check / installing of python3.13"
if ! command -v python3.13 >/dev/null 2>&1; then
  echo "python3.13 not found. Install with Homebrew..."
  brew update
  brew install python@3.13
fi

echo "==> Clone / update of ComfyUI repo in ./$REPO_DIR"
if [ -d "$REPO_DIR/.git" ]; then
  echo "The repo all ready exist. Get the last modifications..."
  git -C "$REPO_DIR" pull --rebase
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Installing of ComfyUI-Manager in $REPO_DIR/custom_nodes"
CUSTOM_NODES_DIR="$REPO_DIR/custom_nodes"
MANAGER_DIR="$CUSTOM_NODES_DIR/comfyui-manager"
mkdir -p "$CUSTOM_NODES_DIR"
if [ -d "$MANAGER_DIR/.git" ]; then
  echo "ComfyUI-Manager all ready exist, update..."
  git -C "$MANAGER_DIR" pull --rebase
else
  git clone https://github.com/ltdrdata/ComfyUI-Manager "$MANAGER_DIR"
fi

echo "==> Creating / reusing a virtualenv in $VENV_DIR"
if [ -d "$VENV_DIR" ]; then
  echo "Existing virtualenv found, reusing it."
else
  python3.13 -m venv "$VENV_DIR"
fi

VENV_PY="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

echo "==> Updating pip in the virtualenv"
"$VENV_PY" -m pip install --upgrade pip setuptools wheel

echo "==> Installing torch/nightly (CPU) in the virtualenv"
"$VENV_PY" -m pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/cpu

echo "==> Installing ComfyUI dependencies in the virtualenv"
"$VENV_PY" -m pip install -r "$REPO_DIR/requirements.txt"

echo "==> Installation complete. To launch: ./launch.sh"
