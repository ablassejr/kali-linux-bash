#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    bash "$SCRIPT_DIR/scripts/install_apt_packages.sh"
    bash "$SCRIPT_DIR/scripts/configure_zsh.sh"
    bash "$SCRIPT_DIR/scripts/configure_course_env.sh"

    cat <<'SUMMARY'
All requested tools and course-specific environment customizations have been installed.
Start a new terminal session or run `exec zsh` to load the updated configuration.
Useful helper functions: dfor767_tools, dfor767_resources, dfor767_schedule.
SUMMARY
}

main "$@"
