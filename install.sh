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

  # Powerline-go (requires Go or downloads pre-built binary)
  if ! command -v powerline-go &> /dev/null; then
    echo "Installing powerline-go..."

    # Try compiling from source with Go first
    if command -v go &> /dev/null; then
      if go install github.com/justjanne/powerline-go@latest 2>&1 | tee /tmp/powerline-go-install.log | grep -q "powerline-go"; then
        if command -v powerline-go &> /dev/null; then
          echo "powerline-go installed successfully from source"
        else
          echo "Go install appeared to succeed but powerline-go not found, trying pre-built binary..."
          COMPILE_FAILED=true
        fi
      else
        echo "Go compilation failed, trying pre-built binary..."
        COMPILE_FAILED=true
      fi
    else
      echo "Go not available, trying pre-built binary..."
      COMPILE_FAILED=true
    fi

    # Fallback: Download pre-built binary
    if [ "$COMPILE_FAILED" = "true" ] || ! command -v powerline-go &> /dev/null; then
      echo "Downloading pre-built powerline-go binary..."
      POWERLINE_VERSION="v1.24"
      POWERLINE_URL="https://github.com/justjanne/powerline-go/releases/download/${POWERLINE_VERSION}/powerline-go-linux-amd64"

      mkdir -p ~/bin
      if curl -fL "$POWERLINE_URL" -o ~/bin/powerline-go; then
        chmod +x ~/bin/powerline-go

        # Add ~/bin to PATH in shell configs if not already there
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.zshrc; then
          echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
        fi
        if ! grep -q 'export PATH="$HOME/bin:$PATH"' ~/.bashrc; then
          echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        fi

        export PATH="$HOME/bin:$PATH"
        echo "powerline-go installed successfully from pre-built binary"
      else
        echo "WARNING: Failed to download powerline-go (non-fatal)"
        echo "The dotfiles will work without powerline-go, but the prompt won't be enhanced"
      fi
    fi
  else
    echo "powerline-go already installed"
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
# Claude Configuration with CODE_PATH-based Syncing
# -----------------------------------------------------------------------------
CLAUDE_REPO="${CLAUDE_REPO:-}"  # Set via environment variable
CLAUDE_CLONE_DIR="$HOME/.dotfiles-claude-configs"

