#!/usr/bin/env zsh

# Claude Code plugins live in marketplaces, so each marketplace has to be
# registered before its plugins can be installed. Plugin ids are always
# <plugin>@<marketplace>.
install_claude_plugins() {
	local -A claude_marketplaces=(
		[mempalace]="MemPalace/mempalace"
		[caveman]="JuliusBrussee/caveman"
	)
	local claude_plugins=(
		"mempalace@mempalace"
		"caveman@caveman"
	)

	if ! mb_have_cmd claude; then
		warn "claude not found; skipping Claude Code plugins"
		return 0
	fi

	local configured m p
	configured="$(claude plugin marketplace list 2>/dev/null)"

	for m in "${(@k)claude_marketplaces}"; do
		if print -r -- "$configured" | grep -qF "${claude_marketplaces[$m]}"; then
			warn "Marketplace $m is already configured"
		else
			info "Adding marketplace < $m >"
			claude plugin marketplace add "${claude_marketplaces[$m]}"
		fi
	done

	local installed
	installed="$(claude plugin list 2>/dev/null)"

	for p in "${claude_plugins[@]}"; do
		if print -r -- "$installed" | grep -qF "$p"; then
			warn "Plugin $p is already installed"
		else
			info "Installing plugin < $p >"
			# -y is required when stdout is not a TTY (marketplace-declared
			# install commands otherwise block on a confirmation prompt).
			claude plugin install "$p" --scope user -y
		fi
	done

	success "Claude Code plugins are up to date"
}
