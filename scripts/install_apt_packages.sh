#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root

APT_PACKAGES=(
    "zsh"
    "zoxide"
    "nmap"
    "hydra"
    "sqlmap"
    "metasploit-framework"
    "nikto"
    "burpsuite"
    "commix"
    "amass"
    "awscli"
    "python3-pip"
    "git"
)

echo "Updating apt package index..."
apt-get update -y

echo "Installing core penetration testing tools..."
apt-get install -y "${APT_PACKAGES[@]}"

