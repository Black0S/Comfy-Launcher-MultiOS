#!/usr/bin/env bash
set -euo pipefail

# ═════════════════════════════════════════════════════════════
#  invoke.sh — All-in-one InvokeAI manager (install / launch /
#  update / switch Python / system info) for Linux & macOS.
#
#  Just run:  ./invoke.sh   → an interactive menu appears.
# ═════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────────────────────────
# InvokeAI is installed with pip into a venv; models/config/outputs
# live in a separate "root" directory (INVOKEAI_ROOT).
INVOKE_DIR="invokeai"
VENV_DIR="$INVOKE_DIR/.venv"
VENV_PY="$VENV_DIR/bin/python"
INVOKE_BIN="$VENV_DIR/bin/invokeai-web"
ROOT_DIR="$INVOKE_DIR/root"

# HTTPS (self-signed) certificate location
CERT_DIR="certs"
TLS_KEY="$CERT_DIR/key.pem"
TLS_CERT="$CERT_DIR/cert.pem"

# Saved launch profiles (name<TAB>listen<TAB>port<TAB>tls<TAB>extra), one per line.
INVOKE_PROFILES_FILE="invoke-profiles.conf"

# PyTorch CUDA wheel channel (Linux). Override if your driver is older, e.g.:
#   TORCH_CUDA_CHANNEL=cu121 ./invoke.sh
TORCH_CUDA_CHANNEL="${TORCH_CUDA_CHANNEL:-cu124}"

# ─────────────────────────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────────────────────────
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
WHITE=$'\033[1;37m'

SEP="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ═════════════════════════════════════════════════════════════
# GENERIC HELPERS
# ═════════════════════════════════════════════════════════════
pause() { echo ""; read -rp "↩  Press Enter to return to the menu..." _ || true; }

# True when we're on (or targeting) macOS.
is_macos() {
  [ "${OS_TYPE:-}" = "macos" ] || { [ -z "${OS_TYPE:-}" ] && [ "$(uname)" = "Darwin" ]; }
}

# Auto-detect the OS family. Returns non-zero if inconclusive.
detect_os() {
  if [ "$(uname -s)" = "Darwin" ]; then
    echo "macos"; return 0
  fi
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
      *" fedora "*|*" rhel "*|*" centos "*) echo "fedora"; return 0 ;;
      *" arch "*)                           echo "arch";   return 0 ;;
      *" debian "*|*" ubuntu "*)            echo "ubuntu"; return 0 ;;
    esac
  fi
  if command -v dnf     >/dev/null 2>&1; then echo "fedora"; return 0; fi
  if command -v pacman  >/dev/null 2>&1; then echo "arch";   return 0; fi
  if command -v apt-get >/dev/null 2>&1; then echo "ubuntu"; return 0; fi
  return 1
}

# Manual OS picker, used as a fallback when detection fails. Sets OS_TYPE.
prompt_os() {
  echo "  1) Fedora / RHEL / CentOS   (dnf)"
  echo "  2) Arch Linux               (pacman + pyenv)"
  echo "  3) Ubuntu / Debian          (apt)"
  echo "  4) macOS                    (brew)"
  echo "$SEP"
  while true; do
    read -rp "Your choice [1-4]: " OS_CHOICE
    case "$OS_CHOICE" in
      1) OS_TYPE="fedora"; break ;;
      2) OS_TYPE="arch";   break ;;
      3) OS_TYPE="ubuntu"; break ;;
      4) OS_TYPE="macos";  break ;;
      *) echo "❌ Invalid choice, try again." ;;
    esac
  done
}

# Resolve OS_TYPE (auto, fallback to manual).
resolve_os() {
  echo "==> Detecting operating system..."
  if OS_TYPE="$(detect_os)"; then
    echo "✅ Detected OS: $OS_TYPE"
  else
    echo "⚠️  Could not auto-detect your OS. Please choose manually:"
    prompt_os
    echo "✅ Selected: $OS_TYPE"
  fi
}

