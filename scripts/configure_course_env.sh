#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root

TARGET_USER=$(get_target_user)
TARGET_HOME=$(get_home_dir "$TARGET_USER")
COURSE_ENV_FILE="$TARGET_HOME/.dfor767_env"

cat <<'ENV' > "$COURSE_ENV_FILE"
# Environment customizations for DFOR 767 - Penetration Testing Forensics
export DFOR767_COURSE_CODE="DFOR 767"
export DFOR767_SECTION="001"
export DFOR767_TERM="Fall 2021"
export DFOR767_COURSE_NAME="Penetration Testing Forensics"
export DFOR767_INSTRUCTOR="Tahir Khan"
export DFOR767_INSTRUCTOR_EMAIL="tkhan9@gmu.edu"
export DFOR767_CLASS_TIME="Tuesdays, 16:30 – 19:10"
export DFOR767_LOCATION="George Mason University"

# Ensure local bin directory is prioritized for custom tooling
export PATH="$HOME/.local/bin:$PATH"

dfor767_tools() {
    cat <<'TOOLS'
Core Tools:
  - Nmap
  - Hydra
  - Sqlmap
  - Metasploit
  - Nikto
  - BurpSuite
  - Commix
  - Kali Linux built-in utilities
  - Amass
TOOLS
}

dfor767_resources() {
    cat <<'RESOURCES'
External Resources:
  * AWS Educate: https://aws.amazon.com/education/awseducate/apply/
  * VulnHub practice VMs: https://www.vulnhub.com
RESOURCES
}

dfor767_schedule() {
    cat <<'SCHEDULE'
Weekly Highlights:
Week 1: Introduction, Scoping, Ethics (Assignment 1 issued)
Week 2: Passive Reconnaissance (Install Kali Linux + BurpSuite)
Week 3: Active Reconnaissance (Assignment 1 due; Assignment 2 issued)
Week 4: Vulnerability Assessment; Exploitation basics
Week 5: SQL Injection (Assignment 2 due; Assignment 3 issued)
Week 6: Advanced SQL Injection
Week 7: Command Injection
Week 9: File Inclusion (Assignment 3 due; Assignment 4 issued)
Week 10: Midterm issued (Take-home)
Week 11: Persistence, Pivoting, Lateral Movement (Assignment 4 due; Midterm due; Assignments 5 & 6 issued)
Week 12: Passwords, Privilege Escalation, XSS (Assignments 5 & 6 due)
Week 13: Final Review
Week 14: Final Presentations (Final due @ 16:20)
Week 15: Final Presentations (continued)
SCHEDULE
}

alias dfor767-open-aws='xdg-open https://aws.amazon.com/education/awseducate/apply/ >/dev/null 2>&1'
alias dfor767-open-vulnhub='xdg-open https://www.vulnhub.com >/dev/null 2>&1'

ENV

chown "$TARGET_USER":"$TARGET_USER" "$COURSE_ENV_FILE"
chmod 0644 "$COURSE_ENV_FILE"

