#!/bin/bash

# Script de mise à jour de Torch (version nightly)
# Récupère et installe la dernière version nightly disponible de PyTorch et torchvision

set -e

# Vérifier que le répertoire comfyui existe
if [ ! -d "../comfyui" ]; then
    echo "❌ Erreur : le répertoire '../comfyui' n'existe pas."
    echo "Assurez-vous d'avoir exécuté '../install.sh' d'abord."
    exit 1
fi

# Vérifier que le venv existe
if [ ! -d "../comfyui/.venv" ]; then
    echo "❌ Erreur : l'environnement virtuel '../comfyui/.venv' n'existe pas."
    echo "Assurez-vous d'avoir exécuté '../install.sh' d'abord."
    exit 1
fi

echo "🔄 Mise à jour de Torch (version nightly)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Activer le venv et mettre à jour pip
echo "📦 Activation du venv et mise à jour de pip..."
source ../comfyui/.venv/bin/activate
pip install --upgrade pip

# Récupérer et installer la dernière version nightly de torch et torchvision
echo "📥 Installation de PyTorch et torchvision (nightly, CPU)..."
pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/cpu

# Vérifier l'installation
echo ""
echo "✅ Mise à jour terminée !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Version de Torch installée :"
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