# Python version picker. Optional arg = current version to highlight. Sets PY_VERSION.
prompt_python() {
  local current="${1:-}"
  echo "$SEP"
  echo "  Select Python version"
  echo "$SEP"
  local entry num ver note
  for entry in \
    "1|3.10|⚠️  Older but maximum compatibility" \
    "2|3.11|✅  Recommended for InvokeAI" \
    "3|3.12|🧪  Supported on recent InvokeAI releases"; do
    num="${entry%%|*}"; ver="${entry#*|}"; ver="${ver%%|*}"; note="${entry##*|}"
    if [ "$ver" = "$current" ]; then
      echo -e "  $num) ${YELLOW}Python $ver  ← already in use${RESET}  $note"
    else
      echo "  $num) Python $ver  — $note"
    fi
  done
  echo "$SEP"
  while true; do
    read -rp "Your choice [1-3]: " PY_CHOICE
    case "$PY_CHOICE" in
      1) PY_VERSION="3.10"; break ;;
      2) PY_VERSION="3.11"; break ;;
      3) PY_VERSION="3.12"; break ;;
      *) echo "❌ Invalid choice, try again." ;;
    esac
  done
}

pkg_install() {
  case "$OS_TYPE" in
    fedora) sudo dnf install -y "$@" ;;
    arch)   sudo pacman -S --noconfirm "$@" ;;
    ubuntu) sudo apt-get install -y "$@" ;;
    macos)  brew install "$@" ;;
  esac
}

# Resolve latest patch version from pyenv (e.g. 3.11 → 3.11.9)
get_latest_patch() {
  local major_minor="$1"
  pyenv install --list 2>/dev/null \
    | grep -E "^\s*${major_minor}\.[0-9]+$" \
    | sed 's/ //g' | sort -V | tail -n 1
}

# Ensure the chosen Python is installed. Needs OS_TYPE + PY_VERSION. Sets PYTHON_BIN.
ensure_python() {
  echo "==> Checking Python $PY_VERSION"
  if [ "$OS_TYPE" = "arch" ]; then
    echo "==> Setting up pyenv (Arch Linux)"
    sudo pacman -S --noconfirm --needed \
      base-devel openssl zlib xz tk libffi bzip2 readline sqlite curl git llvm ncurses

    if ! command -v pyenv >/dev/null 2>&1; then
      echo "==> pyenv not found. Installing via AUR..."
      if command -v yay >/dev/null 2>&1; then yay -S --noconfirm pyenv
      elif command -v paru >/dev/null 2>&1; then paru -S --noconfirm pyenv
      else
        echo "❌ yay or paru is required to install pyenv on Arch."
        exit 1
      fi
    fi

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"

    local rc=""
    if [ -f "$HOME/.bashrc" ]; then rc="$HOME/.bashrc"
    elif [ -f "$HOME/.zshrc" ]; then rc="$HOME/.zshrc"; fi
    if [ -n "$rc" ] && ! grep -q "pyenv init" "$rc"; then
      {
        echo ""; echo "# pyenv"
        echo 'export PYENV_ROOT="$HOME/.pyenv"'
        echo 'export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"'
        echo 'eval "$(pyenv init --path)"'
        echo 'eval "$(pyenv init -)"'
      } >> "$rc"
      echo "✅ pyenv configured in $rc"
    fi

    local full; full="$(get_latest_patch "$PY_VERSION")"
    [ -n "$full" ] || { echo "❌ Could not resolve a patch version for Python $PY_VERSION."; exit 1; }
    echo "==> Installing Python $full via pyenv"
    if pyenv versions --bare | grep -q "^${full}$"; then
      echo "Python $full already installed in pyenv."
    else
      pyenv install "$full"
    fi
    pyenv rehash
    PYTHON_BIN="$HOME/.pyenv/versions/$full/bin/python3"
  else
    if ! command -v "python$PY_VERSION" >/dev/null 2>&1; then
      echo "python$PY_VERSION not found. Installing..."
      case "$OS_TYPE" in
        fedora) sudo dnf install -y "python$PY_VERSION" ;;
        ubuntu) sudo apt-get install -y "python$PY_VERSION" "python${PY_VERSION}-venv" ;;
        macos)  brew install "python@$PY_VERSION" ;;
      esac
    fi
    command -v "python$PY_VERSION" >/dev/null 2>&1 \
      || { echo "❌ python$PY_VERSION could not be found after installation."; exit 1; }
    PYTHON_BIN="$(command -v "python$PY_VERSION")"
  fi
  echo "✅ $("$PYTHON_BIN" --version)"
}

gpu_check() {
  echo "==> Checking NVIDIA GPU & CUDA"
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "✅ NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
  else
    echo "⚠️  nvidia-smi not found. Make sure your NVIDIA drivers are installed. Continuing..."
  fi
  if command -v nvcc >/dev/null 2>&1; then
    echo "✅ CUDA version: $(nvcc --version | grep release | awk '{print $6}' | tr -d ',')"
  else
    echo "⚠️  nvcc not found. PyTorch will still work if CUDA runtime is available."
  fi
}

