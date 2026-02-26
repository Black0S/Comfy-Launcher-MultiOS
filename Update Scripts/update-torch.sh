#!/bin/bash

# Torch update script (nightly version)
# Retrieves and installs the latest available nightly version of PyTorch and torchvision

set -e

# Check that the comfyui directory exists
if [ ! -d "../comfyui" ]; then
    echo "❌ Error: the directory '../comfyui' does not exist."
    echo "Make sure you have run '../install.sh' first."
    exit 1
fi

# Check that the venv exists
if [ ! -d "../comfyui/.venv" ]; then
    echo "❌ Error: the virtual environment '../comfyui/.venv' does not exist."
    echo "Make sure you have run '../install.sh' first."
    exit 1
fi

echo "🔄 Updating Torch (nightly version)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Activate the venv and update pip
echo "📦 Activating venv and updating pip..."
source ../comfyui/.venv/bin/activate
pip install --upgrade pip

# Retrieve and install the latest nightly version of torch and torchvision
echo "📥 Installing PyTorch and torchvision (nightly, CPU)..."
pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/cpu

# Verify the installation
echo ""
echo "✅ Update complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Installed Torch version:"
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
