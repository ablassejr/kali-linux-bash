# Kali Linux Setup Bash Script

This repository provides a modular installer for Kali Linux environments aligned with the George Mason University DFOR 767 Penetration Testing Forensics syllabus. The scripts install the required tooling, configure an enhanced Z shell (zsh) experience, and expose helper functions and environment variables capturing important course information.

## Usage

```bash
sudo ./install.sh
```

The installer performs the following steps:

1. Installs course tooling (zsh, zoxide, Nmap, Hydra, Sqlmap, Metasploit, Nikto, BurpSuite, Commix, Amass, AWS CLI, and supporting utilities).
2. Configures zsh as the default shell with zoxide integration for fast directory jumping (`z`).
3. Creates course-specific environment variables, helper functions, and aliases sourced from `~/.dfor767_env`.

After installation, start a new terminal or run `exec zsh` to load the updated configuration. Access course helpers with:

- `dfor767_tools`
- `dfor767_resources`
- `dfor767_schedule`

These functions summarize the syllabus, recommended tools, and external resources.
