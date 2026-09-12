#!/usr/bin/env zsh

mb_codex_write_file() (
	local target="$1" source_file="$2" dry_run="$3" temporary="" backup
	trap '[[ -z "$temporary" ]] || rm -f -- "$temporary"' EXIT
	if [[ -f "$target" ]] && cmp -s -- "$target" "$source_file"; then
		info "Unchanged: $target"
		return 0
	fi
	if [[ "$dry_run" == true ]]; then
		info "Would update: $target"
		return 0
	fi
	mkdir -p -- "${target:h}" || return $?
	if [[ -f "$target" ]]; then
		backup="$(mktemp "${target}.backup-$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")" || return $?
		cp -p -- "$target" "$backup" || return $?
		info "Backup: $backup"
	fi
	temporary="$(mktemp "${target}.tmp.XXXXXX")" || return $?
	if [[ -f "$target" ]]; then
		cp -p -- "$target" "$temporary" || return $?
	fi
	cat -- "$source_file" > "$temporary" || return $?
	mv -f -- "$temporary" "$target" || return $?
	info "Updated: $target"
)

configure_codex() (
	local vault="${MB_OBSIDIAN_VAULT:-}" directory="${CODEX_HOME:-$HOME/.codex}"
	local registry="$HOME/Library/Application Support/obsidian/obsidian.json"
	local dry_run=false option agents settings target workspace
	while (( $# )); do
		option="$1"
		case "$option" in
			--vault|--codex-dir|--obsidian-registry)
				if (( $# < 2 )); then err "Missing value for $option"; return 1; fi
				case "$option" in
					--vault) vault="$2" ;;
					--codex-dir) directory="$2" ;;
					--obsidian-registry) registry="$2" ;;
				esac
				shift 2 ;;
			--dry-run) dry_run=true; shift ;;
			-h|--help)
				print 'Usage: zsh scripts/codex-config.sh [--vault PATH] [--codex-dir PATH] [--obsidian-registry PATH] [--dry-run]'
				return 0 ;;
			*) err "Unknown option: $option"; return 1 ;;
		esac
	done
	if ! mb_have_cmd jq; then
		err "jq is required to configure Codex; run: brew install jq"
		return 1
	fi
	directory="${directory/#\~/$HOME}"
	directory="${directory:A}"
	registry="${registry/#\~/$HOME}"
	agents="$directory/AGENTS.md"
	settings="$directory/obsidian-vault.json"
	if [[ -f "$directory/AGENTS.override.md" ]] && grep -q '[^[:space:]]' "$directory/AGENTS.override.md"; then
		err "AGENTS.override.md shadows global AGENTS.md; reconcile the override first"
		return 1
	fi
	for target in "$agents" "$settings"; do
		if [[ -L "$target" || ( -e "$target" && ! -f "$target" ) ]]; then
			err "Destination must be a regular file, not a symlink or directory: $target"
			return 1
		fi
	done
	if [[ -z "$vault" ]]; then
		if [[ -f "$settings" ]]; then
			vault="$(jq -er '.vault_path | select(type == "string" and length > 0)' "$settings")" || return $?
		elif [[ -f "$registry" ]]; then
			vault="$(jq -er '[.vaults[].path | select(type == "string" and length > 0)] | unique | if length == 1 then .[0] else error("Select a vault with --vault PATH or MB_OBSIDIAN_VAULT") end' "$registry")" || return $?
		else
			err "Open/sync the vault in Obsidian first, or select it with --vault PATH"
			return 1
		fi
	fi
	vault="${vault/#\~/$HOME}"
	vault="${vault:A}"
	if [[ ! -d "$vault/.obsidian" || ! -f "$vault/03-Reference/Guides/DOCUMENTATION_STANDARDS.md" ]]; then
		err "Vault or documentation standards unavailable at $vault; finish syncing or select --vault PATH"
		return 1
	fi
	workspace="$(mktemp -d "${TMPDIR:-/tmp}/codex-config.XXXXXX")" || return $?
	trap 'rm -rf -- "$workspace"' EXIT
	if [[ -f "$agents" ]]; then
		cp -- "$agents" "$workspace/existing" || return $?
	else
		: > "$workspace/existing"
	fi
	# jq raw strings preserve surrounding instructions, including final newlines.
	# Splitting on literal markers also detects duplicate/incomplete blocks.
	jq -nj --arg vault "$vault" \
		--rawfile template "$MB_REPO_ROOT/config/codex/AGENTS.md" \
		--rawfile existing "$workspace/existing" '
		"<!-- mac-bootstrap:codex:start -->" as $start |
		"<!-- mac-bootstrap:codex:end -->" as $end |
		($template | split("{{VAULT_PATH}}") | join($vault | tojson) | sub("\\n+$"; "")) as $rules |
		($start + "\n" + $rules + "\n" + $end) as $block |
		($existing | split($start)) as $parts |
		if ($existing | contains($start) | not) and ($existing | contains($end) | not) then
			$existing + (if $existing == "" or ($existing | endswith("\n\n")) then "" else "\n\n" end) + $block + "\n"
		elif ($parts | length) == 2 and ($parts[0] | contains($end) | not) and ($parts[1] | split($end) | length) == 2 then
			$parts[0] + $block + ($parts[1] | split($end) | .[1])
		else error("AGENTS.md has duplicate, incomplete or reversed bootstrap markers") end
	' > "$workspace/AGENTS.md" || return $?
	jq -n --arg vault "$vault" '{vault_path: $vault}' > "$workspace/obsidian-vault.json" || return $?
	mb_codex_write_file "$agents" "$workspace/AGENTS.md" "$dry_run" || return $?
	mb_codex_write_file "$settings" "$workspace/obsidian-vault.json" "$dry_run" || return $?
	info "Vault: $vault"
	success "Start a new Codex task/session to load the shared instructions"
)

# Also allow direct execution, while keeping the sourced bootstrap module inert.
if [[ "$ZSH_EVAL_CONTEXT" == toplevel ]]; then
	source "${0:A:h}/utils.sh"
	configure_codex "$@"
fi
