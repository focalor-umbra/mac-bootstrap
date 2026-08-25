# ============================================================================
# HOMEBREW TAPS (Third-party repositories)
# ============================================================================
taps=(
  asmvik/formulae       # yabai
  derailed/k9s          # k9s
  felixkratz/formulae   # borders, sketchybar
  hashicorp/tap         # terraform
  oven-sh/bun           # bun
  rsteube/homebrew-tap  # carapace
)

# Taps that must never be untapped by cleanup (Homebrew-managed / built-in).
protected_taps=(
  homebrew/core
  homebrew/cask
  homebrew/bundle
  homebrew/services
)

# ============================================================================
# FORMULAS (CLI tools, libraries, command-line applications)
# ===========================================================================
required_formulas=(
  gh
  mas
  stow
)

formulas=(
  age
  ansible
  ansible-lint
  awscli
  azure-cli
  FelixKratz/formulae/borders
  oven-sh/bun/bun
  rsteube/homebrew-tap/carapace
  cloudflared
  cmake
  erlang
  eza
  fzf
  git
  git-remote-codecommit
  gleam
  go
  gradle
  gradle-completion
  helm
  istioctl
  derailed/k9s/k9s
  kubernetes-cli
  lazygit
  lima
  lua
  luarocks
  markdownlint-cli2
  maven
  micronaut
  minikube
  mkcert
  neovim
  node
  nss
  nushell
  opencode
  openjdk
  openjdk@17
  openssl
  opentofu
  pillow
  pipx
  podman
  podman-compose
  posting
  prettier
  python3
  qemu
  ripgrep
  rtk
  rustup
  FelixKratz/formulae/sketchybar
  slides
  sops
  starship
  swagger-codegen
  switchaudio-osx
  hashicorp/tap/terraform
  virtualenv
  wget
  asmvik/formulae/yabai
  yazi
  zig
  zoxide
)

# ============================================================================
# CASKS (GUI applications)
# ============================================================================
required_casks=(
)

casks=(
  bitwarden
  copilot-cli
  dotnet-sdk
  font-fira-code-nerd-font
  font-sketchybar-app-font
  localsend
  obs
  obsidian
  raycast
  rectangle
  sf-symbols
  wezterm
)

# ============================================================================
# SERVICES (Background services managed by brew services)
# ============================================================================
services=(
  borders
  sketchybar
)

# ============================================================================
# DERIVED LISTS (Used by cleanup functions)
# ============================================================================
all_formulas=("${required_formulas[@]}" "${formulas[@]}")
all_casks=("${required_casks[@]}" "${casks[@]}")

# ============================================================================
# FUNCTIONS
# ============================================================================
# `brew tap` prints taps lowercased and with the "homebrew-" repo prefix stripped
# (e.g. "rsteube/homebrew-tap" -> "rsteube/tap"). Normalize before comparing.
normalize_tap() {
  local tap="${(L)1}"
  [[ -n "$tap" ]] || return 0
  local user="${tap%%/*}"
  local repo="${tap#*/}"
  printf '%s' "${user}/${repo#homebrew-}"
}

tap_is_installed() {
  local tap
  tap="$(normalize_tap "$1")"
  brew tap | grep -qx "$tap"
}

# Echo the installed formulas/casks provided by a tap (one per line).
tap_installed_packages() {
  local tap
  tap="$(normalize_tap "$1")"
  local dir="$(brew --repository)/Library/Taps/${tap%%/*}/homebrew-${tap##*/}"
  [[ -d "$dir" ]] || return 0

  setopt local_options null_glob

  local f name
  for f in "$dir"/Formula/**/*.rb "$dir"/HomebrewFormula/*.rb "$dir"/*.rb; do
    [[ -f "$f" ]] || continue
    name="${${f:t}:r}"
    brew list --formula --versions "$name" >/dev/null 2>&1 && print -r -- "$name"
  done
  for f in "$dir"/Casks/**/*.rb; do
    [[ -f "$f" ]] || continue
    name="${${f:t}:r}"
    brew list --cask --versions "$name" >/dev/null 2>&1 && print -r -- "$name"
  done

  return 0
}

