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
     - Stow dotfiles (`scripts/stow.sh`)
     - macOS defaults (`scripts/osx-configs.sh`)
     - Post-install steps, including Codex plugins and RTK (`scripts/post-install.sh`)
     - Optional restart

## Customization points

### Homebrew taps / formulas / casks / services

Edit **`scripts/brew.sh`**:
- `taps=(...)`
- `formulas=(...)` (brew formulas)
- `casks=(...)`
- `services=(...)` (started via `brew services`)

`Brewfile` is a separate manifest for `brew bundle`; the interactive installer uses
`scripts/brew.sh`. Both include the Codex CLI cask (`codex`) and `jq`, which the
plugin installer uses to read Codex's JSON output.

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
- installing Codex plugins (`mempalace`, `caveman`)
- configuring RTK for Codex (`rtk init -g --codex`)
- installing shared Codex working agreements and resolving this machine's Obsidian vault
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

- Codex plugins only:
  ```sh
  zsh -lc 'source scripts/utils.sh; source scripts/codex-plugins.sh; install_codex_plugins'
  ```

- RTK integration for Codex only:
  ```sh
  zsh -lc 'source scripts/utils.sh; source scripts/rtk.sh; configure_codex_rtk'
  ```

## Start using Codex

To set up only Codex on an existing machine, without running the full bootstrap:

```sh
brew install --cask codex
brew install jq rtk
zsh -lc 'source scripts/utils.sh; source scripts/codex-plugins.sh; install_codex_plugins'
zsh -lc 'source scripts/utils.sh; source scripts/rtk.sh; configure_codex_rtk'
zsh scripts/codex-config.sh
codex
```

Sign in when prompted on the first launch, or run `codex login` beforehand.
The plugin step registers `MemPalace/mempalace` and `JuliusBrussee/caveman`, then
installs `mempalace@mempalace` and `caveman@caveman` with `codex plugin add`.
It skips already installed plugins, preserving their enabled/disabled state;
use `/plugins` in Codex to review them. Start a new session after installing plugins.
See the official [Codex CLI guide](https://learn.chatgpt.com/docs/codex/cli) and
[plugin guide](https://learn.chatgpt.com/docs/plugins).

RTK is already included in both Homebrew package lists. Its
[Codex integration](https://github.com/rtk-ai/rtk#supported-ai-tools) uses
`rtk init -g --codex` to write `~/.codex/RTK.md` and add a reference in
`~/.codex/AGENTS.md`, preserving existing instructions. It guides Codex to call
RTK explicitly; it is not a marketplace plugin or automatic shell rewrite hook.
Do not omit `--codex`, because RTK's default integration targets Claude Code.

Use a current Codex CLI with `codex plugin add` support. If the setup reports an
older CLI, run `brew upgrade --cask codex` and retry. This bootstrap does not copy
Claude settings or credentials into Codex, and does not overwrite `config.toml`.
Existing Claude installations and data are left alone by the Codex setup step;
the optional Homebrew cleanup can remove casks absent from the desired package list.

## Replicate Codex Across Machines

Shared behavior lives in [`config/codex/AGENTS.md`](config/codex/AGENTS.md). Both
bootstrap entrypoints install it into a marked section of the global Codex
`AGENTS.md`. Existing personal instructions and RTK references are preserved;
changed files get timestamped backups and unchanged reruns write nothing.
Codex loads global instructions in each new task/session, alongside repository
instructions. See [instruction discovery](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

The agreements require Codex to consult the relevant Obsidian project notes before
changes, follow the vault's documentation standards, verify claims against code,
and update affected documentation before completing the task. Project notes are
located through the vault index or a targeted search by repository name or remote.
Private project mappings stay in the vault or machine-local configuration.

On each Mac:

1. Clone this repo and initialize its submodules.
2. Sign in to Obsidian Sync, sync the project documentation vault, and open it once
   in Obsidian so the local vault registry exists.
3. Run the bootstrap, or just the instruction setup:
   ```sh
   zsh scripts/codex-config.sh --dry-run
   zsh scripts/codex-config.sh
   ```
4. Sign in to Codex separately and start a new task. Ask it to identify the active
   working agreements, locate the project's vault notes, and summarize the relevant
   documentation before editing. Check its cited paths.

The setup detects a single registered vault and saves its path in
`~/.codex/obsidian-vault.json`. If there are multiple vaults, or the path changes,
select it with `zsh scripts/codex-config.sh --vault "/path/to/SecondBrain"`.
For the full bootstrap, set `MB_OBSIDIAN_VAULT` to that path. An existing `CODEX_HOME`
is respected. Missing/unsynced documentation, a nonempty global `AGENTS.override.md`,
or symlinked destination files are reported before instructions are changed.

Vault files are ordinary Markdown, so this workflow does not require an Obsidian
plugin or CLI. The vault stays in Obsidian Sync; only the reusable instructions
are versioned here. Authentication, model choices, permissions, sessions, caches,
and plugin state remain local. Shared instructions give consistent working rules;
they do not guarantee identical model output or transfer conversation history.

Instructions do not grant filesystem access. For CLI work that updates vault notes,
include the vault with `codex --add-dir "/path/to/SecondBrain"`; in the desktop app,
grant access to the affected vault files when requested. Keep existing sandbox
settings. If access is blocked, Codex must report the pending documentation update.

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
