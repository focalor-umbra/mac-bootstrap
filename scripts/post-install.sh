#!/usr/bin/env zsh

post_install() {

  install_sbarlua_extras() {
    git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua \
      && cd /tmp/SbarLua/ \
      && make install \
      && rm -rf /tmp/SbarLua/
  }

  info "Post-install steps (each is optional)"

  if mb_have_cmd nu; then
    mb_run_step "Add Nushell to /etc/shells" zsh -lc 'grep -Fq "$(command -v nu)" /etc/shells || echo "$(command -v nu)" | sudo tee -a /etc/shells >/dev/null'
  else
    warn "nu not found; skipping /etc/shells update"
  fi

  if mb_have_cmd rustc; then
    success "Rust: already installed"
  elif mb_have_cmd rustup-init; then
    mb_run_step "Install Rust toolchain (rustup-init)" rustup-init
  else
    warn "rustup-init not found; skipping Rust install"
  fi

  if mb_have_cmd podman; then
    if podman machine ls 2>/dev/null | grep -q 'podman-machine-default'; then
      success "Podman machine: already exists"
    else
      mb_run_step "Initialize Podman machine" podman machine init
    fi
  else
    warn "podman not found; skipping Podman machine init"
  fi

  if mb_have_cmd git && mb_have_cmd make; then
    mb_run_step "Install Sketchybar extras (SbarLua)" install_sbarlua_extras
  else
    warn "git/make not found; skipping SbarLua extras"
  fi

  if mb_have_fn brew_cleanup; then
    mb_run_step "Homebrew cleanup (uninstalls formulas/casks not in desired state)" brew_cleanup
  else
    warn "brew_cleanup() not available; skipping brew cleanup"
  fi

  start_yabai() {
    cd "$HOME" || return 1
    yabai --start-service
  }

  if mb_have_cmd yabai; then
    mb_run_step "Start Yabai service" start_yabai
  else
    warn "yabai not found; skipping Yabai start"
  fi

  if mb_have_fn start_services; then
    mb_run_step "Start/restart brew services" start_services
  else
    warn "start_services() not available; skipping brew services"
  fi

  if mb_have_fn config_rectangle; then
    mb_run_step "Configure Rectangle defaults" config_rectangle
  else
    warn "config_rectangle() not available; skipping Rectangle config"
  fi

  if mb_have_fn install_claude_plugins; then
    mb_run_step "Install Claude Code plugins (mempalace, caveman)" install_claude_plugins
  else
    warn "install_claude_plugins() not available; skipping Claude Code plugins"
  fi



  success "Finished post install"
}
