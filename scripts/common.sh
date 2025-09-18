#!/usr/bin/env bash
set -euo pipefail

require_root() {
    if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run with root privileges." >&2
        exit 1
    fi
}

# Determine the primary non-root user when running via sudo.
get_target_user() {
    if [[ -n "${SUDO_USER-}" && ${SUDO_USER} != "root" ]]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

get_home_dir() {
    local user="$1"
    local home_dir
    home_dir=$(eval echo "~${user}")
    echo "$home_dir"
}

append_if_missing() {
    local file="$1"
    local pattern="$2"
    local content="$3"

    if [[ ! -f "$file" ]] || ! grep -Fq "$pattern" "$file"; then
        printf '\n%s\n' "$content" >> "$file"
    fi
}
