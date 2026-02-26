# ComfyUI Mac Silicon Launcher

<div align="center">

![macOS](https://img.shields.io/badge/macOS-Apple_Silicon-black?style=for-the-badge&logo=apple&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.13-3776AB?style=for-the-badge&logo=python&logoColor=white)
![PyTorch](https://img.shields.io/badge/PyTorch-Nightly-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)
![ComfyUI](https://img.shields.io/badge/ComfyUI-Latest-4B8BBE?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**A streamlined launcher for running ComfyUI natively on Apple Silicon Macs.**  
Automated setup, local virtual environment, and nightly PyTorch — zero hassle.

</div>

---

## 📁 Project Structure

```
comfyui-mac-launcher/
├── comfyui/                    # ComfyUI clone target directory
├── install.sh                  # Dependency checker & full installer
├── launch.sh                   # ComfyUI launcher (uses local venv)
└── Update Scripts/
    ├── update-comfyui.sh       # Pull latest ComfyUI changes
    └── update-torch.sh         # Upgrade to latest nightly PyTorch
```

---

## 🚀 Quick Start

### 0. Clone or Download this Repo

```bash
git clone <this-repo-url>
cd <repo-folder>
```

### 1. Make Scripts Executable

```bash
chmod +x install.sh launch.sh "Update Scripts/update-comfyui.sh" "Update Scripts/update-torch.sh"
```

### 2. Run the Installer

Clones ComfyUI, creates a local virtual environment, and installs all dependencies:

```bash
./install.sh
```

### 3. Launch ComfyUI

```bash
./launch.sh
```

### 4. Update ComfyUI

```bash
./Update\ Scripts/update-comfyui.sh
```

### 5. Update PyTorch (Nightly)

```bash
./Update\ Scripts/update-torch.sh
```

---

## 🌐 Access & Shutdown

**Web Interface** — Once ComfyUI is running, open your browser at:

```
http://127.0.0.1:8188
```

**Startup Time** — First launch may take longer depending on your machine's specs and initialization time. Please be patient.

**Clean Shutdown** — To ensure ComfyUI is fully stopped:

1. Close the terminal running `launch.sh`
2. Open **Activity Monitor** (`Applications → Utilities → Activity Monitor`)
3. Search for any remaining `python` processes and terminate them if needed

---

## 🔧 Technical Details

### `install.sh`
- Verifies **Homebrew** is installed (exits with instructions if not)
- Installs `python@3.13` via Homebrew if not already present
- Clones or updates [ComfyUI](https://github.com/comfyanonymous/ComfyUI) into `./comfyui`
- Creates or reuses a local virtualenv at `./comfyui/.venv`
- Upgrades `pip` inside the venv, then installs **nightly PyTorch + torchvision** (CPU):
  ```bash
  ./comfyui/.venv/bin/python -m pip install --pre torch torchvision \
    --index-url https://download.pytorch.org/whl/nightly/cpu
  ```
- Installs ComfyUI's Python dependencies:
  ```bash
  ./comfyui/.venv/bin/python -m pip install -r comfyui/requirements.txt
  ```
- Clones or updates [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager) into `comfyui/custom_nodes/`

### `launch.sh`
- Uses `./comfyui/.venv/bin/python` to run `comfyui/main.py`
- Forwards any additional arguments passed to the script

### `Update Scripts/update-comfyui.sh`
- Fetches and rebases the latest ComfyUI commits (`fetch + pull --rebase`)
- Updates any git submodules if present
- Reinstalls project dependencies in the local venv

### `Update Scripts/update-torch.sh`
- Verifies the `comfyui/` directory and local venv exist
- Upgrades `pip` inside the venv
- Installs the latest **nightly build** of PyTorch and torchvision (CPU)

---

## 📦 Portability

The entire `comfyui/` folder (including `.venv`) can be moved to another Apple Silicon Mac.

> **Note:** Ensure `python3.13` is available on the target machine if you need to recreate the venv. For maximum portability, simply run `./install.sh` on the new machine — it will handle everything from scratch.

---

## ✅ Requirements

| Requirement | Notes |
|---|---|
| Apple Silicon Mac | M1 / M2 / M3 / M4 series |
| macOS 13 Ventura+ | Recommended |
| [Homebrew](https://brew.sh) | Must be installed manually before running `install.sh` |
| Internet Connection | Required during install & update steps |

---

## 📄 License

This project is released under the [MIT License](LICENSE).

---

<div align="center">

Made with ❤️ for the Apple Silicon community

</div>