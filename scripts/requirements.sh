#!/usr/bin/env zsh

# Preflight checks for mac-bootstrap.
# Intended to be sourced by mac-bootstrap.sh (uses logging + wait_input from scripts/utils.sh).

have_cmd() {
	mb_have_cmd "$1"
}

ensure_line_in_file() {
	local line="$1"
	local file="$2"
	touch "$file"
	if ! grep -Fqs "$line" "$file"; then
		{
			echo
			echo "$line"
		} >>"$file"
	fi
}

ensure_xcode_clt() {
	if xcode-select -p &>/dev/null; then
		success "Xcode Command Line Tools: installed"
		return 0
	fi

	warn "Xcode Command Line Tools: missing"
	info "Install now?"
	if wait_input; then
		xcode-select --install || true
		warn "Finish the Xcode CLT installer, then re-run ./mac-bootstrap.sh"
		return 1
	fi

	err "Cannot continue without Xcode Command Line Tools"
	return 1
}

ensure_homebrew() {
	export HOMEBREW_CASK_OPTS="--appdir=/Applications"

	if have_cmd brew; then
		success "Homebrew: available"
		return 0
	fi

	local brew_bin=""
	if [ -x /opt/homebrew/bin/brew ]; then
		brew_bin=/opt/homebrew/bin/brew
	elif [ -x /usr/local/bin/brew ]; then
		brew_bin=/usr/local/bin/brew
	fi

	if [[ -n "$brew_bin" ]]; then
		warn "Homebrew found at $brew_bin but not in PATH; configuring shellenv"
		eval "$("$brew_bin" shellenv)"

		if grep -Eq 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
			warn "~/.zprofile already contains a brew shellenv line; not modifying"
		else
			local shellenv_line="eval \"\$(${brew_bin} shellenv)\""
			ensure_line_in_file "$shellenv_line" "$HOME/.zprofile"
		fi

		success "Homebrew: shellenv configured"
		return 0
	fi

	warn "Homebrew: missing"
	info "Install Homebrew now?"
	if wait_input; then
		sudo --validate
		NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
		local brew_bin=""
		if [ -x /opt/homebrew/bin/brew ]; then
			brew_bin=/opt/homebrew/bin/brew
		elif [ -x /usr/local/bin/brew ]; then
			brew_bin=/usr/local/bin/brew
		fi

		if [[ -n "$brew_bin" ]]; then
			eval "$("$brew_bin" shellenv)"
			if grep -Eq 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
				warn "~/.zprofile already contains a brew shellenv line; not modifying"
			else
				local shellenv_line="eval \"\$(${brew_bin} shellenv)\""
				ensure_line_in_file "$shellenv_line" "$HOME/.zprofile"
			fi
		fi
		success "Homebrew: installed"
		return 0
	fi

	err "Cannot continue without Homebrew"
	return 1
}

ensure_brew_formula() {
	local formula="$1"

	if brew list --formula "$formula" &>/dev/null; then
		success "brew formula: $formula"
		return 0
	fi

	warn "brew formula missing: $formula"
	info "Install $formula now?"
	if wait_input; then
		brew install "$formula"
		success "Installed: $formula"
		return 0
	fi

	err "Missing required formula: $formula"
	return 1
}

ensure_brew_cask() {
	local cask="$1"

	if brew list --cask "$cask" &>/dev/null; then
		success "brew cask: $cask"
		return 0
	fi

	warn "brew cask missing: $cask"
	info "Install $cask now?"
	if wait_input; then
		brew install --cask "$cask"
		success "Installed cask: $cask"
		return 0
	fi

	err "Missing required cask: $cask"
	return 1
}

check_gh_auth() {
	if ! have_cmd gh; then
		return 1
	fi

	if gh auth status -h github.com &>/dev/null; then
		success "gh auth: signed in"
		return 0
	fi

	warn "gh auth: not signed in"
	info "Run 'gh auth login' now? (recommended)"
	if wait_input; then
		gh auth login
	fi

	gh auth status -h github.com &>/dev/null
}

ssh_github_ok() {
	local out
	out="$(ssh -T -o BatchMode=yes -o ConnectTimeout=5 git@github.com 2>&1 || true)"
	# GitHub commonly returns exit code 1 on success (no shell), so we rely on output.
	echo "$out" | grep -Eq 'successfully authenticated|^Hi [^ ]+! You\x27ve successfully authenticated'
}

