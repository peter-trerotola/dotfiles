#!/bin/bash
set -e

# =============================================================================
# Dotfiles Installation Script
# Supports: macOS, GitHub Codespaces (Linux), Ubuntu Server
# =============================================================================

# -----------------------------------------------------------------------------
# OS Detection
# -----------------------------------------------------------------------------
detect_os() {
  # GitHub Codespaces: Always use Homebrew (linux mode)
  if [ "$CODESPACES" = "true" ]; then
    echo "linux"
  elif [ "$(uname)" = "Darwin" ]; then
    echo "macos"
  elif [ -f "${OS_RELEASE_FILE:-/etc/os-release}" ]; then
    . "${OS_RELEASE_FILE:-/etc/os-release}"
    if [ "$ID" = "ubuntu" ]; then
      echo "ubuntu"
    else
      echo "linux"
    fi
  else
    echo "linux"
  fi
}

# Set OS_TYPE if not already set (allows tests to override)
# Only set at script execution time, not when sourced for testing
if [ -z "$OS_TYPE" ] && [ -z "$BATS_VERSION" ]; then
  OS_TYPE=$(detect_os)
  echo "Detected OS: $OS_TYPE"
fi

# -----------------------------------------------------------------------------
# Package Manager Installation
# -----------------------------------------------------------------------------
install_package_manager() {
  case $OS_TYPE in
    macos|linux)
      if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        export NONINTERACTIVE=1
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [ "$OS_TYPE" = "linux" ]; then
          test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
          test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
          echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc
          echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.zshrc
        fi
      else
        echo "Homebrew already installed"
      fi
      ;;
    ubuntu)
      echo "Using apt package manager"
      sudo apt-get update
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Package Installation
# -----------------------------------------------------------------------------
install_packages() {
  echo "Installing packages..."

  case $OS_TYPE in
    macos|linux)
      # Package list: "brew_package:command_name" (command_name optional if same as package)
      local brew_packages=(
        "rsync"
        "tmux"
        "btop"
        "ripgrep:rg"
        "zsh"
        "neovim:nvim"
        "lua-language-server"
        "bazel"
        "kubectl"
        "docker"
        "docker-compose"
        "golang:go"
        "gh"
        "sst/tap/opencode:opencode"
        "rainbarf"
      )

      local packages_to_install=""
      for entry in "${brew_packages[@]}"; do
        local pkg="${entry%%:*}"
        local cmd="${entry##*:}"
        # If no command specified, use package name
        [ "$pkg" = "$cmd" ] && cmd="$pkg"

        if command -v "$cmd" &> /dev/null; then
          echo "$pkg already installed"
        else
          packages_to_install+=" $pkg"
        fi
      done

      if [ -n "$packages_to_install" ]; then
        echo "Installing:$packages_to_install"
        # Install packages one at a time to avoid "broken pipe" errors
        # and to make failures easier to debug
        for pkg in $packages_to_install; do
          echo "Installing $pkg..."
          if brew install "$pkg"; then
            echo "$pkg installed successfully"
          else
            echo "Warning: Failed to install $pkg"
          fi
        done
      else
        echo "All brew packages already installed"
      fi

      # Claude Code CLI (cask)
      if ! brew list --cask claude-code &> /dev/null; then
        brew install --cask claude-code
      else
        echo "claude-code already installed"
      fi
      ;;
    ubuntu)
      # Core packages only (many dev tools not in default Ubuntu repos)
      # For full tooling, use Codespaces or install Homebrew
      sudo apt-get install -y rsync tmux btop ripgrep zsh neovim git curl
      # Optional: docker.io golang-go (if available in your Ubuntu version)
      # Note: kubectl, bazel, gh, and other tools require additional repos
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Go Installation (Ubuntu)
# -----------------------------------------------------------------------------
install_go_ubuntu() {
  if command -v go &> /dev/null; then
    echo "Go already installed: $(go version)"
    return
  fi

  echo "Installing Go from golang.org..."

  GO_VERSION="1.23.4"
  GO_ARCHIVE="go${GO_VERSION}.linux-amd64.tar.gz"
  GO_URL="https://go.dev/dl/${GO_ARCHIVE}"

  cd /tmp
  curl -LO "$GO_URL"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$GO_ARCHIVE"
  rm "$GO_ARCHIVE"

  export PATH=$PATH:/usr/local/go/bin
  echo "Go installed: $(go version)"
}

# -----------------------------------------------------------------------------
# Kubectl Installation (Ubuntu)
# -----------------------------------------------------------------------------
install_kubectl_ubuntu() {
  if command -v kubectl &> /dev/null; then
    echo "kubectl already installed: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
    return
  fi

  echo "Installing kubectl..."

  cd /tmp
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl

  echo "kubectl installed"
}

# -----------------------------------------------------------------------------
# Docker Installation (Ubuntu)
# -----------------------------------------------------------------------------
install_docker_ubuntu() {
  if command -v docker &> /dev/null; then
    echo "Docker already installed: $(docker --version)"
    return
  fi

  echo "Installing Docker..."

  # Install from Ubuntu repos
  sudo apt-get install -y docker.io

  # Add user to docker group
  sudo usermod -aG docker $USER || true

  echo "Docker installed"
}

