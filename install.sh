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
      # Core packages
      brew install rsync tmux btop ripgrep zsh neovim lua-language-server
      # Additional packages (previously work-specific, now always installed)
      brew install bazel kubectl docker docker-compose golang gh sst/tap/opencode
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

# Main sync function - syncs all repos under CODE_PATH
sync_claude() {
  # Validate CODE_PATH is set
  if [ -z "$CODE_PATH" ]; then
    echo "ERROR: CODE_PATH environment variable is not set"
    echo "Set CODE_PATH to your workspace directory (e.g., ~/Code, ~/Work, /workspaces)"
    return 1
  fi

  # Validate CLAUDE_REPO is set
  if [ -z "$CLAUDE_REPO" ]; then
    echo "ERROR: CLAUDE_REPO environment variable is not set"
    echo "Set CLAUDE_REPO to your Claude configuration repository URL"
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
  echo "CODE_PATH: ${CODE_PATH:-not set}"
  echo "CLAUDE_REPO: ${CLAUDE_REPO:-not set}"
  echo "============================================="

  # Validate CODE_PATH is set
  if [ -z "$CODE_PATH" ]; then
    echo ""
    echo "ERROR: CODE_PATH environment variable must be set"
    echo "Set CODE_PATH to your workspace directory:"
    echo "  - Personal laptop: export CODE_PATH=~/Code"
    echo "  - Work laptop: export CODE_PATH=~/Work"
    echo "  - Codespaces: export CODE_PATH=/workspaces"
    echo ""
    exit 1
  fi

  install_package_manager
  install_packages
  setup_additional_tools
  install_config_files
  setup_shell

  # Sync Claude configurations to all repos under CODE_PATH
  sync_claude

  # Legacy environment variable support
  setup_legacy_env_vars

  echo ""
  echo "============================================="
  echo "Installation complete!"
  echo "Please restart your shell or run: source ~/.zshrc"
  echo "To sync Claude configs later, run: sync-claude"
  echo "============================================="
}

# Only run main if not being sourced (for testing)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main
fi
