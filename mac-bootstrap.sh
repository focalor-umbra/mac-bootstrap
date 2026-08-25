#!/usr/bin/env zsh
set -o errexit

# Ensure relative paths work even if invoked from elsewhere.
cd "$(dirname "$0")"

. scripts/utils.sh
. scripts/requirements.sh

info "####### Mac Bootstrap #######"
mb_press_enter_or_quit

info "Bootstrapping..."
run_requirements

./scripts/install.sh
