# mac-bootstrap

Bootstrap a macOS machine with Homebrew packages, dotfiles, and macOS defaults.

This repository is intentionally **script-first**: the main entrypoint is a Zsh bootstrap script that calls an interactive installer which runs a sequence of modules.

## Quick start

### 1) Clone + init submodules

This repo uses git submodules for dotfiles/config:

```sh
git clone <repo-url>
cd mac-bootstrap
git submodule update --init --recursive
```

> Note: `.gitmodules` currently points to SSH URLs (`git@github.com:...`). Ensure your GitHub SSH key is set up.

### 2) Run the bootstrap

```sh
./mac-bootstrap.sh
```

What to expect:
- You’ll be prompted to press **Enter** to continue (or `q` to quit).
- Each major section then asks **`y`** to run or **`n`** to skip.
- Some steps require sudo/admin privileges.
- Xcode Command Line Tools may trigger a GUI installer prompt.

## What it does (high level)

Execution flow:

1. **`mac-bootstrap.sh`**
   - Runs preflight checks (Xcode Command Line Tools, Homebrew, required CLI tools).
   - Installs/configures Homebrew shellenv (`/opt/homebrew` on Apple Silicon, `/usr/local` on Intel).
   - Runs `./scripts/install.sh`.

2. **`scripts/install.sh`** (interactive orchestrator)
   - Sources and runs these modules in order (each behind a `y/n` prompt):
     - Mac App Store installs (`scripts/macstore-apps.sh`)
     - Homebrew taps/formulas/casks (`scripts/brew.sh`)
     - Python packages (`scripts/python.sh`)
     - Node global packages (`scripts/node.sh`)
     - LuaRocks packages (`scripts/lua.sh`)
     - Go tools (`scripts/golang.sh`)
    - Claude Code plugins (`scripts/claude-plugins.sh`)
     - Stow dotfiles (`scripts/stow.sh`)
     - macOS defaults (`scripts/osx-configs.sh`)
     - Post-install steps (`scripts/post-install.sh`)
     - Optional restart

## Customization points

### Homebrew taps / formulas / casks / services

Edit **`scripts/brew.sh`**:
- `taps=(...)`
- `formulas=(...)` (brew formulas)
- `casks=(...)`
- `services=(...)` (started via `brew services`)

Important behavior:
- `install_packages()` installs what’s listed.
- `brew_cleanup()` may **uninstall** installed formulas/casks that are *not* listed (unless needed as a dependency). If you rely on something, add it to the arrays.

### Mac App Store apps (mas)

Edit **`scripts/macstore-apps.sh`** and populate:

```zsh
mas_apps=(
  # 123456789  # Example app id
)
```

You must be signed into the Mac App Store for `mas install` to work.

### Dotfiles via GNU stow (submodule)

Dotfiles live under **`stow/`** (git submodule). The installer:
- enumerates top-level directories under `stow/`
- runs `stow --target="$HOME" <dir>` for each

### macOS defaults

Edit **`scripts/osx-configs.sh`**.

This module uses `defaults write` to set Finder/Dock/system behaviors.

Wallpaper is configured from the repository location (derived from `scripts/utils.sh` → `MB_REPO_ROOT`). If the wallpaper file doesn’t exist, the wallpaper defaults are skipped (and the rest of the defaults still apply).

### Post-install actions

See **`scripts/post-install.sh`**. It includes (among other items):
- adding Nushell to `/etc/shells`
- initializing Rust (via `rustup-init` if `rustc` isn’t found)
- initializing a Podman machine if needed
- installing Sketchybar extras (SbarLua via a temp clone + `make install`)
- running Homebrew cleanup and starting configured services
- applying Rectangle defaults
- installing Claude Code plugins (`mempalace`, `caveman`)
- starting Yabai as a service

## Running a single module

All modules are designed to be **sourced** by `scripts/install.sh`. If you want to run one step manually, run commands from the repository root.

Examples:

- Homebrew only:
  ```sh
  zsh -lc 'source scripts/utils.sh; source scripts/brew.sh; install_packages'
  ```

- Stow dotfiles only:
  ```sh
  zsh -lc 'source scripts/utils.sh; source scripts/stow.sh; stow_dotfiles'
  ```

- macOS defaults only:
  ```sh
  zsh -lc 'source scripts/utils.sh; source scripts/osx-configs.sh; setup_osx'
  ```

- Claude Code plugins only:
  ```sh
  zsh -lc 'source scripts/utils.sh; source scripts/claude-plugins.sh; install_claude_plugins'
  ```

## Safety warnings (read before running)

- **Dotfiles stow is destructive by design**: `stow_dotfiles()` removes existing config files and may wipe/recreate `$HOME/.config/...` directories before stowing.
- **Homebrew cleanup can uninstall software**: `brew_cleanup()` removes formulas/casks not present in `scripts/brew.sh` lists.
- **macOS defaults modify system settings**: `setup_osx()` writes system defaults (Dock/Finder/etc). A restart is recommended/expected by the installer.

## Troubleshooting

- **Submodules won’t clone**: ensure you have GitHub SSH access, or update `.gitmodules` to HTTPS URLs.
- **Homebrew not found**: preflight configures Homebrew shellenv for both `/opt/homebrew` (Apple Silicon) and `/usr/local` (Intel). If `brew` still isn’t found, check your shell profile files and PATH.
- **`mas install` fails**: sign into the Mac App Store and re-run that section.
- **Yabai/Sketchybar/Borders don’t start**: macOS may require Accessibility / Screen Recording permissions for window managers and status bar tools.

## License

See `LICENSE`.