# pip-install (or upgrade) InvokeAI into the venv, with the right torch source.
# Extra pip args (e.g. --upgrade) are passed through verbatim.
pip_install_invokeai() {
  if is_macos; then
    echo "==> Installing InvokeAI (CPU/MPS — macOS)"
    "$VENV_PY" -m pip install --use-pep517 "$@" InvokeAI
  else
    echo "==> Installing InvokeAI with CUDA support ($TORCH_CUDA_CHANNEL)"
    "$VENV_PY" -m pip install --use-pep517 "$@" "InvokeAI[xformers]" \
      --extra-index-url "https://download.pytorch.org/whl/$TORCH_CUDA_CHANNEL"
  fi
}

install_pytorch() {
  if is_macos; then
    echo "==> Installing PyTorch (CPU/MPS — macOS)"
    "$VENV_PY" -m pip install --upgrade torch torchvision
  else
    echo "==> Installing PyTorch with CUDA support ($TORCH_CUDA_CHANNEL)"
    "$VENV_PY" -m pip install --upgrade torch torchvision \
      --index-url "https://download.pytorch.org/whl/$TORCH_CUDA_CHANNEL"
  fi
}

torch_check() {
  echo "📊 PyTorch check:"
  if is_macos; then
    "$VENV_PY" -c '
import torch
print("PyTorch:", torch.__version__)
print("MPS (Apple GPU) available:", torch.backends.mps.is_available())
'
  else
    "$VENV_PY" -c '
import torch
print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("GPU:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "N/A")
'
  fi
}

# Generate a self-signed certificate if none exists.
ensure_cert() {
  if [ -f "$TLS_KEY" ] && [ -f "$TLS_CERT" ]; then
    return 0
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    echo "❌ openssl is required to generate a self-signed certificate."
    return 1
  fi
  echo "==> Generating a self-signed certificate in ./$CERT_DIR"
  mkdir -p "$CERT_DIR"
  # Try with SAN (openssl 1.1.1+); fall back without it on older/LibreSSL.
  if ! openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$TLS_KEY" -out "$TLS_CERT" -days 3650 \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1; then
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "$TLS_KEY" -out "$TLS_CERT" -days 3650 \
      -subj "/CN=localhost" >/dev/null 2>&1
  fi
  echo "✅ Certificate ready (${TLS_CERT}). Your browser will warn once — accept the exception."
}

# ═════════════════════════════════════════════════════════════
# COMMANDS
# ═════════════════════════════════════════════════════════════

cmd_install() {
  echo ""; echo "$SEP"; echo "  ${BOLD}Install / Reinstall InvokeAI${RESET}"; echo "$SEP"
  resolve_os
  echo ""
  prompt_python
  echo "✅ Selected: Python $PY_VERSION"; echo ""

  ensure_python

  if [ "$OS_TYPE" != "macos" ]; then
    gpu_check
  else
    echo "==> macOS detected — skipping NVIDIA/CUDA check (not applicable)"
  fi

  echo "==> Preparing InvokeAI directory ./$INVOKE_DIR"
  mkdir -p "$INVOKE_DIR"

  echo "==> Setting up virtualenv in $VENV_DIR"
  if [ ! -d "$VENV_DIR" ]; then
    "$PYTHON_BIN" -m venv "$VENV_DIR"
  else
    echo "Existing virtualenv found, reusing it."
  fi

  echo "==> Updating pip"
  "$VENV_PY" -m pip install --upgrade pip setuptools wheel

  pip_install_invokeai

  echo "==> Creating InvokeAI root in ./$ROOT_DIR"
  mkdir -p "$ROOT_DIR"

  echo ""; echo "✅ Installation complete!"; echo "$SEP"
  torch_check
  echo "$SEP"
  echo "To launch: choose option 2 in the menu."
}

# ── Launch profiles (saved address configurations) ───────────
# File format: name<TAB>listen<TAB>port<TAB>tls(0|1)<TAB>extra-flags

profiles_count() {
  if [ -f "$INVOKE_PROFILES_FILE" ]; then awk 'END{print NR}' "$INVOKE_PROFILES_FILE"; else echo 0; fi
}

# Human-readable URL for a profile.
profile_url() {
  local listen="$1" port="$2" tls="$3" scheme="http" host
  [ "$tls" = "1" ] && scheme="https"
  host="$listen"; [ "$listen" = "0.0.0.0" ] && host="<this-machine-IP>"
  echo "$scheme://$host:$port"
}

list_profiles() {
  local i=0 name listen port tls extra
  while IFS=$'\t' read -r name listen port tls extra; do
    i=$((i+1))
    printf "    ${WHITE}%d)${RESET} %-14s ${DIM}→  %s${RESET}\n" \
      "$i" "$name" "$(profile_url "$listen" "$port" "$tls")"
  done < "$INVOKE_PROFILES_FILE"
}

# Load profile N into PROF_NAME / PROF_LISTEN / PROF_PORT / PROF_TLS / PROF_EXTRA.
load_profile() {
  local line; line="$(sed -n "${1}p" "$INVOKE_PROFILES_FILE")"
  IFS=$'\t' read -r PROF_NAME PROF_LISTEN PROF_PORT PROF_TLS PROF_EXTRA <<< "$line"
  PROF_EXTRA="${PROF_EXTRA:-}"
}

save_profile() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$INVOKE_PROFILES_FILE"
}

