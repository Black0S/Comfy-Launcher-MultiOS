# Comfy-Launcher-MultiOS

A set of shell scripts to install, launch, update, and manage [ComfyUI](https://github.com/comfyanonymous/ComfyUI) on Linux and macOS — with multi-OS support, Python version selection, and a clean terminal interface.

---

## ✨ Features

- 🖥️ **Multi-OS support** — Fedora/RHEL, Arch Linux, Ubuntu/Debian, macOS
- 🐍 **Python version selection** — Choose between 3.12, 3.13, or 3.14 at install time
- ⚡ **Automatic CUDA detection** — PyTorch installed with the right backend for your hardware
- 🔀 **Python switcher** — Switch the venv Python version without reinstalling ComfyUI
- 📊 **System info dashboard** — Full diagnostic display in a clean terminal UI
- 🚀 **Smart launcher** — Auto-detects GPU and applies the right flags

---

## 📁 Scripts Overview

| Script | Description |
|---|---|
| `install.sh` | Full installation: OS deps, Python, ComfyUI, ComfyUI-Manager, venv, PyTorch |
| `launch.sh` | Launch ComfyUI using the installed venv |
| `update-comfyui.sh` | Pull latest ComfyUI commits and update venv dependencies |
| `update-torch.sh` | Update PyTorch to the latest version in the venv |
| `switchpy.sh` | Switch the venv to a different Python version (3.12 / 3.13 / 3.14) |
| `info.sh` | Display a full system diagnostic: OS, CPU, RAM, GPU, CUDA, Python, PyTorch, ComfyUI |

---

## 🚀 Quick Start

### 1. Clone this repository

```bash
git clone https://github.com/your-username/Comfy-Launcher-MultiOS.git
cd Comfy-Launcher-MultiOS
```

### 2. Make scripts executable

```bash
chmod +x *.sh
```

### 3. Run the installer

```bash
./install.sh
```

You will be prompted to select:
- Your **operating system**
- Your **Python version** (3.12 / 3.13 / 3.14)

The installer will then:
- Check and install `git` if missing
- Check and install the selected Python version if missing
- Clone ComfyUI and ComfyUI-Manager
- Create a virtual environment
- Install PyTorch with the right backend (CUDA on Linux, MPS nightly on macOS)
- Install all ComfyUI dependencies

### 4. Launch ComfyUI

```bash
./launch.sh
```

Open your browser at: **http://127.0.0.1:8188**

---

## 🐍 Python Version Guide

| Version | Status | Notes |
|---|---|---|
| **3.12** | ⚠️ Older | Maximum compatibility with custom nodes |
| **3.13** | ✅ Recommended | Compatible with the vast majority of custom nodes |
| **3.14** | 🧪 Experimental | Some custom nodes may not work |

---

## 🏗️ Arch Linux — Note on Python installation

Arch Linux only packages a single version of Python in its official repos. To support multiple specific versions (3.12, 3.13, 3.14), the installer uses **pyenv**, installed via your AUR helper.

**Requirements:**
- `yay` or `paru` must be installed before running `install.sh` on Arch

The installer will:
1. Install all required build dependencies via `pacman`
2. Install `pyenv` via your AUR helper
3. Automatically configure pyenv in your `.bashrc` or `.zshrc`
4. Resolve and install the latest patch version of your chosen Python
5. Create the venv using that exact Python binary

---

## 🔀 Switching Python Version

To switch the Python version used by ComfyUI without reinstalling everything from scratch:

```bash
./switchpy.sh
```

The script will:
- Display the **currently active Python version** (highlighted in yellow)
- Let you choose a new version
- Check and install it if not present on your system
- Delete the old virtual environment
- Recreate a clean one with the new Python version
- Reinstall PyTorch and all ComfyUI dependencies automatically

---

## 🔄 Updating

### Update ComfyUI

```bash
./update-comfyui.sh
```

Pulls the latest commits from the ComfyUI repository and updates all venv dependencies.

> ComfyUI-Manager updates itself from within the ComfyUI interface.

### Update PyTorch

```bash
./update-torch.sh
```

Reinstalls the latest version of PyTorch in the venv, for your OS and hardware.

---

## 📊 System Info

```bash
./info.sh
```

Displays a full diagnostic dashboard in the terminal:

- 🖥️ **System** — OS, kernel, CPU, RAM
- ⚡ **GPU / CUDA** — GPU name, VRAM, driver version, CUDA toolkit
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
- `bash` 4.0+ (`brew install bash` if needed)
- [Homebrew](https://brew.sh)
- Apple Silicon recommended for MPS acceleration

---

## 📂 Directory Structure

After installation, the following structure will be created next to the scripts:

```
.
├── install.sh
├── launch.sh
├── update-comfyui.sh
├── update-torch.sh
├── switchpy.sh
├── info.sh
└── comfyui/                  ← ComfyUI repository
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

This project is released under the [MIT License](LICENSE).

---

> **ComfyUI** is developed by [@comfyanonymous](https://github.com/comfyanonymous/ComfyUI) — this project is an independent launcher and is not officially affiliated with ComfyUI.
