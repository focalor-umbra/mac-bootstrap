reset_color=$(tput sgr 0 2>/dev/null || echo '')

# Resolve repo paths based on this file's location (works regardless of current working directory).
MB_UTILS_PATH="${${(%):-%N}:A}"
MB_SCRIPTS_DIR="${MB_UTILS_PATH:h}"
MB_REPO_ROOT="${MB_SCRIPTS_DIR:h}"

# Load shared helpers (mb_have_cmd/mb_have_fn/mb_run_step/mb_press_enter_or_quit)
. "$MB_SCRIPTS_DIR/helpers.sh"

info() {
	printf "%s[*] %s%s\n" "$(tput setaf 4 2>/dev/null || echo '')" "$1" "$reset_color"
}

success() {
	printf "%s[*] %s%s\n" "$(tput setaf 2 2>/dev/null || echo '')" "$1" "$reset_color"
}

err() {
	printf "%s[*] %s%s\n" "$(tput setaf 1 2>/dev/null || echo '')" "$1" "$reset_color"
}

warn() {
	printf "%s[*] %s%s\n" "$(tput setaf 3 2>/dev/null || echo '')" "$1" "$reset_color"
}

wait_input() {
	while true; do
		read -k 1 -r "input?Press 'y' to continue, or 'n' to skip: "
		if [[ $input == $'y' ]]; then
			echo $'\n'
			return 0 # Success
		elif [[ $input == $'n' ]]; then
			echo $'\n'
			return 1 # Skip
		else
			echo $'\n' "Invalid input. Please try again."
		fi
	done
}