delete_profile() {
  local tmp; tmp="$(mktemp)"
  awk -v n="$1" 'NR!=n' "$INVOKE_PROFILES_FILE" > "$tmp"
  mv "$tmp" "$INVOKE_PROFILES_FILE"
}

# replace_profile N name listen port tls extra
replace_profile() {
  local n="$1" name="$2" listen="$3" port="$4" tls="$5" extra="$6"
  local tmp i=0 ln; tmp="$(mktemp)"
  while IFS= read -r ln; do
    i=$((i+1))
    if [ "$i" -eq "$n" ]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$listen" "$port" "$tls" "$extra" >> "$tmp"
    else
      printf '%s\n' "$ln" >> "$tmp"
    fi
  done < "$INVOKE_PROFILES_FILE"
  mv "$tmp" "$INVOKE_PROFILES_FILE"
}

# Prompt for a custom listen address + port. Sets LISTEN_ADDR and PORT.
prompt_address() {
  local a p
  read -rp "Listen address [0.0.0.0]: " a; LISTEN_ADDR="${a:-0.0.0.0}"
  read -rp "Port [9090]: " p;            PORT="${p:-9090}"
}

# Edit/delete an existing profile interactively.
manage_profiles() {
  local n sel act
  while true; do
    n="$(profiles_count)"
    [ "$n" -eq 0 ] && { echo "  (no saved profiles)"; return 0; }
    echo ""; echo "  ${BOLD}Saved profiles${RESET}"
    list_profiles
    echo "    ${WHITE}0)${RESET} Back"
    read -rp "  Select a profile to edit/delete: " sel
    [ "$sel" = "0" ] && return 0
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "$n" ]; then
      load_profile "$sel"
      echo "  → '$PROF_NAME'  $(profile_url "$PROF_LISTEN" "$PROF_PORT" "$PROF_TLS")  ${DIM}${PROF_EXTRA}${RESET}"
      echo "    1) Edit   2) Delete   0) Cancel"
      read -rp "  Action: " act
      case "$act" in
        1) edit_profile "$sel" ;;
        2) delete_profile "$sel"; echo "  🗑  Deleted '$PROF_NAME'." ;;
        *) ;;
      esac
    else
      echo "  ❌ Invalid choice."
    fi
  done
}

edit_profile() {
  load_profile "$1"
  local name listen port tls extra t tlsdef
  read -rp "  Name [$PROF_NAME]: " name;            name="${name:-$PROF_NAME}"
  read -rp "  Listen address [$PROF_LISTEN]: " listen; listen="${listen:-$PROF_LISTEN}"
  read -rp "  Port [$PROF_PORT]: " port;            port="${port:-$PROF_PORT}"
  tlsdef="n"; [ "$PROF_TLS" = "1" ] && tlsdef="y"
  read -rp "  HTTPS? [y/n] [$tlsdef]: " t; t="${t:-$tlsdef}"
  case "$t" in y|Y|1) tls=1 ;; *) tls=0 ;; esac
  read -rp "  Extra flags [$PROF_EXTRA]: " extra; extra="${extra-$PROF_EXTRA}"
  replace_profile "$1" "$name" "$listen" "$port" "$tls" "$extra"
  echo "  ✅ Updated '$name'."
}

