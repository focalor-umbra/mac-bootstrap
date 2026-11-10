install_node_packages() {
	local node_packages=(
		"@mermaid-js/mermaid-cli"
	)

	for p in "${node_packages[@]}"; do
		if npm ll -g | grep "$p" >/dev/null; then
			warn "Package $p is already installed"
		else
			info "Installing package < $p >"
			npm install -g "$p"
		fi
	done
}
