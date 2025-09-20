#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SHELL_CONFIGS=("$HOME/.zprofile" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.bashrc")

add_shell_snippet() {
    local snippet="$1"
    for shell_file in "${SHELL_CONFIGS[@]}"; do
        append_if_missing "$shell_file" "$snippet" "$snippet"
    done
}

ensure_path_export() {
    local dir="$1"
    local export_line="export PATH=\"$dir:\$PATH\""
    add_shell_snippet "$export_line"
}

ensure_directory() {
    local dir="$1"
    mkdir -p "$dir"
}

info() {
    printf "[macOS setup] %s\n" "$1"
}

if ! command -v xcode-select >/dev/null 2>&1 || ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools are required. Please run 'xcode-select --install' and re-run this script." >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required. Install it from https://brew.sh/ and re-run this script." >&2
    exit 1
fi

BREW_FORMULAE=(
    "git"
    "neovim"
    "python@3.12"
    "node"
    "yarn"
    "cmake"
    "go"
    "delve"
    "rustup-init"
    "llvm"
    "pkg-config"
    "openssl@3"
    "readline"
    "sqlite"
    "xz"
    "ruby"
    "openjdk"
    "maven"
    "gradle"
    "coursier/formulas/coursier"
    "scala"
    "sbt"
    "elixir"
    "erlang"
    "r"
    "ghc"
    "cabal-install"
    "haskell-language-server"
    "stack"
    "hoogle"
    "ansible"
    "helm"
    "pandoc"
    "graphviz"
    "shellcheck"
    "jq"
    "fzf"
    "ripgrep"
    "tree-sitter"
    "chezmoi"
    "gh"
    "watchexec"
)

BREW_CASKS=(
    "dotnet-sdk"
    "basictex"
)

info "Updating Homebrew..."
brew update