# Build env from LISTEN_ADDR / PORT / USE_TLS / EXTRA and exec InvokeAI.
do_launch() {
  local SCHEME="http"
  local root_abs; root_abs="$(cd "$(dirname "$ROOT_DIR")" && pwd)/$(basename "$ROOT_DIR")"

  # InvokeAI reads all settings from INVOKEAI_* environment variables.
  export INVOKEAI_ROOT="$root_abs"
  export INVOKEAI_HOST="$LISTEN_ADDR"
  export INVOKEAI_PORT="$PORT"

  if [ "$USE_TLS" = "1" ]; then
    ensure_cert || return 0
    export INVOKEAI_SSL_CERTFILE="$PWD/$TLS_CERT"
    export INVOKEAI_SSL_KEYFILE="$PWD/$TLS_KEY"
    SCHEME="https"
  fi

  # Append any extra flags (word-split on purpose).
  local ARGS=()
  if [ -n "${EXTRA:-}" ]; then
    # shellcheck disable=SC2206
    ARGS+=( $EXTRA )
  fi

  if [ "$LISTEN_ADDR" != "127.0.0.1" ] && [ "$LISTEN_ADDR" != "localhost" ]; then
    echo ""
    echo -e "  ${YELLOW}⚠️  SECURITY:${RESET} InvokeAI has no authentication. Listening on"
    echo -e "  ${YELLOW}   '$LISTEN_ADDR' exposes the full UI (and the model/file APIs)"
    echo -e "  ${YELLOW}   to anyone who can reach it. Use only on a trusted network${RESET}"
    echo -e "  ${YELLOW}   (e.g. Tailscale), or behind an authenticated reverse proxy.${RESET}"
  fi

  local host="$LISTEN_ADDR"
  [ "$LISTEN_ADDR" = "0.0.0.0" ] && host="<this-machine-IP>"
  echo ""
  echo "🚀 Starting InvokeAI..."
  echo "   Root: $INVOKEAI_ROOT"
  echo "   Open your browser at: $SCHEME://$host:$PORT"
  echo ""
  exec "$INVOKE_BIN" ${ARGS[@]+"${ARGS[@]}"}
}

# Interactive "new launch" flow (choose mode, optionally save), then launch.
configure_launch() {
  echo ""
  echo "  How do you want to serve InvokeAI?"
  echo "$SEP"
  echo "  1) Local            — http://127.0.0.1:9090"
  echo "  2) Custom address   — choose IP + port (HTTP)"
  echo "  3) Local HTTPS      — https://127.0.0.1:9090 (self-signed)"
  echo "  4) Custom HTTPS     — choose IP + port (self-signed)"
  echo "$SEP"

  USE_TLS=0; LISTEN_ADDR="127.0.0.1"; PORT="9090"; EXTRA=""
  local MODE
  while true; do
    read -rp "Your choice [1-4]: " MODE
    case "$MODE" in
      1) break ;;
      2) prompt_address; break ;;
      3) USE_TLS=1; break ;;
      4) USE_TLS=1; prompt_address; break ;;
      *) echo "❌ Invalid choice, try again." ;;
    esac
  done

  read -rp "Extra flags (optional, passed to invokeai-web) [none]: " EXTRA

  local pname
  read -rp "Save this as a profile? Enter a name (empty = don't save): " pname
  if [ -n "$pname" ]; then
    save_profile "$pname" "$LISTEN_ADDR" "$PORT" "$USE_TLS" "$EXTRA"
    echo "✅ Saved profile '$pname' (in $INVOKE_PROFILES_FILE)."
  fi

  do_launch
}

cmd_launch() {
  echo ""; echo "$SEP"; echo "  ${BOLD}Launch InvokeAI${RESET}"; echo "$SEP"
  if [ ! -d "$INVOKE_DIR" ]; then
    echo "❌ Directory $INVOKE_DIR not found. Run Install (option 1) first."; return 0
  fi
  if [ ! -x "$INVOKE_BIN" ]; then
    echo "❌ InvokeAI not found in venv. Run Install (option 1) first."; return 0
  fi

  local n c
  while true; do
    n="$(profiles_count)"
    if [ "$n" -gt 0 ]; then
      echo ""
      echo "  ${BOLD}Saved profiles${RESET} ${DIM}(pick a number to launch)${RESET}"
      list_profiles
      echo ""
    fi
    echo "  ${WHITE}n)${RESET} New launch configuration"
    [ "$n" -gt 0 ] && echo "  ${WHITE}e)${RESET} Edit / delete a saved profile"
    echo "  ${WHITE}0)${RESET} Back to main menu"
    read -rp "  Your choice: " c
    case "$c" in
      0)   return 0 ;;
      n|N) configure_launch; return 0 ;;
      e|E) [ "$n" -gt 0 ] && manage_profiles ;;
      *)
        if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "$n" ]; then
          load_profile "$c"
          LISTEN_ADDR="$PROF_LISTEN"; PORT="$PROF_PORT"; USE_TLS="$PROF_TLS"; EXTRA="$PROF_EXTRA"
          echo ""; echo "▶  Launching profile '$PROF_NAME'"
          do_launch; return 0
        else
          echo "  ❌ Invalid choice."
        fi
        ;;
    esac
  done
}

