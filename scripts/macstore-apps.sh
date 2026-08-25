mas_apps=(
)

install_masApps() {
	# Preflight sets MB_MAS_SIGNED_IN=1 when mas is authenticated.
	# Re-check defensively in case user signed in after preflight.
	if [[ "${MB_MAS_SIGNED_IN:-0}" != "1" ]]; then
		if ! mas account &>/dev/null; then
			warn "Skipping Mac App Store installs (mas not signed in)"
			return 0
		fi
		export MB_MAS_SIGNED_IN=1
	fi

	info "Installing App Store apps..."
	for app in "${mas_apps[@]}"; do
		mas install "$app"
	done
}