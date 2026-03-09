# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository for personal development environment configuration, designed to work on macOS, GitHub Codespaces (Linux), and Ubuntu Server.

## Installation and Setup

```bash
./install.sh

# With Claude Code settings via env var:
CLAUDE_CONFIG='{"key":"value"}' ./install.sh
```

### Package Installation

**Packages:**
- rsync, tmux, btop, ripgrep, zsh, neovim, lua-language-server
- bazel, kubectl, docker, docker-compose, golang, gh, and other development tools

**Platform support:**
- **macOS & Linux Codespaces**: Uses Homebrew for all packages
- **Ubuntu Server**: Uses apt package manager (some tools may require manual installation)

## Repository Structure

```
.
├── install.sh              # Main installation script
├── .zshrc                  # Zsh configuration
├── .tmux.conf              # Tmux configuration with plugins
├── CLAUDE.md               # This file
└── config/
    ├── nvim/               # Neovim configuration (NvChad-based)
    │   ├── init.lua        # Entry point for Neovim config
    │   └── lua/
    │       ├── configs/    # LSP and tool configurations
    │       └── plugins/    # Plugin configurations
    ├── btop/               # btop system monitor configuration
    └── tmux-powerline/     # tmux-powerline theme and segments
        ├── config.sh       # Powerline settings
        ├── themes/         # Custom themes
        └── segments/       # Custom segments
```

## Key Configurations

### Zsh Configuration
- Theme: robbyrussell
- Uses powerline-go for enhanced prompt
- Oh My Zsh with all plugins loaded

**Plugins (always loaded):** git, brew, vi-mode, bazel, docker, docker-compose, gh, golang, kubectl

**Aliases:**
- `vim` → `nvim`

### Neovim Setup
- Based on **NvChad v2.5** (imported as a plugin)
- Uses **lazy.nvim** for plugin management
- LSP servers configured: HTML, Bash, Protocol Buffers, Bazel (bzl), gopls
- Format-on-save enabled via `conform.nvim`
- File tree width set to 60 characters

### Tmux Configuration
- Mouse mode enabled
- Vi mode for copy/paste and status keys
- Plugins: tpm, tmux-sensible, tmux-powerline, tmux-resurrect, tmux-continuum
- Session resurrection enabled for Neovim

## Making Changes

### Modifying Configuration Files

- Shell configs: `.zshrc` in root
- Tmux configs: `.tmux.conf` in root
- Neovim configs: `config/nvim/`
- Other tool configs: `config/{tool_name}/`

After modifying, re-run `install.sh` or manually sync:
```bash
cp .zshrc ~/
cp .tmux.conf ~/
rsync -av config/* ~/.config/
```

### Modifying Installation Script

The `install.sh` script is organized into logical sections:
- **OS Detection**: `detect_os()` function
- **Package Manager**: `install_package_manager()`, `install_packages()`
- **Additional Tools**: `setup_additional_tools()` (tmux, nvim, oh-my-zsh, etc.)
- **Claude Config**: `apply_claude_config()` — writes `CLAUDE_CONFIG` env var to `~/.claude/settings.json`
- **Config Files**: `install_config_files()`
- **Main Flow**: `main()` orchestrates everything

## Environment Variables

- **CLAUDE_CONFIG**: JSON configuration written directly to `~/.claude/settings.json`
- **SNOWFLAKE_PRIVATE_KEY**: Private key for Snowflake (written to `~/.keys/snowflake_private_key.pem`)
- **SNOWFLAKE_CLI_CONFIG**: Snowflake CLI config (written to `~/.snowflake/config.toml`)