if [[ ${#BREW_FORMULAE[@]} -gt 0 ]]; then
    info "Installing command-line dependencies with Homebrew..."
    brew install "${BREW_FORMULAE[@]}"
fi

if [[ ${#BREW_CASKS[@]} -gt 0 ]]; then
    info "Installing cask applications with Homebrew..."
    brew install --cask "${BREW_CASKS[@]}"
fi

BREW_PREFIX="$(brew --prefix)"

ensure_path_export "$BREW_PREFIX/opt/llvm/bin"
ensure_path_export "$BREW_PREFIX/opt/openjdk/bin"

if brew --prefix python@3.12 >/dev/null 2>&1; then
    PYTHON_PREFIX="$(brew --prefix python@3.12)"
    ensure_path_export "$PYTHON_PREFIX/bin"
fi

if brew --prefix ruby >/dev/null 2>&1; then
    RUBY_PREFIX="$(brew --prefix ruby)"
    ensure_path_export "$RUBY_PREFIX/bin"
fi

ensure_path_export "/Library/TeX/texbin"
ensure_directory "$HOME/.local/bin"
ensure_path_export "$HOME/.local/bin"

if command -v rustup >/dev/null 2>&1; then
    info "Updating existing Rust toolchain via rustup..."
    rustup self update
else
    info "Bootstrapping Rust toolchain via rustup-init..."
    rustup-init -y --no-modify-path
fi

if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env"
fi

ensure_path_export "$HOME/.cargo/bin"

info "Ensuring Rust components are installed..."
rustup toolchain install stable
rustup default stable
rustup component add rustfmt clippy >/dev/null 2>&1 || true
rustup component add rust-analyzer >/dev/null 2>&1 || cargo install --locked rust-analyzer || true
cargo install --locked taplo-cli stylua cargo-nextest cargo-watch >/dev/null 2>&1 || true

info "Installing Go tooling..."
if command -v go >/dev/null 2>&1; then
    export GO111MODULE=on
    go install golang.org/x/tools/gopls@latest
    go install github.com/cweill/gotests/...@latest
    go install gotest.tools/gotestsum@latest
fi

info "Installing global npm packages for language servers and formatters..."
NPM_PACKAGES=(
    "neovim"
    "typescript"
    "typescript-language-server"
    "bash-language-server"
    "yaml-language-server"
    "vscode-langservers-extracted"
    "@ansible/ansible-language-server"
    "@vue/language-server"
    "svelte-language-server"
    "graphql-language-service-cli"
    "dockerfile-language-server-nodejs"
    "emmet-ls"
    "eslint"
    "prettier"
    "jsonlint"
    "sql-formatter"
    "markdownlint-cli"
    "tailwindcss-language-server"
)

npm install -g "${NPM_PACKAGES[@]}"

info "Installing Python packages for language tooling..."
PYTHON_BIN="$(command -v python3)"
"$PYTHON_BIN" -m pip install --upgrade pip
"$PYTHON_BIN" -m pip install --user --upgrade \
    pynvim debugpy black isort ruff flake8 mypy pytest pytest-cov ansible-lint

PYTHON_USER_BIN="$($PYTHON_BIN -m site --user-base)/bin"
ensure_directory "$PYTHON_USER_BIN"
ensure_path_export "$PYTHON_USER_BIN"

info "Installing Ruby gems for language tooling..."
if command -v ruby >/dev/null 2>&1; then
    ruby_version="$(ruby -e 'require "rbconfig"; print RbConfig::CONFIG["ruby_version"]' 2>/dev/null || true)"
    if [[ -n "${ruby_version}" ]]; then
        GEM_BIN="$HOME/.gem/ruby/${ruby_version}/bin"
        ensure_directory "$GEM_BIN"
        ensure_path_export "$GEM_BIN"
    fi
    gem install --user-install bundler rspec rubocop solargraph readapt
fi

info "Configuring R packages..."
if command -v Rscript >/dev/null 2>&1; then
    Rscript -e 'packages <- c("languageserver", "httpgd", "jsonlite", "lintr", "styler", "testthat"); install_if_missing <- function(pkg) { if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg, repos = "https://cloud.r-project.org") }; invisible(lapply(packages, install_if_missing))'
fi

info "Setting up Elixir tooling..."
if command -v mix >/dev/null 2>&1; then
    mix local.hex --force
    mix local.rebar --force
    if [[ ! -x "$HOME/.local/bin/elixir-ls" ]]; then
        mix escript.install hex elixir_ls --force
        ln -sf "$HOME/.mix/escripts/elixir-ls" "$HOME/.local/bin/elixir-ls"
    fi
    ensure_path_export "$HOME/.mix/escripts"
fi

info "Setting up .NET language servers and tools..."
if command -v dotnet >/dev/null 2>&1; then
    dotnet tool update --global csharp-ls >/dev/null 2>&1 || dotnet tool install --global csharp-ls
    dotnet tool update --global fantomas >/dev/null 2>&1 || dotnet tool install --global fantomas
    ensure_path_export "$HOME/.dotnet/tools"
fi

info "Setting up Scala and Metals tooling via Coursier..."
if command -v cs >/dev/null 2>&1; then
    COURSIER_BIN_DIR="$HOME/.local/share/coursier/bin"
    ensure_directory "$COURSIER_BIN_DIR"
    cs install --install-dir "$COURSIER_BIN_DIR" metals scala-cli scalafmt
    ensure_path_export "$COURSIER_BIN_DIR"
fi

info "Installing Lean toolchain via elan..."
if ! command -v elan >/dev/null 2>&1; then
    curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y
fi
if [[ -f "$HOME/.elan/env" ]]; then
    # shellcheck disable=SC1090
    source "$HOME/.elan/env"
fi
ensure_path_export "$HOME/.elan/bin"

info "Installing Zig language toolchain..."
if ! command -v zig >/dev/null 2>&1; then
    brew install zig
fi

info "Ensuring database clients for vim-dadbod are installed..."
brew install postgresql mysql-client redis sqlite

info "Updating TeX Live packages required by vimtex..."
if command -v tlmgr >/dev/null 2>&1; then
    sudo tlmgr update --self
    sudo tlmgr install latexindent latexmk luatex
fi

info "Finalizing Homebrew maintenance..."
brew cleanup

cat <<'SUMMARY'
macOS language environment setup complete.
A new shell session is recommended so PATH updates take effect.
Installed languages and tooling cover: C/C++, CMake, Rust, Go, Python, Node.js, TypeScript, Bash, YAML, JSON, SQL, Markdown,
Ruby, R, Zig, Scala/Metals, Java/OpenJDK, .NET, Elixir, Lean, database clients, and TeX utilities for vimtex.
SUMMARY