cmd_update_invoke() {
  echo ""; echo "$SEP"; echo "  ${BOLD}Update InvokeAI${RESET}"; echo "$SEP"
  if [ ! -d "$INVOKE_DIR" ] || [ ! -x "$VENV_PY" ]; then
    echo "❌ No venv found. Run Install (option 1) first."; return 0
  fi
  echo "==> Updating pip"
  "$VENV_PY" -m pip install --upgrade pip setuptools wheel
  pip_install_invokeai --upgrade
  echo ""; echo "✅ Update complete."
}

cmd_update_torch() {
  echo ""; echo "$SEP"; echo "  ${BOLD}Update PyTorch${RESET}"; echo "$SEP"
  if [ ! -d "$INVOKE_DIR" ] || [ ! -x "$VENV_PY" ]; then
    echo "❌ No venv found. Run Install (option 1) first."; return 0
  fi
  resolve_os
  echo "==> Updating pip..."
  "$VENV_PY" -m pip install --upgrade pip
  install_pytorch
  echo ""; echo "✅ Update complete!"; echo "$SEP"
  torch_check
}

cmd_switchpy() {
  echo ""; echo "$SEP"; echo "  ${BOLD}Switch Python version${RESET}"; echo "$SEP"
  if [ ! -d "$INVOKE_DIR" ] || [ ! -x "$VENV_PY" ]; then
    echo "❌ No venv found. Run Install (option 1) first."; return 0
  fi
  local current; current="$("$VENV_PY" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  echo -e "  Current venv Python version: ${GREEN}$current${RESET}"; echo ""
  prompt_python "$current"
  if [ "$PY_VERSION" = "$current" ]; then
    echo ""; echo "⚠️  Python $PY_VERSION is already the active version. Nothing to do."; return 0
  fi
  echo ""; echo -e "✅ Switching from Python $current → ${GREEN}$PY_VERSION${RESET}"; echo ""
  resolve_os
  ensure_python

  echo ""; echo "==> Removing old virtualenv (Python $current)..."
  rm -rf "$VENV_DIR"
  echo "==> Creating new virtualenv with Python $PY_VERSION..."
  "$PYTHON_BIN" -m venv "$VENV_DIR"
  echo "==> Updating pip"
  "$VENV_PY" -m pip install --upgrade pip setuptools wheel
  pip_install_invokeai
  echo ""; echo "✅ Switch complete!"; echo "$SEP"
  echo -e "  Python: ${GREEN}$current → $PY_VERSION${RESET}"
  echo -e "  ${DIM}Your models & config in ./$ROOT_DIR are untouched.${RESET}"
  torch_check
}

