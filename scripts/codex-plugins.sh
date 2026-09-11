#!/usr/bin/env zsh

# Register the same marketplaces used by the desktop app, then install their
# Codex plugins. Use JSON and exact ids so reruns leave installed plugins alone.
install_codex_plugins() {
	local -A codex_marketplaces=(
		[mempalace]="MemPalace/mempalace"
		[caveman]="JuliusBrussee/caveman"
	)
	local codex_plugins=(
		"mempalace@mempalace"
		"caveman@caveman"
	)

	if ! mb_have_cmd codex; then
		warn "codex not found; install it with: brew install --cask codex"
		return 0
	fi
	if ! mb_have_cmd jq; then
		err "jq is required for Codex plugin setup; install it with: brew install jq"
		return 1
	fi
	if ! codex plugin add --help >/dev/null 2>&1; then
		err "This Codex CLI lacks plugin support; update it with: brew upgrade --cask codex"
		return 1
	fi

	local configured installed listing m p
	listing="$(codex plugin marketplace list --json)" || return $?
	configured="$(print -r -- "$listing" | jq -er '.marketplaces | map(.name) | join("\n")')" || return $?

	for p in "${codex_plugins[@]}"; do
		m="${p##*@}"
		if print -r -- "$configured" | grep -Fxq -- "$m"; then
			info "Marketplace $m is already configured"
		else
			info "Adding marketplace < $m >"
			codex plugin marketplace add "${codex_marketplaces[$m]}" || return $?
		fi

		# A marketplace filter avoids querying unrelated remote plugin catalogs.
		listing="$(codex plugin list --marketplace "$m" --json)" || return $?
		installed="$(print -r -- "$listing" | jq -er '.installed | map(select(.installed == true) | .pluginId) | join("\n")')" || return $?
		if print -r -- "$installed" | grep -Fxq -- "$p"; then
			info "Plugin $p is already installed"
		else
			info "Installing plugin < $p >"
			codex plugin add "$p" || return $?
		fi
	done

	success "Codex plugins are installed; start a new Codex session to use them"
}
