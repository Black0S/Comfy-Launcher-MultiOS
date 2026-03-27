#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="comfyui"
VENV_PY="$REPO_DIR/.venv/bin/python"

# ─────────────────────────────────────────────────────────────
# COLORS & STYLES
# ─────────────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"

# ─────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────
line_sep() {
  echo -e "  ${DIM}${BLUE}──────────────────────────────────────────────────${RESET}"
}

section_title() {
  echo ""
  echo -e "  ${BOLD}${CYAN}$1${RESET}"
  line_sep
}

row() {
  local label="$1"
  local value="$2"
  printf "  ${WHITE}%-18s${RESET}  %s\n" "$label" "$value"
}

# ─────────────────────────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────────────────────────
clear
echo ""
echo -e "  ${BOLD}${MAGENTA}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "  ${BOLD}${MAGENTA}║${RESET}  ${BOLD}${WHITE}       ComfyUI — System Information              ${RESET}${BOLD}${MAGENTA}║${RESET}"
echo -e "  ${BOLD}${MAGENTA}╚══════════════════════════════════════════════════╝${RESET}"

# ─────────────────────────────────────────────────────────────
# DETECT PLATFORM
# ─────────────────────────────────────────────────────────────
UNAME_S="$(uname -s)"
if [ "$UNAME_S" = "Darwin" ]; then
  PLATFORM="macos"
else
  PLATFORM="linux"
fi

# ─────────────────────────────────────────────────────────────
# SECTION 1 — SYSTEM
# ─────────────────────────────────────────────────────────────
section_title "🖥️   SYSTEM"

if [ "$PLATFORM" = "macos" ]; then
  OS_NAME="macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
  KERNEL="$(uname -r)"
  CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'N/A')"
  RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  RAM_GB=$(( RAM_BYTES / 1024 / 1024 / 1024 ))
  RAM="${RAM_GB} GB"
else
  if [ -f /etc/os-release ]; then
    OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  else
    OS_NAME="$(uname -s) $(uname -r)"
  fi
  KERNEL="$(uname -r)"
  CPU=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || echo 'N/A')
  RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
  RAM_GB=$(( RAM_KB / 1024 / 1024 ))
  RAM="${RAM_GB} GB"
fi

row "OS" "$OS_NAME"
row "Kernel" "$KERNEL"
row "CPU" "$CPU"
row "RAM" "$RAM"

# ─────────────────────────────────────────────────────────────
# SECTION 2 — GPU / CUDA
# ─────────────────────────────────────────────────────────────
section_title "⚡  GPU / CUDA"

if [ "$PLATFORM" = "macos" ]; then
  GPU_NAME=$(system_profiler SPDisplaysDataType 2>/dev/null \
    | grep "Chipset Model" | head -1 | cut -d: -f2 | sed 's/^ //' || echo "N/A")
  row "GPU" "${GREEN}$GPU_NAME${RESET}"
  row "CUDA" "${DIM}Not applicable on macOS${RESET}"
  row "Driver" "${DIM}Not applicable on macOS${RESET}"
  MPS_AVAILABLE="N/A"
  if [ -x "$VENV_PY" ]; then
    MPS_AVAILABLE=$("$VENV_PY" -c \
      "import torch; print('Yes' if torch.backends.mps.is_available() else 'No')" \
      2>/dev/null || echo "N/A")
  fi
  row "MPS (Apple GPU)" "${GREEN}$MPS_AVAILABLE${RESET}"
else
  if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "N/A")
    VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1 || echo "N/A")
    DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "N/A")
    row "GPU" "${GREEN}$GPU_NAME${RESET}"
    row "VRAM" "${GREEN}$VRAM${RESET}"
    row "NVIDIA Driver" "$DRIVER"
  else
    row "GPU" "${YELLOW}⚠️  nvidia-smi not found${RESET}"
    row "VRAM" "${DIM}N/A${RESET}"
    row "NVIDIA Driver" "${DIM}N/A${RESET}"
  fi

  if command -v nvcc >/dev/null 2>&1; then
    CUDA_VER=$(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | tr -d ',' || echo "N/A")
    row "CUDA Toolkit" "${GREEN}$CUDA_VER${RESET}"
  else
    row "CUDA Toolkit" "${YELLOW}⚠️  nvcc not found${RESET}"
  fi
fi

# ─────────────────────────────────────────────────────────────
# SECTION 3 — PYTHON
# ─────────────────────────────────────────────────────────────
section_title "🐍  PYTHON"

