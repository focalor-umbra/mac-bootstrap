install_python_packages() {
	local pip_packages=(
		mempalace
	)

	for p in "${pip_packages[@]}"; do
		if pipx list --short 2>/dev/null | grep -qw "$p"; then
			warn "Package $p is already installed"
		else
			info "Installing package < $p >"
			pipx install "$p"
		fi
	done
}
