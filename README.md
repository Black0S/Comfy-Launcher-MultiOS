# Comfy-Launcher-MultiOS

A single Bash script (`comfy.sh`) to install, launch, update, and manage [ComfyUI](https://github.com/comfyanonymous/ComfyUI) on Linux and macOS — with multi-OS support, Python version selection, HTTPS, saved launch profiles, and a clean terminal interface.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/C0C11HGDJV)

---

## ✨ Features

- 🎛️ **All-in-one menu** — one script, one interactive menu for every action
- 🖥️ **Multi-OS support** — Fedora/RHEL, Arch Linux, Ubuntu/Debian, macOS (auto-detected)
- 🐍 **Python version selection** — Choose between 3.12, 3.13, or 3.14 at install time
- ⚡ **Automatic CUDA detection** — PyTorch installed with the right backend for your hardware
- 🔀 **Python switcher** — Switch the venv Python version without reinstalling ComfyUI
- 🔐 **HTTPS launch** — Optional self-signed certificate, generated automatically
- 🗂️ **Saved launch profiles** — Save addresses (e.g. a Tailscale IP) once, relaunch in one keystroke
- 📊 **System info dashboard** — Full diagnostic display in a clean terminal UI

---

## 🚀 Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/Black0S/Comfy-Launcher-MultiOS
cd Comfy-Launcher-MultiOS
```

### 2. Make the script executable

```bash
chmod +x comfy.sh
```

### 3. Run it

```bash
./comfy.sh
```

That's it — everything happens through the interactive menu:

```
  ╔══════════════════════════════════════════════════╗
  ║          Comfy-Launcher  —  comfy.sh             ║
  ╚══════════════════════════════════════════════════╝

    1) 📦  Install / Reinstall ComfyUI
    2) 🚀  Launch ComfyUI  (HTTP / HTTPS / custom address)
    3) 🔄  Update ComfyUI
    4) 🔥  Update PyTorch
    5) 🐍  Switch Python version
    6) 📊  System info
    0) 🚪  Quit
```

---

## 📦 Installing (menu → 1)

Your **operating system is auto-detected** (Fedora/RHEL, Arch, Ubuntu/Debian, macOS). You will then be prompted to select your **Python version** (3.12 / 3.13 / 3.14).

> If auto-detection fails on an unusual distro, the installer falls back to a manual OS menu.

The installer will:
- Check and install `git` if missing
- Check and install the selected Python version if missing
- Clone ComfyUI and ComfyUI-Manager into `./comfyui`
- Create a virtual environment (`comfyui/.venv`)
- Install PyTorch with the right backend (CUDA on Linux, MPS nightly on macOS)
- Install all ComfyUI dependencies

> **Older CUDA driver?** PyTorch ships from the `cu130` (CUDA 13.0) wheel channel by default. If your driver is too old, override it before launching:
> ```bash
> TORCH_CUDA_CHANNEL=cu128 ./comfy.sh
> ```
> This applies to Install, Switch Python, and Update PyTorch.

---

## 🚀 Launching (menu → 2)

Choose how to serve ComfyUI:

| Mode | Result |
|---|---|
| **Local** | `http://127.0.0.1:8188` (default) |
| **Custom address** | Choose IP + port over HTTP (e.g. `0.0.0.0:8080` to expose on your LAN) |
| **Local HTTPS** | `https://127.0.0.1:8188` with an auto-generated self-signed certificate |
| **Custom HTTPS** | Choose IP + port over HTTPS (self-signed) |

You can also add **extra launch flags** (e.g. `--lowvram`, `--use-split-cross-attention`) when configuring a launch.

The self-signed certificate is created once with `openssl` into `./certs/` (git-ignored). Your browser will show a one-time warning you can accept.

### Saved launch profiles

No more retyping addresses. When you create a launch configuration, you can **save it as a named profile** (e.g. `tailscale`, `lan`, `local`). On the next launch the menu lists your profiles — just pick a number to start instantly:

```
  Saved profiles (pick a number to launch)
    1) tailscale      →  https://100.64.1.5:8188
    2) lan            →  http://<this-machine-IP>:8080

  n) New launch configuration
  e) Edit / delete a saved profile
  0) Back to main menu
```

- **Select** — type the profile number to launch with no further questions.
- **Create** — choose `n`, configure address/HTTPS/extra flags, and optionally give it a name to save.
- **Manage** — choose `e` to edit (address, port, HTTPS, flags) or delete a profile.

