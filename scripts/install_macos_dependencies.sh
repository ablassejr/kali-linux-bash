#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This installer targets macOS systems only." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/common.sh"
if [[ -f "$COMMON_SH" ]]; then
    # shellcheck disable=SC1090
    source "$COMMON_SH"
fi

ensure_homebrew() {
    if command -v brew &>/dev/null; then
        return
    fi

    echo "Homebrew not found. Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

add_brew_to_path() {
    if command -v brew &>/dev/null; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
}

install_formula() {
    local pkg="$1"
    if brew list --formula "$pkg" &>/dev/null; then
        echo "✔ brew formula '${pkg}' already installed"
    else
        echo "➜ Installing brew formula '${pkg}'..."
        brew install "$pkg"
    fi
}

install_cask() {
    local cask="$1"
    if brew list --cask "$cask" &>/dev/null; then
        echo "✔ brew cask '${cask}' already installed"
    else
        echo "➜ Installing brew cask '${cask}'..."
        brew install --cask "$cask"
    fi
}

run_pip_command() {
    local -a args=("$@")
    local pip_output

    if pip_output=$(python3 -m pip "${args[@]}" 2>&1); then
        printf '%s\n' "$pip_output"
        return 0
    fi

    local status=$?
    printf '%s\n' "$pip_output" >&2

    if [[ "$pip_output" == *"externally managed"* ]]; then
        echo "Detected externally managed Python environment; retrying with --break-system-packages." >&2
        python3 -m pip "${args[@]}" --break-system-packages
        return $?
    fi

    return $status
}

pip_install() {
    local package="$1"
    if python3 -m pip show "$package" &>/dev/null; then
        echo "✔ Python package '${package}' already installed"
    else
        echo "➜ Installing Python package '${package}'..."
        run_pip_command install --user "$package"
    fi
}

npm_install() {
    local package="$1"
    if npm list -g --depth=0 "$package" &>/dev/null; then
        echo "✔ npm package '${package}' already installed"
    else
        echo "➜ Installing npm package '${package}'..."
        npm install -g "$package"
    fi
}

gem_install() {
    local package="$1"
    if gem list -i "$package" &>/dev/null; then
        echo "✔ Ruby gem '${package}' already installed"
    else
        echo "➜ Installing Ruby gem '${package}'..."
        if gem install "$package"; then
            return
        fi

        echo "First attempt to install '${package}' failed; retrying with --user-install." >&2
        if gem install --user-install "$package"; then
            return
        fi

        return $?
    fi
}

go_install() {
    local package="$1"
    local binary_name="$2"
    if command -v "$binary_name" &>/dev/null; then
        echo "✔ Go tool '${binary_name}' already installed"
    else
        echo "➜ Installing Go tool '${binary_name}'..."
        GO111MODULE=on go install "$package"
    fi
}

cargo_install() {
    local package="$1"
    local binary_name="$2"
    if command -v "$binary_name" &>/dev/null; then
        echo "✔ Cargo binary '${binary_name}' already installed"
    else
        echo "➜ Installing Cargo binary '${binary_name}'..."
        cargo install "$package"
    fi
}

install_r_packages() {
    local -a packages=("languageserver" "lintr" "styler" "testthat" "jsonlite" "httpgd")
    if ! command -v Rscript &>/dev/null; then
        echo "Rscript not found; skipping CRAN package installation." >&2
        return
    fi

    echo "➜ Installing CRAN packages: ${packages[*]}"
    Rscript -e 'pkgs <- commandArgs(trailingOnly = TRUE); missing <- setdiff(pkgs, installed.packages()[,"Package"]); if (length(missing)) install.packages(missing, repos="https://cloud.r-project.org");' "${packages[@]}"
}

configure_r_testthat() {
    if ! command -v Rscript &>/dev/null; then
        return
    fi

    Rscript -e 'if (!requireNamespace("testthat", quietly = TRUE)) install.packages("testthat", repos="https://cloud.r-project.org")'
}

install_rust_toolchain() {
    if command -v rustup &>/dev/null; then
        echo "✔ rustup already installed"
    else
        echo "➜ Installing rustup toolchain manager..."
        rustup-init -y --no-modify-path
    fi

    if [[ -f "$HOME/.cargo/env" ]]; then
        # shellcheck disable=SC1090
        source "$HOME/.cargo/env"
    fi

    echo "➜ Ensuring Rust stable toolchain and components..."
    rustup default stable
    rustup component add rust-analyzer rustfmt clippy
}

install_coursier_tools() {
    if ! command -v cs &>/dev/null; then
        echo "Coursier is not available; skipping Scala language server setup." >&2
        return
    fi

    echo "➜ Installing Metals and Bloop via coursier..."
    cs install --only-prebuilt metals bloop scala-cli
}

install_lean_toolchain() {
    if command -v elan &>/dev/null; then
        echo "✔ elan (Lean toolchain manager) already installed"
    else
        echo "➜ Installing elan for Lean language support..."
        curl -fsSL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y
    fi
}

install_tex_support() {
    local tlmgr_path="/Library/TeX/texbin/tlmgr"
    if [[ ! -x "$tlmgr_path" ]]; then
        echo "tlmgr not found; ensure BasicTeX is installed before installing LaTeX packages." >&2
        return
    fi

    echo "➜ Installing LaTeX dependencies via tlmgr..."
    sudo "$tlmgr_path" install latexmk latexindent-bin
}

configure_shell_paths() {
    if ! declare -f append_if_missing >/dev/null; then
        return
    fi

    local target_user
    target_user=$(get_target_user)
    local home_dir
    home_dir=$(get_home_dir "$target_user")
    local ruby_version=""
    local gem_user_bin=""
    if command -v ruby &>/dev/null; then
        ruby_version=$(ruby -rrbconfig -e 'print RbConfig::CONFIG["ruby_version"]' 2>/dev/null || true)
        if [[ -n "$ruby_version" ]]; then
            gem_user_bin="$home_dir/.gem/ruby/$ruby_version/bin"
        fi
    fi
    local -a shell_files=("$home_dir/.zshrc" "$home_dir/.bash_profile")
    local -a path_entries=(
        'export PATH="$HOME/.cargo/bin:$PATH"'
        'export PATH="$HOME/.dotnet/tools:$PATH"'
        'export PATH="$HOME/.elan/bin:$PATH"'
        'export PATH="/Library/TeX/texbin:$PATH"'
        'export PATH="$HOME/Library/Python/3.11/bin:$PATH"'
        'export PATH="$HOME/.local/bin:$PATH"'
        'export PATH="$HOME/go/bin:$PATH"'
        'export PATH="$HOME/.local/share/coursier/bin:$PATH"'
        'export PATH="$HOME/Library/Application Support/Coursier/bin:$PATH"'
    )

    if [[ -n "$gem_user_bin" ]]; then
        local gem_path_entry
        printf -v gem_path_entry 'export PATH="%s:$%s"' "$gem_user_bin" "PATH"
        path_entries+=("$gem_path_entry")
    fi

    for shell_file in "${shell_files[@]}"; do
        for entry in "${path_entries[@]}"; do
            append_if_missing "$shell_file" "$entry" "$entry"
        done
    done
}

prepare_gem_environment() {
    if ! command -v ruby &>/dev/null; then
        return
    fi

    if [[ -n "${GEM_HOME:-}" && -n "${GEM_PATH:-}" ]]; then
        return
    fi

    local ruby_version
    ruby_version=$(ruby -rrbconfig -e 'print RbConfig::CONFIG["ruby_version"]' 2>/dev/null || true)
    if [[ -z "$ruby_version" ]]; then
        return
    fi

    local user_gem_dir="$HOME/.gem/ruby/$ruby_version"
    local default_gem_dir
    default_gem_dir=$(ruby -rrubygems -e 'print Gem.default_dir' 2>/dev/null || true)
    mkdir -p "$user_gem_dir"
    export GEM_HOME="${GEM_HOME:-$user_gem_dir}"
    if [[ -n "${GEM_PATH:-}" ]]; then
        :
    elif [[ -n "$default_gem_dir" ]]; then
        export GEM_PATH="$user_gem_dir:$default_gem_dir"
    else
        export GEM_PATH="$user_gem_dir"
    fi
    export PATH="$user_gem_dir/bin:$PATH"
}

ensure_homebrew
add_brew_to_path

brew update

brew tap clojure/tools || true
brew tap coursier/formulas || true
brew tap zigtools/zls || true

BREW_FORMULAE=(
    "git"
    "curl"
    "wget"
    "python@3.11"
    "node"
    "yarn"
    "go"
    "rustup-init"
    "zig"
    "zls"
    "cmake"
    "ninja"
    "pkg-config"
    "llvm"
    "r"
    "openjdk"
    "scala"
    "sbt"
    "elixir"
    "erlang"
    "ghc"
    "cabal-install"
    "stack"
    "chezmoi"
    "helm"
    "pandoc"
    "sqlite"
    "gh"
    "ripgrep"
    "fzf"
    "stylua"
    "shellcheck"
    "shfmt"
    "leiningen"
    "clojure"
)

for formula in "${BREW_FORMULAE[@]}"; do
    install_formula "$formula"
done

BREW_CASKS=(
    "basictex"
    "dotnet-sdk"
)

for cask in "${BREW_CASKS[@]}"; do
    install_cask "$cask"
done

add_brew_to_path

PYTHON_BIN="$(command -v python3 || true)"
if [[ -n "$PYTHON_BIN" ]]; then
    echo "➜ Upgrading pip in user site-packages (when possible)..."
    if ! run_pip_command install --upgrade --user pip; then
        echo "Skipping pip upgrade because the environment is managed externally." >&2
    fi
fi

PYTHON_PACKAGES=(
    "pynvim"
    "debugpy"
    "ansible"
    "ansible-lint"
    "black"
    "isort"
    "mypy"
    "flake8"
    "ruff"
    "python-lsp-server"
    "radian"
)

for package in "${PYTHON_PACKAGES[@]}"; do
    pip_install "$package"
done

NPM_PACKAGES=(
    "neovim"
    "pyright"
    "typescript"
    "typescript-language-server"
    "eslint"
    "eslint_d"
    "prettier"
    "bash-language-server"
    "yaml-language-server"
    "dockerfile-language-server-nodejs"
    "vscode-langservers-extracted"
    "@ansible/ansible-language-server"
    "@tailwindcss/language-server"
    "svelte-language-server"
    "graphql-language-service-cli"
    "markdownlint-cli"
)

for package in "${NPM_PACKAGES[@]}"; do
    npm_install "$package"
done

prepare_gem_environment

if command -v gem &>/dev/null; then
    if ! gem update --system; then
        echo "Skipping 'gem update --system' due to insufficient permissions. Consider running it manually with elevated privileges." >&2
    fi
fi

RUBY_GEMS=(
    "bundler"
    "solargraph"
    "readapt"
    "rubocop"
    "neovim"
)

for gem_pkg in "${RUBY_GEMS[@]}"; do
    gem_install "$gem_pkg"
done

install_rust_toolchain

if command -v cargo &>/dev/null; then
    cargo_install "taplo-cli" "taplo"
    cargo_install "stylua" "stylua"
fi

if command -v go &>/dev/null; then
    go_install "github.com/go-delve/delve/cmd/dlv@latest" "dlv"
    go_install "github.com/golangci/golangci-lint/cmd/golangci-lint@latest" "golangci-lint"
fi

install_coursier_tools
install_lean_toolchain
install_tex_support
install_r_packages
configure_r_testthat

if command -v stack &>/dev/null; then
    echo "➜ Ensuring Haskell tooling via stack..."
    stack setup
    stack install hoogle hasktags
fi

if command -v dotnet &>/dev/null; then
    if ! dotnet tool list --global | grep -q "csharp-ls"; then
        echo "➜ Installing csharp-ls via dotnet tool..."
        dotnet tool install --global csharp-ls
    else
        echo "✔ csharp-ls already installed"
    fi
fi

if command -v tlmgr &>/dev/null; then
    install_tex_support
else
    echo "Install BasicTeX and ensure tlmgr is on PATH to complete LaTeX setup for vimtex." >&2
fi

if command -v npm &>/dev/null; then
    corepack enable || true
fi

configure_shell_paths

echo "\nAll requested macOS language and tooling dependencies have been processed."
