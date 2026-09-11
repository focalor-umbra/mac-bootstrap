#!/usr/bin/env zsh
# Run from any directory: zsh tests/codex-setup.zsh
# External commands are mocked; no packages or user settings are changed.
set -euo pipefail
cd "${0:A:h:h}"
source scripts/helpers.sh
source scripts/codex-plugins.sh
source scripts/rtk.sh
source scripts/brew.sh

info() { :; }
warn() { :; }
err() { :; }
success() { :; }

check() {
	if ! "$@"; then
		print -u2 -- "FAIL: $*"
		exit 1
	fi
}

typeset -a mutations=() marketplaces=() plugins=()
failure=""
codex() {
	case "$*" in
		'plugin add --help') return 0 ;;
		'plugin marketplace list --json')
			[[ "$failure" != list ]] || return 12
			if [[ "$failure" == malformed ]]; then
				print -r -- '{"marketplaces":null}'
			else
				printf '%s\n' "${marketplaces[@]}" | jq -Rn '{marketplaces: [inputs | select(length > 0) | {name: .}]}'
			fi
			;;
		'plugin marketplace add '*)
			mutations+=("$*")
			[[ "$failure" != add ]] || return 13
			marketplaces+=("${4##*/}")
			;;
		'plugin list --marketplace '*' --json')
			[[ "$failure" != plugin_list ]] || return 14
			printf '%s\n' "${plugins[@]}" | jq -Rn '{installed: [inputs | select(length > 0) | {pluginId: ., installed: true}]}'
			;;
		'plugin add '*)
			mutations+=("$*")
			[[ "$failure" != plugin_add ]] || return 15
			plugins+=("$3")
			;;
		*) print -u2 -- "Unexpected Codex command: $*"; return 99 ;;
	esac
}

# Fresh install must register each marketplace before installing its plugin.
install_codex_plugins
check test "${#mutations}" -eq 4
check test "$mutations[1]" = 'plugin marketplace add MemPalace/mempalace'
check test "$mutations[2]" = 'plugin add mempalace@mempalace'
check test "$mutations[3]" = 'plugin marketplace add JuliusBrussee/caveman'
check test "$mutations[4]" = 'plugin add caveman@caveman'
install_codex_plugins
check test "${#mutations}" -eq 4
print 'PASS: fresh install and idempotent rerun'

# Similar names must not be mistaken for the exact marketplace/plugin ids.
(
	marketplaces=(mempalace-extra caveman-extra)
	plugins=(mempalace@mempalace-extra caveman@caveman-extra)
	mutations=()
	install_codex_plugins
	check test "${#mutations}" -eq 4
)
print 'PASS: exact marketplace and plugin matching'

# Failures must propagate even when invoked inside an `if` (errexit disabled).
for failure in list malformed add plugin_list plugin_add; do
	(
		marketplaces=() plugins=() mutations=()
		if install_codex_plugins >/dev/null 2>&1; then
			print -u2 -- "FAIL: swallowed $failure error"
			exit 1
		fi
		case "$failure" in
			list|malformed) check test "${#mutations}" -eq 0 ;;
			add|plugin_list) check test "${#mutations}" -eq 1 ;;
			plugin_add) check test "${#mutations}" -eq 2 ;;
		esac
	)
done
print 'PASS: listing, malformed JSON, and installation failures stop setup'

rtk() { check test "$*" = 'init -g --codex'; }
configure_codex_rtk
(
	rtk() { return 16; }
	if configure_codex_rtk; then exit 1; else check test "$?" -eq 16; fi
)
print 'PASS: RTK targets Codex and propagates errors'

# Exercise the real cleanup code, with all Homebrew operations intercepted.
(
	mutations=()
	brew() {
		case "$*" in
			leaves) print -l jq rtk ;;
			'list --cask') print codex ;;
			uninstall*) mutations+=("$*") ;;
			autoremove) return 0 ;;
			*) return 99 ;;
		esac
	}
	cleanup_brew_taps() { :; }
	brew_cleanup
	check test "${#mutations}" -eq 0
)
print 'PASS: Homebrew cleanup preserves Codex, jq, and RTK'
