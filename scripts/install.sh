#!/usr/bin/env zsh
set -o errexit
set -o nounset
set -o pipefail

# Ensure relative paths work even if invoked from elsewhere.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

. scripts/utils.sh
. scripts/osx-configs.sh
. scripts/macstore-apps.sh
. scripts/brew.sh
. scripts/python.sh
. scripts/node.sh
. scripts/golang.sh
. scripts/lua.sh
. scripts/claude-plugins.sh
. scripts/stow.sh
. scripts/post-install.sh
. scripts/rectangle.sh

on_error() {
	local code=$?
	err "Last command failed (exit $code)"
	info "Finishing..."
}

on_interrupt() {
	err "Interrupted"
	info "Finishing..."
	exit 130
}

main() {
	info "Installing ..."

	info "################################################################################"
	info "MacOS Apps"
	info "################################################################################"
	if wait_input; then
		install_masApps
		success "Finished installing macOS apps"
	fi

	info "################################################################################"
	info "Homebrew Installation (Formulas & Casks)"
	info "################################################################################"
	if wait_input; then
		install_packages
		success "Finished installing Homebrew formulas and casks"
	fi

	info "################################################################################"
	info "python modules"
	info "################################################################################"
	if wait_input; then
		install_python_packages
		success "Finished installing python packages"
	fi

	info "################################################################################"
	info "node modules"
	info "################################################################################"
	if wait_input; then
		install_node_packages
		success "Finished installing node packages"
	fi

	info "################################################################################"
	info "lua modules"
	info "################################################################################"
	if wait_input; then
		install_lua_packages
		success "Finished installing lua packages"
	fi

	info "################################################################################"
	info "Golang tools"
	info "################################################################################"
	if wait_input; then
		install_go_tools
		success "Finished installing Golang tools"
	fi

	info "################################################################################"
	info "Stow .dotfiles"
	info "################################################################################"
	if wait_input; then
		stow_dotfiles
		success "Finished stowing dotfiles"
	fi

	info "################################################################################"
	info "Mac Configuration"
	info "################################################################################"
	if wait_input; then
		setup_osx
		success "Finished configuring MacOS defaults. NOTE: A restart is needed"
	fi

	info "################################################################################"
	info "Post Install"
	info "################################################################################"
	if wait_input; then
		post_install
	fi

	info "System needs to restart. Restart?"
	if wait_input; then
		sudo shutdown -r now
	fi
	success "Installation process completed successfully"
}

trap on_error ERR
trap on_interrupt SIGINT SIGTERM

main
