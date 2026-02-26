#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="../comfyui"

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Dépôt $REPO_DIR introuvable. Exécutez ../install.sh d'abord."
  exit 1
fi

echo "==> Récupération des branches distantes"
git -C "$REPO_DIR" fetch --all --prune

BRANCH="$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)"
echo "==> Branche courante : $BRANCH"

echo "==> Pull --rebase sur la branche $BRANCH"
git -C "$REPO_DIR" pull --rebase

if [ -f "$REPO_DIR/.gitmodules" ]; then
  echo "==> Mise à jour des submodules"
  git -C "$REPO_DIR" submodule update --init --recursive
fi

VENV_PY="$REPO_DIR/.venv/bin/python"
if [ -x "$VENV_PY" ]; then
  echo "==> Virtualenv trouvé, mise à jour des dépendances dans le venv"
  "$VENV_PY" -m pip install --upgrade pip setuptools wheel
  "$VENV_PY" -m pip install -r "$REPO_DIR/requirements.txt"
fi

echo "==> Mise à jour terminée."
