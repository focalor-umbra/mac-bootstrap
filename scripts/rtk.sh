#!/usr/bin/env zsh

configure_codex_rtk() {
	if ! mb_have_cmd rtk; then
		warn "rtk not found; install it with: brew install rtk"
		return 0
	fi

	# RTK's Codex integration uses AGENTS.md + RTK.md instructions. The explicit
	# --codex flag is required: plain `rtk init -g` targets Claude Code.
	info "Configuring RTK for Codex"
	rtk init -g --codex || return $?
	success "RTK is configured for Codex; start a new session to load its instructions"
}