if [ -x "$VENV_PY" ]; then
  COMFY_PY_VER=$("$VENV_PY" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
else
  COMFY_PY_VER="none"
fi

FOUND_VERSIONS=()
for ver in 3.11 3.12 3.13 3.14; do
  if command -v "python$ver" >/dev/null 2>&1; then
    FOUND_VERSIONS+=("$ver")
  fi
done

# Also check pyenv versions
if command -v pyenv >/dev/null 2>&1; then
  export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
  while IFS= read -r pver; do
    minor=$(echo "$pver" | grep -oE '^3\.(11|12|13|14)' || true)
    if [ -n "$minor" ] && [[ ! " ${FOUND_VERSIONS[*]} " =~ " $minor " ]]; then
      FOUND_VERSIONS+=("$minor")
    fi
  done < <(pyenv versions --bare 2>/dev/null || true)
fi

PY_DISPLAY=""
for ver in "${FOUND_VERSIONS[@]}"; do
  if [ "$ver" = "$COMFY_PY_VER" ]; then
    PY_DISPLAY+="${GREEN}● $ver (ComfyUI)${RESET}  "
  else
    PY_DISPLAY+="${DIM}$ver${RESET}  "
  fi
done

if [ -z "$PY_DISPLAY" ]; then
  PY_DISPLAY="${DIM}N/A${RESET}"
fi

row "Installed" "$(echo -e "$PY_DISPLAY")"

if [ -x "$VENV_PY" ]; then
  FULL_PY_VER=$("$VENV_PY" --version 2>&1 | awk '{print $2}')
  row "ComfyUI venv" "${GREEN}Python $FULL_PY_VER${RESET}"
else
  row "ComfyUI venv" "${YELLOW}⚠️  No venv found — run ./install.sh${RESET}"
fi

# ─────────────────────────────────────────────────────────────
# SECTION 4 — PYTORCH
# ─────────────────────────────────────────────────────────────
section_title "🔥  PYTORCH"

if [ -x "$VENV_PY" ]; then
  TORCH_INFO=$("$VENV_PY" -c "
try:
  import torch
  cuda_available = torch.cuda.is_available()
  mps_available = torch.backends.mps.is_available()
  print(f'version={torch.__version__}')
  print(f'cuda_available={cuda_available}')
  if cuda_available:
    print(f'cuda_version={torch.version.cuda}')
    print(f'gpu_name={torch.cuda.get_device_name(0)}')
    print(f'vram={(torch.cuda.get_device_properties(0).total_memory // 1024**2)} MB')
  print(f'mps_available={mps_available}')
except ImportError:
  print('not_installed=true')
" 2>/dev/null || echo "not_installed=true")

  if echo "$TORCH_INFO" | grep -q "not_installed=true"; then
    row "PyTorch" "${YELLOW}⚠️  Not installed in venv${RESET}"
  else
    TORCH_VER=$(echo "$TORCH_INFO" | grep "^version=" | cut -d= -f2)
    CUDA_AVAIL=$(echo "$TORCH_INFO" | grep "^cuda_available=" | cut -d= -f2)
    MPS_AVAIL=$(echo "$TORCH_INFO" | grep "^mps_available=" | cut -d= -f2)

    row "Version" "${GREEN}$TORCH_VER${RESET}"

    if [ "$PLATFORM" = "macos" ]; then
      if [ "$MPS_AVAIL" = "True" ]; then
        row "MPS (Apple GPU)" "${GREEN}Available ✅${RESET}"
      else
        row "MPS (Apple GPU)" "${YELLOW}Not available${RESET}"
      fi
    else
      if [ "$CUDA_AVAIL" = "True" ]; then
        TORCH_CUDA=$(echo "$TORCH_INFO" | grep "^cuda_version=" | cut -d= -f2)
        TORCH_GPU=$(echo "$TORCH_INFO" | grep "^gpu_name=" | cut -d= -f2)
        TORCH_VRAM=$(echo "$TORCH_INFO" | grep "^vram=" | cut -d= -f2)
        row "CUDA" "${GREEN}Available ✅  ($TORCH_CUDA)${RESET}"
        row "GPU" "${GREEN}$TORCH_GPU${RESET}"
        row "VRAM" "${GREEN}$TORCH_VRAM${RESET}"
      else
        row "CUDA" "${YELLOW}⚠️  Not available${RESET}"
      fi
    fi
  fi
else
  row "PyTorch" "${YELLOW}⚠️  No venv found — run ./install.sh${RESET}"
fi

# ─────────────────────────────────────────────────────────────
# SECTION 5 — COMFYUI
# ─────────────────────────────────────────────────────────────
section_title "🎨  COMFYUI"

if [ -d "$REPO_DIR/.git" ]; then
  COMFY_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
  COMFY_COMMIT=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "N/A")
  COMFY_DATE=$(git -C "$REPO_DIR" log -1 --format="%ci" 2>/dev/null | cut -d' ' -f1 || echo "N/A")
  COMFY_MSG=$(git -C "$REPO_DIR" log -1 --format="%s" 2>/dev/null || echo "N/A")
  row "Branch" "${GREEN}$COMFY_BRANCH${RESET}"
  row "Commit" "${CYAN}$COMFY_COMMIT${RESET}  ${DIM}($COMFY_DATE)${RESET}"
  row "Last commit" "${DIM}$COMFY_MSG${RESET}"
else
  row "ComfyUI" "${YELLOW}⚠️  Not installed — run ./install.sh${RESET}"
fi

MANAGER_DIR="$REPO_DIR/custom_nodes/comfyui-manager"
if [ -d "$MANAGER_DIR/.git" ]; then
  MGR_COMMIT=$(git -C "$MANAGER_DIR" rev-parse --short HEAD 2>/dev/null || echo "N/A")
  MGR_DATE=$(git -C "$MANAGER_DIR" log -1 --format="%ci" 2>/dev/null | cut -d' ' -f1 || echo "N/A")
  row "Manager" "${GREEN}Installed${RESET}  ${DIM}commit $MGR_COMMIT ($MGR_DATE)${RESET}"
else
  row "Manager" "${YELLOW}⚠️  Not found${RESET}"
fi

# ─────────────────────────────────────────────────────────────
# FOOTER
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "  ${DIM}${BLUE}══════════════════════════════════════════════════${RESET}"
echo -e "  ${DIM}To launch ComfyUI: ${WHITE}./launch.sh${RESET}"
echo -e "  ${DIM}${BLUE}══════════════════════════════════════════════════${RESET}"
echo ""