ensure_github_ssh() {
	if ssh_github_ok; then
		success "GitHub SSH: OK"
		return 0
	fi

	warn "GitHub SSH: not working"

	if [ ! -f "$HOME/.ssh/id_ed25519.pub" ]; then
		info "No ~/.ssh/id_ed25519.pub found. Generate an SSH key now?"
		if wait_input; then
			mkdir -p "$HOME/.ssh"
			chmod 700 "$HOME/.ssh"
			ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519"
		fi
	fi

	if [ -f "$HOME/.ssh/id_ed25519" ]; then
		info "Add key to ssh-agent now?"
		if wait_input; then
			# Best-effort agent setup
			eval "$(ssh-agent -s)" &>/dev/null || true
			ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" &>/dev/null || ssh-add "$HOME/.ssh/id_ed25519" &>/dev/null || true
		fi
	fi

	# Optionally upload the key via gh (avoids manual GitHub UI steps), but requires gh auth.
	if have_cmd gh && [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
		if gh auth status -h github.com &>/dev/null; then
			info "Upload SSH public key to GitHub via 'gh ssh-key add' now?"
			if wait_input; then
				gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "mac-bootstrap $(hostname -s)" || true
			fi
		else
			warn "gh is installed but not authenticated; skipping automatic key upload"
		fi
	fi

	if ssh_github_ok; then
		success "GitHub SSH: OK"
		return 0
	fi

	err "GitHub SSH still failing. Ensure your public key is added to GitHub and try again."
	if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
		info "Public key to add (copy/paste into GitHub SSH keys):"
		cat "$HOME/.ssh/id_ed25519.pub"
	fi
	return 1
}

ensure_submodules() {
	local dirty_report

	# Only check for dirtiness in submodules that are already checked out.
	dirty_report="$(git submodule foreach --recursive --quiet '
		if [ -n "$(git status --porcelain)" ]; then
			echo "## $path"
			git status --porcelain
		fi
	' 2>/dev/null || true)"

	if [[ -n "$dirty_report" ]]; then
		warn "Dirty submodules detected (uncommitted changes):"
		echo "$dirty_report"

		info "Stash submodule changes and continue with update?"
		if wait_input; then
			git submodule foreach --recursive --quiet 'git stash push -u -m "mac-bootstrap preflight" >/dev/null || true' || true
		else
			info "Skip submodule update and continue?"
			if wait_input; then
				warn "Skipping submodule update"
				return 0
			fi

			err "Aborting due to dirty submodules"
			return 1
		fi
	fi

	info "Initializing/updating submodules..."
	git submodule update --init --recursive
	success "Submodules: initialized"
}

check_mas_account() {
	export MB_MAS_SIGNED_IN=0

	if ! have_cmd mas; then
		warn "mas: not installed (Mac App Store installs will be skipped)"
		return 0
	fi

	if mas account &>/dev/null; then
		success "mas: signed in"
		export MB_MAS_SIGNED_IN=1
		return 0
	fi

	warn "mas: not signed in"
	info "Open App Store now to sign in?"
	if wait_input; then
		if mb_have_cmd open; then
			open -a "App Store" >/dev/null 2>&1 || open "macappstore://" >/dev/null 2>&1 || true
		else
			warn "open command not available; please open App Store manually"
		fi

		info "After signing in, confirm to re-check"
		if wait_input; then
			if mas account &>/dev/null; then
				success "mas: signed in"
				export MB_MAS_SIGNED_IN=1
				return 0
			fi
			warn "mas still not signed in; skipping Mac App Store installs"
			return 0
		fi
	fi

	warn "Skipping Mac App Store installs (not signed in)"
	return 0
}

run_requirements() {
	info "################################################################################"
	info "Requirements / Preflight"
	info "################################################################################"

	# Basic commands (should be present on macOS)
	for c in zsh curl git ssh; do
		if mb_have_cmd "$c"; then
			success "cmd: $c"
		else
			err "Missing required command: $c"
			return 1
		fi
	done

	ensure_xcode_clt
	ensure_homebrew

	# Single source of truth for required brew deps
	. scripts/brew.sh
	if (( ! ${+required_formulas} )); then
		err "scripts/brew.sh must define required_formulas"
		return 1
	fi

	if (( ${+required_casks} )) && (( ${#required_casks[@]} )); then
		for c in "${required_casks[@]}"; do
			ensure_brew_cask "$c"
		done
	fi

	for f in "${required_formulas[@]}"; do
		ensure_brew_formula "$f"
	done

	# Auth & connectivity checks
	check_gh_auth || warn "gh auth: still not signed in"
	ensure_github_ssh

	# Submodules use SSH URLs in this repo
	ensure_submodules

	check_mas_account
	success "Preflight complete"
}

# Note: this file is intended to be sourced (by mac-bootstrap.sh).
# For standalone execution, use: ./scripts/requirements-run.sh
