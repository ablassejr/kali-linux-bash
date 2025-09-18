#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root

TARGET_USER=$(get_target_user)
TARGET_HOME=$(get_home_dir "$TARGET_USER")
ZSH_PATH=$(command -v zsh)
ZSHRC_FILE="$TARGET_HOME/.zshrc"

if [[ -z "$ZSH_PATH" ]]; then
    echo "zsh is not installed. Run install_apt_packages.sh first." >&2
    exit 1
fi

if [[ ! -f "$ZSHRC_FILE" ]]; then
    touch "$ZSHRC_FILE"
fi
chown "$TARGET_USER":"$TARGET_USER" "$ZSHRC_FILE"

append_if_missing "$ZSHRC_FILE" "# Added by DFOR767 installer" "# Added by DFOR767 installer"
append_if_missing "$ZSHRC_FILE" "eval \"\$(zoxide init zsh" "eval \"\$(zoxide init zsh --cmd z)\""
append_if_missing "$ZSHRC_FILE" "source \$HOME/.dfor767_env" "[[ -f \$HOME/.dfor767_env ]] && source \$HOME/.dfor767_env"

CURRENT_SHELL=$(getent passwd "$TARGET_USER" | cut -d: -f7)
if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
    echo "Setting default shell for $TARGET_USER to zsh"
    chsh -s "$ZSH_PATH" "$TARGET_USER" || echo "Warning: Failed to change shell for $TARGET_USER" >&2
fi

