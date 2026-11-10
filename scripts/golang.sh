install_go_tools() {
	declare -A tools=(
		[delve]="github.com/go-delve/delve/cmd/dlv@latest"
	)

	for tool in "${(@k)tools}"; do
		if ! command -v "$tool" &>/dev/null; then
			info "Installing go tool < $tool >"
			go install "${tools[$tool]}"
		else
			warn "$tool is already installed"
		fi
	done
}