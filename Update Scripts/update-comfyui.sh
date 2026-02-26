#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="../comfyui"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Repository $REPO_DIR not found. Run ../install.sh first."
  exit 1
fi

echo "==> Fetching remote branches"
git -C "$REPO_DIR" fetch --all --prune

BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
echo "==> Current branch: $BRANCH"

echo "==> Pull --rebase on branch $BRANCH"
git -C "$REPO_DIR" pull --rebase

if [ -f "$REPO_DIR/.gitmodules" ]; then
  echo "==> Updating submodules"
  git -C "$REPO_DIR" submodule update --init --recursive
fi

VENV_PY="$REPO_DIR/.venv/bin/python"
if [ -x "$VENV_PY" ]; then
  echo "==> Virtualenv found, updating dependencies in the venv"
  "$VENV_PY" -m pip install --upgrade pip setuptools wheel
  "$VENV_PY" -m pip install -r "$REPO_DIR/requirements.txt"
fi

echo "==> Update complete."
