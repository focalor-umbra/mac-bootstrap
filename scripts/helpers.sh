#!/usr/bin/env zsh

mb_have_cmd() {
	command -v "$1" &>/dev/null
}

mb_have_fn() {
	typeset -f "$1" &>/dev/null
}

mb_run_step() {
	local title="$1"
	shift

	info "$title"
	if wait_input; then
		"$@"
	else
		warn "Skipped: $title"
	fi
}

mb_press_enter_or_quit() {
	local prompt=${1:-"Press enter to continue, or 'q' to exit: "}
	local input

	while true; do
		read -k 1 -r "input?$prompt"
		if [[ $input == $'\n' ]]; then
			break
		elif [[ $input == "q" ]]; then
			exit 0
		else
			echo $'\n' "Invalid input. Please try again."
		fi
	done
}
