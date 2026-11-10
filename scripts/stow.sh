stow_dotfiles() {
	local files=(
		".gitconfig"
		".aerospace.toml"
		".yabairc"
	)
	local folders=(
		".config/borders"
		".config/git"
		".config/nushell"
		".config/nvim"
		".config/sketchybar"
		".config/starship"
		".config/wezterm"
		".config/yazi"
		".hammerspoon"
	)

	info "Removing existing config files"
	for f in "${files[@]}"; do
		rm -f "$HOME/$f" || true
	done

	# Create the folders to avoid symlinking folders
	for d in "${folders[@]}"; do
		rm -rf "${HOME:?}/$d" || true
		mkdir -p "$HOME/$d"
	done

	local script_dir repo_root stow_dir
	# Use ${(%):-%x} to get the path of this sourced script file
	script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
	repo_root="$(cd "$script_dir/.." && pwd)"
	stow_dir="$repo_root/stow"

	if [[ ! -d "$stow_dir" ]]; then
		err "stow directory not found at: $stow_dir"
		return 1
	fi

	# Use a while loop and read to handle directories
	local to_stow=()
	while IFS= read -r dir; do
		to_stow+=("$dir")
	done < <(find "$stow_dir" -maxdepth 1 -type d -mindepth 1 -exec basename {} \;)

	info "Stowing directories: ${to_stow[@]}"

	# Run stow for each directory individually
	for dir in "${to_stow[@]}"; do
		stow --dir="$stow_dir" --verbose=1 --target="$HOME" "$dir"
	done
}
