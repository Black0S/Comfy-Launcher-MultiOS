#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="comfyui"
REPO_URL="https://github.com/comfyanonymous/ComfyUI.git"
VENV_DIR="$REPO_DIR/.venv"

# ─────────────────────────────────────────────────────────────
# OS SELECTION
# ─────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ComfyUI Installer — Select your OS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1) Fedora / RHEL / CentOS   (dnf)"
echo "  2) Arch Linux               (pacman + pyenv)"
echo "  3) Ubuntu / Debian          (apt)"
echo "  4) macOS                    (brew)"
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
# PYTHON VERSION SELECTION
# ─────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Select Python version"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1) Python 3.12  — ⚠️  Older but maximum compatibility with custom nodes"
echo "  2) Python 3.13  — ✅  Recommended, compatible with most custom nodes"
echo "  3) Python 3.14  — 🧪  Experimental, some custom nodes may not work"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -rp "Your choice [1-3]: " PY_CHOICE

case "$PY_CHOICE" in
  1) PY_VERSION="3.12" ;;
  2) PY_VERSION="3.13" ;;
  3) PY_VERSION="3.14" ;;
  *)
    echo "❌ Invalid choice. Exiting."
    exit 1
    ;;
esac
echo "✅ Selected: Python $PY_VERSION"
echo ""

# ─────────────────────────────────────────────────────────────
# PACKAGE INSTALL HELPER
# ─────────────────────────────────────────────────────────────
pkg_install() {
  case "$OS_TYPE" in
    fedora) sudo dnf install -y "$@" ;;
    arch)   sudo pacman -S --noconfirm "$@" ;;
    ubuntu) sudo apt-get install -y "$@" ;;
    macos)  brew install "$@" ;;
  esac
}

# ─────────────────────────────────────────────────────────────
# SYSTEM DEPENDENCIES (git)
# ─────────────────────────────────────────────────────────────
echo "==> Checking system dependencies"
MISSING_PKGS=()
command -v git >/dev/null 2>&1 || MISSING_PKGS+=(git)

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
  echo "Installing: ${MISSING_PKGS[*]}"
  pkg_install "${MISSING_PKGS[@]}"
fi
echo "✅ git $(git --version | awk '{print $3}')"

# ─────────────────────────────────────────────────────────────
# PYTHON INSTALLATION
# ─────────────────────────────────────────────────────────────
echo "==> Checking Python $PY_VERSION"

# Helper: resolve latest patch version from pyenv list (e.g. 3.13 → 3.13.3)
get_latest_patch() {
  local major_minor="$1"
  pyenv install --list 2>/dev/null \
    | grep -E "^\s*${major_minor}\.[0-9]+$" \
    | sed 's/ //g' \
    | sort -V \
    | tail -n 1
}

if [ "$OS_TYPE" = "arch" ]; then
  # ── Arch Linux: pyenv ──────────────────────────────────────
  echo "==> Setting up pyenv (Arch Linux)"

  # Always ensure build deps are present
  sudo pacman -S --noconfirm --needed \
    base-devel openssl zlib xz tk libffi bzip2 readline sqlite curl git llvm ncurses

  if ! command -v pyenv >/dev/null 2>&1; then
    echo "==> pyenv not found. Installing via AUR..."
    if command -v yay >/dev/null 2>&1; then
      yay -S --noconfirm pyenv
    elif command -v paru >/dev/null 2>&1; then
      paru -S --noconfirm pyenv
    else
      echo "❌ yay or paru is required to install pyenv on Arch."
      echo "   Install one of them first and rerun this script."
      exit 1
    fi
  else
    echo "==> pyenv already installed"
  fi

  # Init pyenv for this session
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"

  # Persist pyenv config in shell rc if not already present
  SHELL_RC=""
  if [ -f "$HOME/.bashrc" ]; then SHELL_RC="$HOME/.bashrc"
  elif [ -f "$HOME/.zshrc" ]; then SHELL_RC="$HOME/.zshrc"
  fi

  if [ -n "$SHELL_RC" ] && ! grep -q "pyenv init" "$SHELL_RC"; then
    {
      echo ""
      echo "# pyenv"
      echo 'export PYENV_ROOT="$HOME/.pyenv"'
      echo 'export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"'
      echo 'eval "$(pyenv init --path)"'
      echo 'eval "$(pyenv init -)"'
    } >> "$SHELL_RC"
    echo "✅ pyenv configured in $SHELL_RC"
  fi

  # Resolve and install the latest patch version
  FULL_PY_VERSION="$(get_latest_patch "$PY_VERSION")"
  if [ -z "$FULL_PY_VERSION" ]; then
    echo "❌ Could not resolve a patch version for Python $PY_VERSION. Exiting."
    exit 1
  fi
  echo "==> Installing Python $FULL_PY_VERSION via pyenv"

  if pyenv versions --bare | grep -q "^${FULL_PY_VERSION}$"; then
    echo "Python $FULL_PY_VERSION already installed in pyenv."
  else
    pyenv install "$FULL_PY_VERSION"
  fi

  pyenv rehash
  PYTHON_BIN="$HOME/.pyenv/versions/$FULL_PY_VERSION/bin/python3"

