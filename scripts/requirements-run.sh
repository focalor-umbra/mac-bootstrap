#!/usr/bin/env zsh
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

. scripts/utils.sh
. scripts/requirements.sh

run_requirements
