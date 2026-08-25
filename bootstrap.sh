#!/usr/bin/env bash
# One-command workstation setup. Idempotent; safe to re-run.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

command -v brew >/dev/null || /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew bundle --file="$REPO_DIR/Brewfile"

gh auth status >/dev/null 2>&1 || gh auth login

# Dotfiles come from the stow/ submodule (focalor-umbra/.DotFiles).
# stow.sh is zsh-only (uses ${(%):-%x}), so invoke it under zsh.
zsh -lc "cd '$REPO_DIR' && source scripts/utils.sh && source scripts/stow.sh && stow_dotfiles"

# Clone all org repos that are not present yet
mkdir -p "$HOME/Projects" && cd "$HOME/Projects"
gh repo list UmbraDigitalTechnologies --limit 100 --json name -q '.[].name' | while read -r r; do
  [ -d "$r" ] || gh repo clone "UmbraDigitalTechnologies/$r" "$r"
done

# Tools not in brew (rtk and obsidian-cli are brew formulas — Brewfile covers them)
command -v mempalace >/dev/null || pipx install mempalace

mempalace init || true

echo "bootstrap complete"
