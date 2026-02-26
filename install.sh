#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="comfyui"
REPO_URL="https://github.com/comfyanonymous/ComfyUI.git"
VENV_DIR="$REPO_DIR/.venv"

echo "==> Vérification Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew non trouvé. Veuillez l'installer depuis https://brew.sh/ puis relancer ce script."
  exit 1
fi

echo "==> Vérification / installation de python3.13"
if ! command -v python3.13 >/dev/null 2>&1; then
  echo "python3.13 non trouvé. Installation via Homebrew..."
  brew update
  brew install python@3.13
fi

echo "==> Clonage / mise à jour du dépôt ComfyUI dans ./$REPO_DIR"
if [ -d "$REPO_DIR/.git" ]; then
  echo "Le dépôt existe déjà. Récupération des dernières modifications..."
  git -C "$REPO_DIR" pull --rebase
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Création / réutilisation d'un virtualenv dans $VENV_DIR"
if [ -d "$VENV_DIR" ]; then
  echo "Virtualenv existant trouvé, réutilisation."
else
  python3.13 -m venv "$VENV_DIR"
fi

VENV_PY="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

echo "==> Mise à jour pip dans le virtualenv"
"$VENV_PY" -m pip install --upgrade pip setuptools wheel

echo "==> Installation de torch/nightly (CPU) dans le virtualenv"
"$VENV_PY" -m pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/cpu

echo "==> Installation des dépendances de ComfyUI dans le virtualenv"
"$VENV_PY" -m pip install -r "$REPO_DIR/requirements.txt"

echo "==> Installation terminée. Pour lancer : ./launch.sh"
