#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="comfyui"
VENV_PY="$REPO_DIR/.venv/bin/python"

if [ ! -d "$REPO_DIR" ]; then
  echo "Répertoire $REPO_DIR introuvable. Lancez ./install.sh d'abord."
  exit 1
fi

if [ -x "$VENV_PY" ]; then
  exec "$VENV_PY" "$REPO_DIR/main.py" "$@"
else
  echo "Virtualenv introuvable dans $REPO_DIR/.venv. Exécutez ./install.sh pour le créer."
  exit 1
fi
