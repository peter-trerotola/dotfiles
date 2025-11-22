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
  if [ "$(uname)" = "Darwin" ]; then
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
install_core_packages() {
  echo "Installing core packages..."

  case $OS_TYPE in
    macos|linux)
      brew install rsync tmux btop ripgrep zsh neovim lua-language-server
      ;;
    ubuntu)
      sudo apt-get install -y rsync tmux btop ripgrep zsh neovim lua-language-server git curl
      ;;
  esac
}

install_repo_specific_packages() {
  echo "Installing repo-specific packages for: $CONFIG_MODE"

  # Check if this is a work-related config
  # Set WORK_ORG_PATTERN to match your work organization (e.g., "work-org/*")
  local work_pattern="${WORK_ORG_PATTERN:-__no_match__}"

  if [[ "$CONFIG_MODE" == $work_pattern ]]; then
    case $OS_TYPE in
      macos|linux)
        brew install bazel kubectl docker docker-compose golang gh sst/tap/opencode
        ;;
      ubuntu)
        sudo apt-get install -y kubectl docker.io docker-compose golang-go
        # Note: Bazel and other tools may need manual installation on Ubuntu
        ;;
    esac
  fi
}

# -----------------------------------------------------------------------------
# Additional Tools Setup
# -----------------------------------------------------------------------------
setup_additional_tools() {
  echo "Setting up additional tools..."

  # Tmux Plugin Manager
  if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  fi

  # NvChad
  if [ ! -d ~/.config/nvim ]; then
    git clone https://github.com/NvChad/starter ~/.config/nvim
  fi

  # Powerline-go (requires Go)
  if command -v go &> /dev/null; then
    go install github.com/justjanne/powerline-go@latest
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
# Claude Configuration with Layered Fallback
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
    git clone "$CLAUDE_REPO" "$CLAUDE_CLONE_DIR"
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
  local config_path="$2"      # e.g., "VideoAmp/central" or "default"

  local repo_specific_path="$CLAUDE_CLONE_DIR/$config_path/$component_name"
  local default_path="$CLAUDE_CLONE_DIR/default/$component_name"
  local target_path="$HOME/.claude/$component_name"

  # Determine source: repo-specific or default
  local source_path=""
  if [ -d "$repo_specific_path" ]; then
    source_path="$repo_specific_path"
    echo "  Using repo-specific $component_name from $config_path"
  elif [ -d "$default_path" ]; then
    source_path="$default_path"
    echo "  Using default $component_name (not found in $config_path)"
  else
    echo "  Skipping $component_name (not found in repo-specific or default)"
    return
  fi

  # Sync to target
  # Note: Using --delete to ensure clean sync. Any local-only files will be removed.
  # To keep local files, remove them from ~/.claude/ and add to .gitignore in the private repo
  mkdir -p "$target_path"
  rsync -av --delete "$source_path/" "$target_path/"
}

# Sync a single file component with fallback to default
sync_claude_file() {
  local file_name="$1"        # e.g., "CLAUDE.md"
  local config_path="$2"      # e.g., "VideoAmp/central" or "default"
  local is_template="$3"      # "true" if needs template processing

  local repo_specific_file="$CLAUDE_CLONE_DIR/$config_path/$file_name"
  local default_file="$CLAUDE_CLONE_DIR/default/$file_name"
  local target_file="$HOME/.claude/${file_name%.template}"

  # Determine source: repo-specific or default
  local source_file=""
  if [ -f "$repo_specific_file" ]; then
    source_file="$repo_specific_file"
    echo "  Using repo-specific $file_name from $config_path"
  elif [ -f "$default_file" ]; then
    source_file="$default_file"
    echo "  Using default $file_name (not found in $config_path)"
  else
    echo "  Skipping $file_name (not found in repo-specific or default)"
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

setup_claude_config() {
  local config_path="${CONFIG_MODE:-default}"

  # Skip if CLAUDE_REPO is not set
  if [ -z "$CLAUDE_REPO" ]; then
    echo "Skipping Claude Code configuration (CLAUDE_REPO not set)"
    return 0
  fi

  echo "Setting up Claude Code configuration for: $config_path"

  # Clone or update the Claude config repository
  clone_or_update_claude_repo

  # Verify the config path exists (at least as an empty directory)
  if [ ! -d "$CLAUDE_CLONE_DIR/$config_path" ] && [ "$config_path" != "default" ]; then
    echo "WARNING: Config path '$config_path' not found in Claude repo. Falling back to default."
    config_path="default"
  fi

  # Create .claude directory
  mkdir -p ~/.claude

  # Sync components with layered fallback
  echo "Syncing Claude Code components..."

  # Settings (template processing required)
  sync_claude_file "settings.json.template" "$config_path" "true"

  # CLAUDE.md (optional, no template processing)
  sync_claude_file "CLAUDE.md" "$config_path" "false"

  # Directory components
  sync_claude_component "agents" "$config_path"
  sync_claude_component "commands" "$config_path"
  sync_claude_component "skills" "$config_path"
  sync_claude_component "hooks" "$config_path"
  sync_claude_component "output-styles" "$config_path"

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
  # Legacy CLAUDE_CONFIG support (backward compatibility)
  if [ ! -z "${CLAUDE_CONFIG}" ]; then
    echo "Setting up legacy Claude config from CLAUDE_CONFIG env var"
    mkdir -p ~/.claude
    echo "$CLAUDE_CONFIG" > ~/.claude/settings.json
  fi

  # Snowflake configuration
  if [ ! -z "${SNOWFLAKE_PRIVATE_KEY}" ] && [ ! -z "${SNOWFLAKE_CLI_CONFIG}" ]; then
    echo "Setting up Snowflake config & private key"
    mkdir -p ~/.keys ~/.snowflake
    echo "$SNOWFLAKE_PRIVATE_KEY" > ~/.keys/snowflake_private_key.pem
    chmod 600 ~/.keys/snowflake_private_key.pem
    echo "$SNOWFLAKE_CLI_CONFIG" > ~/.snowflake/config.toml
  fi
}

# -----------------------------------------------------------------------------
# Main Installation Flow
# -----------------------------------------------------------------------------
main() {
  echo "============================================="
  echo "Dotfiles Installation"
  echo "CONFIG_MODE: ${CONFIG_MODE:-default}"
  echo "============================================="

  install_package_manager
  install_core_packages

  # Install repo-specific packages if CONFIG_MODE is set
  if [ ! -z "$CONFIG_MODE" ] && [ "$CONFIG_MODE" != "default" ]; then
    install_repo_specific_packages
  fi

  setup_additional_tools
  install_config_files
  setup_shell

  # Setup Claude configuration (always run, uses default if CONFIG_MODE not set)
  setup_claude_config

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
