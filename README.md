# ComfyUI Mac Silicon Launcher

Architecture proposée
- `comfyui/` : répertoire cible pour le `git clone` de ComfyUI
- `install.sh` : script d'installation et de vérification des dépendances (macOS Silicon)
- `launch.sh` : script de lancement qui exécute `main.py` via `python3.13`

Utilisation rapide

1. Rendre les scripts exécutables :

```bash
chmod +x install.sh launch.sh update-comfyui.sh
```

2. Exécuter l'installation (clonage + dépendances dans un `venv` local) :

```bash
./install.sh
```

3. Lancer ComfyUI (utilise le `venv` local) :

```bash
./launch.sh
```

4. Mettre à jour le clone ComfyUI :

```bash
./update-comfyui.sh
```

Notes techniques
- `install.sh` :
  - vérifie que Homebrew est installé (sinon quitte et demande installation manuelle)
  - installe `python@3.13` via `brew` si `python3.13` est absent
  - clone (ou met à jour) `https://github.com/comfyanonymous/ComfyUI.git` dans `./comfyui`
  - crée ou réutilise un virtualenv local `./comfyui/.venv` (via `python3.13 -m venv`)
  - met à jour `pip` dans le `venv` puis installe `torch`/`torchvision` nightly (CPU) dans le `venv` :
    `./comfyui/.venv/bin/python -m pip install --pre torch torchvision --index-url https://download.pytorch.org/whl/nightly/cpu`
  - installe ensuite les dépendances du projet dans le `venv` :
    `./comfyui/.venv/bin/python -m pip install -r comfyui/requirements.txt`

- `launch.sh` :
  - utilise `./comfyui/.venv/bin/python` pour exécuter `comfyui/main.py` (transmet les arguments)

- `update-comfyui.sh` :
  - récupère les dernières modifications du dépôt `comfyui` (fetch + pull --rebase)
  - met à jour les submodules si présents
  - réinstalle les dépendances dans le `venv` local s'il existe

Portabilité
- Le contenu du dossier `comfyui/` (y compris `.venv`) peut être déplacé sur un autre Mac similaire. Sur le nouvel hôte, assurez-vous que `python3.13` est disponible si vous recréez le `venv`. Pour une portabilité maximale, vous pouvez recréer le `venv` sur la nouvelle machine en lançant `./install.sh` depuis le dossier du launcher.


Si vous souhaitez que j'ajoute :
- un `pyenv`-based flow au lieu de `brew`
- un contrôle plus interactif (installer Homebrew automatiquement)
- rendre les scripts IDÉPENDANTS du nom de l'interpréteur (virtualenv)