# Echo the tap a formula was installed from, per its install receipt (empty if unknown).
installed_formula_tap() {
  local name="${1##*/}"
  local receipt
  for receipt in "$(brew --cellar)/${name}"/*/INSTALL_RECEIPT.json(N); do
    grep -o '"tap"[[:space:]]*:[[:space:]]*"[^"]*"' "$receipt" |
      head -1 |
      sed 's/.*:[[:space:]]*"\(.*\)"$/\1/'
    return 0
  done
  return 0
}

check_tap_trusted() {
  local tap="$1"
  brew tap-info "$tap" 2>/dev/null | grep -q "^Trusted$"
  return $?
}

confirm_tap_trust() {
  local tap="$1"
  
  if ! tap_is_installed "$tap"; then
    return 0 
  fi
  
  if check_tap_trusted "$tap"; then
    return 0 
  fi
  
  warn "Tap '$tap' is not marked as trusted"
  warn "Homebrew refuses to load formulas/casks from untrusted third-party taps"
  info "Trusting a tap lets Homebrew run code from that repository"
  info "Source: https://github.com/${tap}"
  
  if wait_input; then
    info "Trusting tap < $tap >"
    brew trust --tap "$tap"
    return 0
  else
    warn "Leaving $tap untrusted; its packages cannot be installed"
    return 1
  fi
}

apply_brew_taps() {
  local tap_list=("$@")
  for tap in "${tap_list[@]}"; do
    if tap_is_installed "$tap"; then
      warn "Tap $tap is already applied"
      confirm_tap_trust "$tap"
    else
      info "Tapping < $tap >"
      brew tap "$tap"
      confirm_tap_trust "$tap"
    fi
  done
}

install_brew_formulas() {
  local formula_list=("$@")
  for formula in "${formula_list[@]}"; do
    local formula_name="${formula##*/}"

    # Fully-qualified entries ("user/tap/name") pin the tap the formula must come from.
    local desired_tap=""
    if [[ "$formula" == */*/* ]]; then
      desired_tap="$(normalize_tap "${formula%/*}")"
    fi

    if brew list --formula --versions "$formula_name" >/dev/null 2>&1; then
      local current_tap
      current_tap="$(normalize_tap "$(installed_formula_tap "$formula_name")")"

      if [[ -n "$desired_tap" && -n "$current_tap" && "$current_tap" != "$desired_tap" ]]; then
        warn "Formula $formula_name is installed from $current_tap, desired state is $desired_tap"
        info "Reinstalling < $formula > from $desired_tap"
        brew uninstall --ignore-dependencies "$formula_name" 2>/dev/null || true
        brew install "$formula"
      else
        warn "Formula $formula_name is already installed"
      fi
    else
      info "Installing formula < $formula >"
      brew install "$formula"
    fi
  done
}

install_brew_casks() {
  local cask_list=("$@")
  for cask in "${cask_list[@]}"; do
    if brew list --cask --versions "$cask" >/dev/null 2>&1; then
      warn "Cask $cask is already installed"
    else
      info "Installing cask < $cask >"
      brew install --cask "$cask"
    fi
  done
}

start_services() {
  info "Starting services..."
  cd "$HOME" || return 1
  for service in "${services[@]}"; do
    if brew services list | grep -q "^$service.*started"; then
      brew services restart "$service"
    else
      brew services start "$service"
    fi
  done
}

install_packages() {
  info "Applying Homebrew taps..."
  apply_brew_taps "${taps[@]}"

  info "Installing required formulas (preflight)..."
  install_brew_formulas "${required_formulas[@]}"

  if (( ${#required_casks[@]} )); then
    info "Installing required casks (preflight)..."
    install_brew_casks "${required_casks[@]}"
  fi

  info "Installing main formulas..."
  install_brew_formulas "${formulas[@]}"

  info "Installing main casks..."
  install_brew_casks "${casks[@]}"

  info "Cleaning up Homebrew..."
  brew cleanup
}

# Untap third-party taps that are not in the desired `taps` list. A tap that still
# provides installed packages is kept (and reported) instead of being untapped.
cleanup_brew_taps() {
  info "Cleaning up brew taps..."

  local desired_taps=()
  local tap
  for tap in "${taps[@]}" "${protected_taps[@]}"; do
    desired_taps+=("$(normalize_tap "$tap")")
  done

  local installed_taps=($(brew tap))
  for tap in "${installed_taps[@]}"; do
    local name
    name="$(normalize_tap "$tap")"

    if [[ " ${desired_taps[@]} " =~ " ${name} " ]]; then
      # Desired tap: re-check its trust status while we are here.
      confirm_tap_trust "$name" || true
      continue
    fi

    local used
    used="$(tap_installed_packages "$name")"
    if [[ -n "$used" ]]; then
      warn "Tap $name is not in the desired list but still provides installed packages:"
      local pkg
      while IFS= read -r pkg; do
        info "  - $pkg"
      done <<< "$used"
      warn "Keeping tap $name; remove those packages first to untap it"
      continue
    fi

    info "Untapping < $name >"
    brew untap "$name" 2>/dev/null || warn "Failed to untap $name"
  done
}

brew_cleanup() {
  info "Cleaning up brew..."
  cd "$HOME" || return 1
  installed_formulas=($(brew leaves))
  installed_casks=($(brew list --cask))

  local formula_names=()
  for formula in "${all_formulas[@]}"; do
    local name="${formula##*/}"
    formula_names+=("$name")
  done

  for formula in "${installed_formulas[@]}"; do
    local name="${formula##*/}"
    if [[ ! " ${formula_names[@]} " =~ " ${name} " ]]; then
      info "Uninstalling formula < $formula >"
      brew uninstall "$formula" 2>/dev/null || true
    fi
  done

  for cask in "${installed_casks[@]}"; do
    if [[ ! " ${all_casks[@]} " =~ " ${cask} " ]]; then
      info "Uninstalling cask < $cask >"
      brew uninstall --cask "$cask" 2>/dev/null || true
    fi
  done

  info "Removing unused dependencies..."
  brew autoremove 2>/dev/null || true

  cleanup_brew_taps
}
