setup_osx() {
	info "Configuring MacOS default settings"
	defaults write com.apple.AppleMultitouchMouse MouseButtonMode -string "TwoButton"

	local wallpaper_path="${MB_REPO_ROOT:-$HOME/projects/mac-bootstrap}/resources/images/022f8f32-561f-4b07-a10b-5d86a879d245.jpg"
	if [[ -f "$wallpaper_path" ]]; then
		defaults write com.apple.desktop Background "{default = {ImageFilePath = \"$wallpaper_path\"; };}"
	else
		warn "Wallpaper not found at $wallpaper_path; skipping desktop wallpaper defaults"
	fi

	defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

	defaults write com.apple.dock show-recents -bool false
	defaults write com.apple.dock autohide -bool true
	defaults write com.apple.dock largesize -float 96
	defaults write com.apple.dock minimize-to-application -bool false
	defaults write com.apple.dock tilesize -float 45
	defaults write com.apple.dock workspaces-swoosh-animation-off -bool YES

	defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool false
	defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
	defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool false
	defaults write com.apple.finder ShowMountedServersOnDesktop -bool false
	defaults write com.apple.finder CreateDesktop -bool true
	defaults write com.apple.finder ShowPathbar -bool true
	defaults write com.apple.finder AppleShowAllFiles -bool true
	defaults write com.apple.finder ShowStatusBar -bool true
	defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
	defaults write com.apple.finder NewWindowTarget -string "PfHm"
	defaults write com.apple.finder NewWindowTargetPath -string "file:///${HOME}/"

	if [[ -f "$wallpaper_path" ]]; then
		defaults write com.apple.wallpaper SystemWallpaperURL "file://$wallpaper_path"
	fi

	defaults write com.apple.screencapture type -string "png"
	defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

	defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

	defaults write NSGlobalDomain _HIHideMenuBar -int 1
	defaults write -g NSWindowShouldDragOnGesture -bool true
	defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
}