else
  # ── Other distros: package manager ────────────────────────
  if ! command -v "python$PY_VERSION" >/dev/null 2>&1; then
    echo "python$PY_VERSION not found. Installing..."
    case "$OS_TYPE" in
      fedora) sudo dnf install -y "python$PY_VERSION" ;;
      ubuntu) sudo apt-get install -y "python$PY_VERSION" "python${PY_VERSION}-venv" ;;
      macos)  brew install "python@$PY_VERSION" ;;
    esac
  fi

  if ! command -v "python$PY_VERSION" >/dev/null 2>&1; then
    echo "❌ python$PY_VERSION could not be found after installation. Exiting."
    exit 1
  fi

  PYTHON_BIN="$(command -v "python$PY_VERSION")"
fi

echo "✅ $("$PYTHON_BIN" --version)"

# ─────────────────────────────────────────────────────────────
# GPU / CUDA CHECK (skipped on macOS)
# ─────────────────────────────────────────────────────────────
if [ "$OS_TYPE" != "macos" ]; then
  echo "==> Checking NVIDIA GPU & CUDA"
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✅ NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
  else
    echo "⚠️  nvidia-smi not found. Make sure your NVIDIA drivers are installed."
    echo "   Visit https://www.nvidia.com/Download/index.aspx or use your distro's package manager."
    echo "   Continuing anyway..."
  fi

  echo "==> Checking CUDA toolkit"
  if command -v nvcc >/dev/null 2>&1; then
    echo "✅ CUDA version: $(nvcc --version | grep release | awk '{print $6}' | tr -d ',')"
  else
    echo "⚠️  nvcc not found. CUDA toolkit may not be installed."
    echo "   PyTorch will still work if CUDA runtime is available."
  fi
else
  echo "==> macOS detected — skipping NVIDIA/CUDA check (not applicable)"
fi

# ─────────────────────────────────────────────────────────────
# CLONE / UPDATE COMFYUI
# ─────────────────────────────────────────────────────────────
echo "==> Clone / update ComfyUI in ./$REPO_DIR"
if [ -d "$REPO_DIR/.git" ]; then
  echo "Repo already exists. Pulling latest changes..."
  git -C "$REPO_DIR" pull --rebase
else
  git clone "$REPO_URL" "$REPO_DIR"
fi

# ─────────────────────────────────────────────────────────────
# COMFYUI-MANAGER
# ─────────────────────────────────────────────────────────────
echo "==> Installing ComfyUI-Manager in $REPO_DIR/custom_nodes"
CUSTOM_NODES_DIR="$REPO_DIR/custom_nodes"
MANAGER_DIR="$CUSTOM_NODES_DIR/comfyui-manager"
mkdir -p "$CUSTOM_NODES_DIR"
if [ -d "$MANAGER_DIR/.git" ]; then
  echo "ComfyUI-Manager already exists, updating..."
  git -C "$MANAGER_DIR" pull --rebase
else
  git clone https://github.com/ltdrdata/ComfyUI-Manager "$MANAGER_DIR"
fi

# ─────────────────────────────────────────────────────────────
# VIRTUALENV
# ─────────────────────────────────────────────────────────────
echo "==> Setting up virtualenv in $VENV_DIR"
if [ -d "$VENV_DIR" ]; then
  echo "Existing virtualenv found, reusing it."
else
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

VENV_PY="$VENV_DIR/bin/python"

echo "==> Updating pip"
"$VENV_PY" -m pip install --upgrade pip setuptools wheel

# ─────────────────────────────────────────────────────────────
# PYTORCH INSTALLATION
# ─────────────────────────────────────────────────────────────
if [ "$OS_TYPE" = "macos" ]; then
  echo "==> Installing PyTorch (nightly, CPU — macOS)"
  "$VENV_PY" -m pip install --pre torch torchvision \
    --index-url https://download.pytorch.org/whl/nightly/cpu
else
  echo "==> Installing PyTorch with CUDA support (cu130)"
  "$VENV_PY" -m pip install torch torchvision torchaudio \
    --extra-index-url https://download.pytorch.org/whl/cu130
fi

# ─────────────────────────────────────────────────────────────
# COMFYUI DEPENDENCIES
# ─────────────────────────────────────────────────────────────
echo "==> Installing ComfyUI dependencies"
"$VENV_PY" -m pip install -r "$REPO_DIR/requirements.txt"

# ─────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────
echo ""
echo "✅ Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 PyTorch + CUDA check:"
if [ "$OS_TYPE" = "macos" ]; then
  "$VENV_PY" -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'MPS (Apple GPU) available: {torch.backends.mps.is_available()}')
"
else
  "$VENV_PY" -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')
"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "To launch: ./launch.sh"