# -----------------------------------------------------------------------------
# Docker Compose Installation (Ubuntu)
# -----------------------------------------------------------------------------
install_docker_compose_ubuntu() {
  if command -v docker-compose &> /dev/null; then
    echo "docker-compose already installed: $(docker-compose --version)"
    return
  fi

  echo "Installing docker-compose..."

  COMPOSE_VERSION="2.32.4"
  cd /tmp
  curl -L "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o docker-compose
  sudo install -o root -g root -m 0755 docker-compose /usr/local/bin/docker-compose
  rm docker-compose

  echo "docker-compose installed"
}

# -----------------------------------------------------------------------------
# Lua Language Server Installation (Ubuntu)
# -----------------------------------------------------------------------------
install_lua_language_server_ubuntu() {
  if command -v lua-language-server &> /dev/null; then
    echo "lua-language-server already installed"
    return
  fi

  echo "Installing lua-language-server..."

  LUA_LS_VERSION="3.13.5"
  cd /tmp
  curl -L "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LS_VERSION}/lua-language-server-${LUA_LS_VERSION}-linux-x64.tar.gz" -o lua-ls.tar.gz
  sudo mkdir -p /usr/local/lua-language-server
  sudo tar -C /usr/local/lua-language-server -xzf lua-ls.tar.gz
  sudo ln -sf /usr/local/lua-language-server/bin/lua-language-server /usr/local/bin/lua-language-server
  rm lua-ls.tar.gz

  echo "lua-language-server installed"
}

# -----------------------------------------------------------------------------
# Additional Tools Setup
# -----------------------------------------------------------------------------
setup_additional_tools() {
  echo "Setting up additional tools..."

  # Install dev tools on Ubuntu (not in default repos)
  if [ "$OS_TYPE" = "ubuntu" ]; then
    install_go_ubuntu
    install_kubectl_ubuntu
    install_docker_ubuntu
    install_docker_compose_ubuntu
    install_lua_language_server_ubuntu
  fi

  # Tmux Plugin Manager
  if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  fi

  # NvChad
  if [ ! -d ~/.config/nvim ]; then
    git clone https://github.com/NvChad/starter ~/.config/nvim
  fi


  # Tailscale (optional, only if not already installed)
  if ! command -v tailscale &> /dev/null; then
    echo "Tailscale not found. Skipping installation (optional)."
  fi

  # Oh My Zsh
  if [ ! -d ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi
}

# -----------------------------------------------------------------------------
# Claude Code Settings (from CLAUDE_CONFIG env var)
# -----------------------------------------------------------------------------
apply_claude_config() {
  if [ -n "${CLAUDE_CONFIG}" ]; then
    echo "Applying CLAUDE_CONFIG env var to $HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
    echo "$CLAUDE_CONFIG" > "$HOME/.claude/settings.json"
  fi
}

# -----------------------------------------------------------------------------
# Config Files Installation
# -----------------------------------------------------------------------------
install_config_files() {
  echo "Installing configuration files..."

  cp .zshrc ~/ && \
    cp .tmux.conf ~/ && \
    rsync -av config/* ~/.config/

  echo "Configuration files installed"
}

# -----------------------------------------------------------------------------
# Shell Setup
# -----------------------------------------------------------------------------
setup_shell() {
  echo "Setting default shell to zsh..."

  if [ "$SHELL" != "$(which zsh)" ]; then
    if [ "$OS_TYPE" = "macos" ]; then
      chsh -s "$(which zsh)"
    else
      sudo chsh "$(id -un)" --shell "$(which zsh)"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Legacy Environment Variable Support
# -----------------------------------------------------------------------------
setup_legacy_env_vars() {
  # Snowflake configuration
  if [ ! -z "${SNOWFLAKE_PRIVATE_KEY}" ] && [ ! -z "${SNOWFLAKE_CLI_CONFIG}" ]; then
    echo "Setting up Snowflake config & private key"
    mkdir -p ~/.keys ~/.snowflake
    echo "$SNOWFLAKE_PRIVATE_KEY" > ~/.keys/snowflake_private_key.pem
    chmod 600 ~/.keys/snowflake_private_key.pem
    echo "$SNOWFLAKE_CLI_CONFIG" > ~/.snowflake/config.toml
  fi

  # JFrog npm configuration
  if [ ! -z "${JFROG_AUTH}" ] && [ ! -z "${JFROG_URL}" ]; then
    echo "Setting up JFrog npm configuration..."
    curl -u $JFROG_AUTH "$JFROG_URL" > ~/.npmrc

    # Create .netrc from .npmrc values
    echo "Setting up .netrc from .npmrc..."
    local jfrog_host=$(grep -oP '//\K[^/]+' ~/.npmrc | head -1)
    local jfrog_user=$(grep ':username=' ~/.npmrc | head -1 | sed 's/.*:username=//')
    local jfrog_pass=$(grep ':_password=' ~/.npmrc | head -1 | sed 's/.*:_password=//')

    cat > ~/.netrc <<EOF
machine $jfrog_host
    login $jfrog_user
    password $jfrog_pass
EOF
    chmod 600 ~/.netrc

    echo "JFrog npm and netrc configuration complete"
  fi
}

# -----------------------------------------------------------------------------
# Main Installation Flow
# -----------------------------------------------------------------------------
main() {
  echo "============================================="
  echo "Dotfiles Installation"
  echo "============================================="

  install_package_manager
  install_packages
  setup_additional_tools
  install_config_files
  setup_shell

  # Apply Claude Code settings from env var
  apply_claude_config

  # Legacy environment variable support
  setup_legacy_env_vars

  echo ""
  echo "============================================="
  echo "Installation complete!"
  echo "Please restart your shell or run: source ~/.zshrc"
  echo "============================================="
}

# Only run main if not being sourced (for testing)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
