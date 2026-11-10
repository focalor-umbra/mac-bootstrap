#!/usr/bin/env zsh
config_rectangle() {
  defaults write com.knollsoft.Rectangle screenEdgeGapTop -int 55
  defaults write com.knollsoft.Rectangle screenEdgeGapBottom -int 15
  defaults write com.knollsoft.Rectangle screenEdgeGapLeft -int 15
  defaults write com.knollsoft.Rectangle screenEdgeGapRight -int 15

  defaults write com.knollsoft.Rectangle screenEdgeGapTopNotch -int 15

  defaults write com.knollsoft.Rectangle almostMaximizeHeight -float 0.95
  defaults write com.knollsoft.Rectangle almostMaximizeWidth -float 0.95
  defaults write com.knollsoft.Rectangle doubleClickTitleBar -int 30
}