# ─────────────────────────────────────────────────────────────
# SYSTEM INFO DASHBOARD
# ─────────────────────────────────────────────────────────────
cmd_info() {
  local line_sep section_title row platform
  line_sep() { echo -e "  ${DIM}${BLUE}──────────────────────────────────────────────────${RESET}"; }
  section_title() { echo ""; echo -e "  ${BOLD}${CYAN}$1${RESET}"; line_sep; }
  row() { printf "  ${WHITE}%-18s${RESET}  %s\n" "$1" "$2"; }

  echo ""
  echo -e "  ${BOLD}${MAGENTA}╔══════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${BOLD}${MAGENTA}║${RESET}  ${BOLD}${WHITE}       InvokeAI — System Information            ${RESET}${BOLD}${MAGENTA}║${RESET}"
  echo -e "  ${BOLD}${MAGENTA}╚══════════════════════════════════════════════════╝${RESET}"

  if [ "$(uname -s)" = "Darwin" ]; then platform="macos"; else platform="linux"; fi

  # ── SYSTEM ──
  section_title "🖥️   SYSTEM"
  local OS_NAME KERNEL CPU RAM
  if [ "$platform" = "macos" ]; then
    OS_NAME="macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    KERNEL="$(uname -r)"
    CPU="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'N/A')"
    RAM="$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1024 / 1024 / 1024 )) GB"
  else
    if [ -f /etc/os-release ]; then OS_NAME=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"'); else OS_NAME="$(uname -s) $(uname -r)"; fi
    KERNEL="$(uname -r)"
    CPU=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || echo 'N/A')
    RAM="$(( $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0) / 1024 / 1024 )) GB"
  fi
  row "OS" "$OS_NAME"; row "Kernel" "$KERNEL"; row "CPU" "$CPU"; row "RAM" "$RAM"

  # ── GPU / CUDA ──
  section_title "⚡  GPU / CUDA"
  if [ "$platform" = "macos" ]; then
    local gpu; gpu=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Chipset Model" | head -1 | cut -d: -f2 | sed 's/^ //' || echo "N/A")
    row "GPU" "${GREEN}$gpu${RESET}"
    local mps="N/A"
    [ -x "$VENV_PY" ] && mps=$("$VENV_PY" -c "import torch; print('Yes' if torch.backends.mps.is_available() else 'No')" 2>/dev/null || echo "N/A")
    row "MPS (Apple GPU)" "${GREEN}$mps${RESET}"
  else
    if command -v nvidia-smi >/dev/null 2>&1; then
      row "GPU" "${GREEN}$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)${RESET}"
      row "VRAM" "${GREEN}$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)${RESET}"
      row "NVIDIA Driver" "$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)"
    else
      row "GPU" "${YELLOW}⚠️  nvidia-smi not found${RESET}"
    fi
    if command -v nvcc >/dev/null 2>&1; then
      row "CUDA Toolkit" "${GREEN}$(nvcc --version 2>/dev/null | grep release | awk '{print $6}' | tr -d ',')${RESET}"
    else
      row "CUDA Toolkit" "${YELLOW}⚠️  nvcc not found${RESET}"
    fi
  fi

  # ── PYTHON ──
  section_title "🐍  PYTHON"
  local invoke_py="none"
  [ -x "$VENV_PY" ] && invoke_py=$("$VENV_PY" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
  local FOUND_VERSIONS=() ver
  for ver in 3.10 3.11 3.12 3.13; do
    command -v "python$ver" >/dev/null 2>&1 && FOUND_VERSIONS+=("$ver")
  done
  if command -v pyenv >/dev/null 2>&1; then
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
    local pver minor
    while IFS= read -r pver; do
      minor=$(echo "$pver" | grep -oE '^3\.(10|11|12|13)' || true)
      if [ -n "$minor" ] && [[ ! " ${FOUND_VERSIONS[*]:-} " =~ " $minor " ]]; then
        FOUND_VERSIONS+=("$minor")
      fi
    done < <(pyenv versions --bare 2>/dev/null || true)
  fi
  local py_display=""
  if [ ${#FOUND_VERSIONS[@]} -gt 0 ]; then
    for ver in "${FOUND_VERSIONS[@]}"; do
      if [ "$ver" = "$invoke_py" ]; then py_display+="${GREEN}● $ver (InvokeAI)${RESET}  "; else py_display+="${DIM}$ver${RESET}  "; fi
    done
  fi
  [ -z "$py_display" ] && py_display="${DIM}N/A${RESET}"
  row "Installed" "$(echo -e "$py_display")"
  if [ -x "$VENV_PY" ]; then
    row "InvokeAI venv" "${GREEN}Python $("$VENV_PY" --version 2>&1 | awk '{print $2}')${RESET}"
  else
    row "InvokeAI venv" "${YELLOW}⚠️  No venv found — run Install${RESET}"
  fi

  # ── PYTORCH ──
  section_title "🔥  PYTORCH"
  if [ -x "$VENV_PY" ]; then
    local info; info=$("$VENV_PY" -c '
try:
  import torch
  cuda = torch.cuda.is_available()
  mps = torch.backends.mps.is_available()
  print(f"version={torch.__version__}")
  print(f"cuda_available={cuda}")
  if cuda:
    print(f"cuda_version={torch.version.cuda}")
    print(f"gpu_name={torch.cuda.get_device_name(0)}")
    print(f"vram={(torch.cuda.get_device_properties(0).total_memory // 1024**2)} MB")
  print(f"mps_available={mps}")
except ImportError:
  print("not_installed=true")
' 2>/dev/null || echo "not_installed=true")
    if echo "$info" | grep -q "not_installed=true"; then
      row "PyTorch" "${YELLOW}⚠️  Not installed in venv${RESET}"
    else
      row "Version" "${GREEN}$(echo "$info" | grep '^version=' | cut -d= -f2)${RESET}"
      if [ "$platform" = "macos" ]; then
        if [ "$(echo "$info" | grep '^mps_available=' | cut -d= -f2)" = "True" ]; then
          row "MPS (Apple GPU)" "${GREEN}Available ✅${RESET}"
        else
          row "MPS (Apple GPU)" "${YELLOW}Not available${RESET}"
        fi
      else
        if [ "$(echo "$info" | grep '^cuda_available=' | cut -d= -f2)" = "True" ]; then
          row "CUDA" "${GREEN}Available ✅  ($(echo "$info" | grep '^cuda_version=' | cut -d= -f2))${RESET}"
          row "GPU" "${GREEN}$(echo "$info" | grep '^gpu_name=' | cut -d= -f2)${RESET}"
          row "VRAM" "${GREEN}$(echo "$info" | grep '^vram=' | cut -d= -f2)${RESET}"
        else
          row "CUDA" "${YELLOW}⚠️  Not available${RESET}"
        fi
      fi
    fi
  else
    row "PyTorch" "${YELLOW}⚠️  No venv found — run Install${RESET}"
  fi

  # ── INVOKEAI ──
  section_title "🎨  INVOKEAI"
  if [ -x "$VENV_PY" ]; then
    local iv; iv=$("$VENV_PY" -m pip show invokeai 2>/dev/null | awk -F': ' '/^Version/{print $2}')
    if [ -n "$iv" ]; then
      row "Version" "${GREEN}$iv${RESET}"
    else
      row "InvokeAI" "${YELLOW}⚠️  Not installed in venv${RESET}"
    fi
  else
    row "InvokeAI" "${YELLOW}⚠️  No venv found — run Install${RESET}"
  fi
  if [ -d "$ROOT_DIR" ]; then
    row "Root" "${GREEN}$ROOT_DIR${RESET}"
    local models_n
    models_n=$(find "$ROOT_DIR/models" -mindepth 1 -maxdepth 3 -type f 2>/dev/null | wc -l | tr -d ' ')
    row "Model files" "${CYAN}${models_n:-0}${RESET}"
  else
    row "Root" "${YELLOW}⚠️  Not initialized — run Install${RESET}"
  fi
  echo ""
}

# ═════════════════════════════════════════════════════════════
# MAIN MENU
# ═════════════════════════════════════════════════════════════
main_menu() {
  while true; do
    clear 2>/dev/null || true
    echo ""
    echo -e "  ${BOLD}${MAGENTA}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${BOLD}${MAGENTA}║${RESET}  ${BOLD}${WHITE}        Invoke-Launcher  —  invoke.sh           ${RESET}${BOLD}${MAGENTA}║${RESET}"
    echo -e "  ${BOLD}${MAGENTA}╚══════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "    ${WHITE}1)${RESET} 📦  Install / Reinstall InvokeAI"
    echo -e "    ${WHITE}2)${RESET} 🚀  Launch InvokeAI  ${DIM}(HTTP / HTTPS / custom address)${RESET}"
    echo -e "    ${WHITE}3)${RESET} 🔄  Update InvokeAI"
    echo -e "    ${WHITE}4)${RESET} 🔥  Update PyTorch"
    echo -e "    ${WHITE}5)${RESET} 🐍  Switch Python version"
    echo -e "    ${WHITE}6)${RESET} 📊  System info"
    echo -e "    ${WHITE}0)${RESET} 🚪  Quit"
    echo ""
    read -rp "  Your choice: " CHOICE
    case "$CHOICE" in
      1) cmd_install;       pause ;;
      2) cmd_launch;        pause ;;
      3) cmd_update_invoke; pause ;;
      4) cmd_update_torch;  pause ;;
      5) cmd_switchpy;      pause ;;
      6) cmd_info;          pause ;;
      0|q|Q) echo "Bye! 👋"; exit 0 ;;
      *) echo "❌ Invalid choice."; sleep 1 ;;
    esac
  done
}

main_menu