Each profile stores the listen address, port, HTTPS on/off, and any extra flags. Profiles live in `profiles.conf` (git-ignored, since it may contain private addresses like a Tailscale IP).

> **Tailscale tip:** a profile pointing at your Tailscale IP lets you reach ComfyUI from any device on your tailnet. The self-signed cert will still trigger a browser warning (the cert is issued for `localhost`); for a trusted certificate, consider `tailscale cert` / `tailscale serve` instead.

> ⚠️ **Security:** ComfyUI has **no authentication**. Listening on anything other than `127.0.0.1` exposes the full UI — and code execution via custom nodes — to your network. Only do this on a trusted network, or behind an authenticated reverse proxy. `comfy.sh` warns you when the listen address is not local.

---

## 🐍 Python Version Guide

| Version | Status | Notes |
|---|---|---|
| **3.12** | ⚠️ Older | Maximum compatibility with custom nodes |
| **3.13** | ✅ Recommended | Compatible with the vast majority of custom nodes |
| **3.14** | 🧪 Experimental | Some custom nodes may not work |

### Switching Python version (menu → 5)

Switch the Python version used by ComfyUI without reinstalling everything from scratch. The script will:
- Display the **currently active Python version** (highlighted)
- Let you choose a new version, installing it if missing
- Delete the old virtual environment and recreate a clean one
- Reinstall PyTorch and all ComfyUI dependencies automatically

---

## 🏗️ Arch Linux — Note on Python installation

Arch Linux only packages a single version of Python in its official repos. To support multiple specific versions (3.12, 3.13, 3.14), the installer uses **pyenv**, installed via your AUR helper.

**Requirements:**
- `yay` or `paru` must be installed before running `comfy.sh` on Arch

The installer will:
1. Install all required build dependencies via `pacman`
2. Install `pyenv` via your AUR helper
3. Automatically configure pyenv in your `.bashrc` or `.zshrc`
4. Resolve and install the latest patch version of your chosen Python
5. Create the venv using that exact Python binary

---

## 🔄 Updating

- **Update ComfyUI (menu → 3)** — Pulls the latest commits from the ComfyUI repository and updates all venv dependencies. *(ComfyUI-Manager updates itself from within the ComfyUI interface.)*
- **Update PyTorch (menu → 4)** — Reinstalls the latest version of PyTorch in the venv, for your OS and hardware.

---

## 📊 System Info (menu → 6)

Displays a full diagnostic dashboard in the terminal:

- 🖥️ **System** — OS, kernel, CPU, RAM
- ⚡ **GPU / CUDA** — GPU name, VRAM, driver version, CUDA toolkit (or MPS on macOS)
- 🐍 **Python** — All versions installed on the system (including pyenv), with the ComfyUI venv version highlighted
- 🔥 **PyTorch** — Version, CUDA/MPS availability, GPU seen by PyTorch
- 🎨 **ComfyUI** — Branch, commit, date, ComfyUI-Manager status

---

## 📋 Requirements

### Linux
- `bash` 4.0+
- A package manager: `dnf`, `pacman`, or `apt`
- **Arch only:** `yay` or `paru` (AUR helper) must be installed
- NVIDIA GPU with drivers installed *(recommended)*
- CUDA runtime *(optional — PyTorch works without `nvcc`)*

### macOS
- `bash` 3.2+ (the system default works; the script is tested on it)
- [Homebrew](https://brew.sh)
- `openssl` (preinstalled) for HTTPS
- Apple Silicon recommended for MPS acceleration

---

## 📂 Directory Structure

After installation, the following structure exists next to the script:

```
.
├── comfy.sh                  ← the only script (interactive menu)
├── certs/                    ← self-signed TLS certificate (generated, git-ignored)
├── profiles.conf             ← saved launch profiles (generated, git-ignored)
└── comfyui/                  ← ComfyUI repository (cloned by the installer)
    ├── .venv/                ← Python virtual environment
    ├── main.py
    ├── requirements.txt
    └── custom_nodes/
        └── comfyui-manager/  ← ComfyUI-Manager
```

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

---

## 📄 License

This project is released under the MIT License.

---

> **ComfyUI** is developed by [@comfyanonymous](https://github.com/comfyanonymous/ComfyUI) — this project is an independent launcher and is not officially affiliated with ComfyUI.