clone_or_update_claude_repo() {
  echo "Fetching Claude configurations..."

  if [ -d "$CLAUDE_CLONE_DIR" ]; then
    echo "Updating existing Claude config repository..."
    git -C "$CLAUDE_CLONE_DIR" pull
  else
    echo "Cloning Claude config repository..."

    # In Codespaces, use gh CLI for authenticated cloning (supports private repos)
    # But only for GitHub URLs (not file:// or other protocols)
    if [ "$CODESPACES" = "true" ] && command -v gh &> /dev/null && [[ ! "$CLAUDE_REPO" =~ ^file:// ]]; then
      # Extract repo from various URL formats
      local repo_path="$CLAUDE_REPO"
      # Convert git@github.com:user/repo.git to user/repo
      repo_path="${repo_path#git@github.com:}"
      # Convert https://github.com/user/repo.git to user/repo
      repo_path="${repo_path#https://github.com/}"
      # Remove .git suffix
      repo_path="${repo_path%.git}"

      echo "Using gh CLI for authenticated clone in Codespaces..."
      if ! gh repo clone "$repo_path" "$CLAUDE_CLONE_DIR"; then
        echo "ERROR: Failed to clone Claude config repository with gh CLI"
        echo "Repository: $repo_path"
        return 1
      fi
    else
      # Non-Codespaces or file:// URL: use regular git clone
      if ! git clone "$CLAUDE_REPO" "$CLAUDE_CLONE_DIR"; then
        echo "ERROR: Failed to clone Claude config repository"
        echo "Repository URL: $CLAUDE_REPO"
        if [[ "$CLAUDE_REPO" =~ ^git@ ]]; then
          echo "Tip: SSH URLs require SSH keys. Use HTTPS URLs or configure SSH keys."
        fi
        return 1
      fi
    fi
  fi
}

# Process template file by substituting environment variables
process_template() {
  local template_file="$1"
  local output_file="$2"

  # Use envsubst if available, otherwise use a simple sed approach
  if command -v envsubst &> /dev/null; then
    envsubst < "$template_file" > "$output_file"
  else
    # Simple variable substitution (handles ${VAR} format)
    eval "cat <<EOF
$(<"$template_file")
EOF
" > "$output_file"
  fi
}

# Sync a directory component with fallback to default
sync_claude_component() {
  local component_name="$1"  # e.g., "agents", "commands", "skills"
  local repo_name="$2"       # e.g., "central" or "default"
  local target_base="$3"     # Target base directory (e.g., ~/.claude or ~/Code/central/.claude)

  local repo_specific_path="$CLAUDE_CLONE_DIR/$repo_name/$component_name"
  local default_path="$CLAUDE_CLONE_DIR/default/$component_name"
  local target_path="$target_base/$component_name"

  # Determine source: repo-specific or default
  local source_path=""
  if [ -d "$repo_specific_path" ]; then
    source_path="$repo_specific_path"
    echo "    Using repo-specific $component_name for $repo_name"
  elif [ -d "$default_path" ]; then
    source_path="$default_path"
    echo "    Using default $component_name"
  else
    echo "    Skipping $component_name (not found)"
    return
  fi

  # Sync to target
  mkdir -p "$target_path"
  rsync -av --delete "$source_path/" "$target_path/" > /dev/null
}

# Sync a single file component with fallback to default
sync_claude_file() {
  local file_name="$1"        # e.g., "CLAUDE.md" or "settings.json.template"
  local repo_name="$2"        # e.g., "central" or "default"
  local is_template="$3"      # "true" if needs template processing
  local target_base="$4"      # Target base directory

  local repo_specific_file="$CLAUDE_CLONE_DIR/$repo_name/$file_name"
  local default_file="$CLAUDE_CLONE_DIR/default/$file_name"
  local target_file="$target_base/${file_name%.template}"

  # Determine source: repo-specific or default
  local source_file=""
  if [ -f "$repo_specific_file" ]; then
    source_file="$repo_specific_file"
    echo "    Using repo-specific $file_name for $repo_name"
  elif [ -f "$default_file" ]; then
    source_file="$default_file"
    echo "    Using default $file_name"
  else
    echo "    Skipping $file_name (not found)"
    return
  fi

  # Ensure target directory exists
  mkdir -p "$(dirname "$target_file")"

  # Copy or process template
  if [ "$is_template" = "true" ]; then
    process_template "$source_file" "$target_file"
  else
    cp "$source_file" "$target_file"
  fi
}

# Sync Claude config for a single repo
sync_repo_claude_config() {
  local repo_path="$1"
  local repo_name=$(basename "$repo_path")
  local claude_dir="$repo_path/.claude"

  echo "  Syncing Claude config for: $repo_name"

  mkdir -p "$claude_dir"

  # Sync components with layered fallback
  sync_claude_file "settings.json.template" "$repo_name" "true" "$claude_dir"
  sync_claude_file "CLAUDE.md" "$repo_name" "false" "$claude_dir"
  sync_claude_component "agents" "$repo_name" "$claude_dir"
  sync_claude_component "commands" "$repo_name" "$claude_dir"
  sync_claude_component "skills" "$repo_name" "$claude_dir"
  sync_claude_component "hooks" "$repo_name" "$claude_dir"
  sync_claude_component "output-styles" "$repo_name" "$claude_dir"
}

# Apply CLAUDE_CONFIG if set (independent of CLAUDE_REPO)
apply_claude_config() {
  if [ -n "${CLAUDE_CONFIG}" ]; then
    echo "Applying CLAUDE_CONFIG env var to $HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
    echo "$CLAUDE_CONFIG" > "$HOME/.claude/settings.json"
  fi
}

# Main sync function - syncs all repos under CODE_PATH
sync_claude() {
  # Skip if CLAUDE_REPO is not set (Claude sync is optional)
  if [ -z "$CLAUDE_REPO" ]; then
    echo "Skipping Claude sync (CLAUDE_REPO not set)"
    return 0
  fi

  # Validate CODE_PATH is set when CLAUDE_REPO is provided
  if [ -z "$CODE_PATH" ]; then
    echo "ERROR: CODE_PATH environment variable is not set"
    echo "Set CODE_PATH to your workspace directory (e.g., ~/Code, ~/Work, /workspaces)"
    return 1
  fi

  # Validate CODE_PATH exists
  if [ ! -d "$CODE_PATH" ]; then
    echo "ERROR: CODE_PATH directory does not exist: $CODE_PATH"
    return 1
  fi

  echo "Syncing Claude configurations..."
  echo "CODE_PATH: $CODE_PATH"
  echo "CLAUDE_REPO: $CLAUDE_REPO"

  # Clone or update the Claude config repository
  clone_or_update_claude_repo

  # Sync default config to $HOME/.claude
  echo ""
  echo "  Syncing default config to $HOME/.claude"
  mkdir -p "$HOME/.claude"
  sync_claude_file "settings.json.template" "default" "true" "$HOME/.claude"
  sync_claude_file "CLAUDE.md" "default" "false" "$HOME/.claude"
  sync_claude_component "agents" "default" "$HOME/.claude"
  sync_claude_component "commands" "default" "$HOME/.claude"
  sync_claude_component "skills" "default" "$HOME/.claude"
  sync_claude_component "hooks" "default" "$HOME/.claude"
  sync_claude_component "output-styles" "default" "$HOME/.claude"

  # Iterate through all repos under CODE_PATH
  echo ""
  echo "Syncing repo-specific configs..."
  for repo_dir in "$CODE_PATH"/*; do
    if [ -d "$repo_dir" ]; then
      sync_repo_claude_config "$repo_dir"
    fi
  done

  echo ""
  echo "Claude Code configuration complete!"
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
  echo "CODE_PATH: ${CODE_PATH:-not set}"
  echo "CLAUDE_REPO: ${CLAUDE_REPO:-not set}"
  echo "============================================="

  install_package_manager
  install_packages
  setup_additional_tools
  install_config_files
  setup_shell

  # Sync Claude configurations (optional - only if CLAUDE_REPO is set)
  sync_claude

  # Apply CLAUDE_CONFIG if set (independent of CLAUDE_REPO)
  apply_claude_config

  # Legacy environment variable support
  setup_legacy_env_vars

  echo ""
  echo "============================================="
  echo "Installation complete!"
  echo "Please restart your shell or run: source ~/.zshrc"
  if [ ! -z "$CLAUDE_REPO" ]; then
    echo "To sync Claude configs later, run: sync-claude"
  fi
  echo "============================================="
}

# Only run main if not being sourced (for testing)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
