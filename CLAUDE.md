# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository for personal development environment configuration, designed to work on macOS, GitHub Codespaces (Linux), and Ubuntu Server. The repository provides a consistent shell, editor, and tooling setup across different environments with automatic Claude Code configuration syncing per repository via `CODE_PATH`.

## Installation and Setup

### Basic Installation
```bash
# Set CODE_PATH to where your code repos live and run the installer
CODE_PATH=~/Code CLAUDE_REPO="git@github.com:user/claude-configs.git" ./install.sh

# For different environments:
# Personal laptop:   CODE_PATH=~/Code
# Work laptop:       CODE_PATH=~/Work
# GitHub Codespaces: CODE_PATH=/workspaces
```

### CODE_PATH System

The `CODE_PATH` environment variable points to the directory where your code repositories live. The installer syncs Claude Code configurations to all repositories under this path based on repository name.

**How it works:**
1. `CODE_PATH` is set to your workspace directory (e.g., `~/Code`, `~/Work`, `/workspaces`)
2. During installation, `sync-claude` iterates through all directories under `CODE_PATH/*`
3. For each repo directory (e.g., `~/Code/central`), it:
   - Extracts the repo name (`central`)
   - Looks for matching config in your private Claude repo
   - Syncs repo-specific config to `~/Code/central/.claude`
   - Falls back to default config if repo-specific doesn't exist
4. Also syncs default config to `$HOME/.claude` for general use

**Example directory structure:**
```
~/Code/           <- CODE_PATH
├── central/      <- Repo gets 'central' Claude config
│   └── .claude/
├── platform/     <- Repo gets 'platform' Claude config
│   └── .claude/
└── side-project/ <- Repo gets 'side-project' Claude config (or default if not found)
    └── .claude/
```

### Package Installation

All packages are installed regardless of environment (work and personal packages):

**Packages:**
- rsync, tmux, btop, ripgrep, zsh, neovim, lua-language-server
- bazel, kubectl, docker, docker-compose, golang, gh, and other development tools

**Platform support:**
- **macOS & Linux Codespaces**: Uses Homebrew for all packages
- **Ubuntu Server**: Uses apt package manager (some tools may require manual installation)

## Claude Code Configuration System

### Private Configuration Repository

Claude configurations are stored in a separate private repository specified via the `CLAUDE_REPO` environment variable. Configs are organized by repository name (not organization/repo).

**Expected structure:**
```
claude/
├── default/                           # Fallback configuration (used by $HOME/.claude and repos without specific configs)
│   ├── settings.json.template         # Settings with env var substitution
│   ├── CLAUDE.md                      # Project memory/guidance
│   ├── agents/                        # Custom AI subagents (*.md files)
│   ├── commands/                      # Slash commands (*.md files)
│   ├── skills/                        # Skills with SKILL.md structure
│   ├── hooks/                         # Hook scripts
│   └── output-styles/                 # Custom output styles
├── central/                           # Config for any repo named 'central'
│   ├── settings.json.template         # Repo-specific settings (optional)
│   ├── CLAUDE.md                      # Repo-specific guidance (optional)
│   ├── agents/                        # Repo-specific agents (optional)
│   └── ...                            # Other components (optional)
├── platform/                          # Config for any repo named 'platform'
│   └── ... (same structure, all components optional)
└── my-side-project/                   # Config for any repo named 'my-side-project'
    └── ... (same structure)
```

**Note:** Directory names in the Claude repo should match the **basename** of your repositories under CODE_PATH. For example:
- `~/Code/work-org/central` → uses `central` config
- `~/Code/personal/central` → also uses `central` config (same name)
- You can organize repos however you want locally; only the final directory name matters

### Layered Fallback System

For each Claude Code component, `sync-claude` uses this precedence:
1. **Repo-specific**: Check if component exists in repo name path (e.g., `central/agents/`)
2. **Default fallback**: If not found, use `default/` path (e.g., `default/agents/`)
3. **Skip**: If not in either location, skip that component

This allows repo configurations to:
- Override only specific components (e.g., just settings.json.template and CLAUDE.md)
- Inherit everything else from default
- Create minimal repo configs (even an empty folder works, will use all defaults)

**Components with fallback support:**
- `settings.json.template` - Processed with environment variable substitution
- `CLAUDE.md` - Repository-specific guidance
- `agents/` - Custom AI subagents directory
- `commands/` - Slash commands directory
- `skills/` - Skills directory
- `hooks/` - Hook scripts directory
- `output-styles/` - Output styles directory

**Template processing:** The `settings.json.template` file supports environment variable substitution using `${VARIABLE_NAME}` syntax. Required environment variables should be documented in each template.

### Installation Location

All Claude Code components are synced to `~/.claude/`:
- `~/.claude/settings.json` - Processed from template
- `~/.claude/CLAUDE.md` - Copied from selected config
- `~/.claude/agents/` - Synced from selected config or default
- `~/.claude/commands/` - Synced from selected config or default
- `~/.claude/skills/` - Synced from selected config or default
- `~/.claude/hooks/` - Synced from selected config or default
- `~/.claude/output-styles/` - Synced from selected config or default

The private Claude repo is cloned to `~/.dotfiles-claude-configs/` and updated on each install.

## Repository Structure

```
.
├── install.sh              # Main installation script with CODE_PATH support
├── .zshrc                  # Zsh configuration
├── .tmux.conf             # Tmux configuration with plugins
├── CLAUDE.md              # This file
└── config/
    ├── nvim/              # Neovim configuration (NvChad-based)
    │   ├── init.lua       # Entry point for Neovim config
    │   └── lua/
    │       ├── configs/   # LSP and tool configurations
    │       │   └── lspconfig.lua  # gopls and other LSP configs
    │       └── plugins/   # Plugin configurations
    └── btop/              # btop system monitor configuration
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

**gopls LSP configuration:**
- Uses standard gopls settings
- For Bazel-specific configuration, customize via repo-specific Claude config

Location: `config/nvim/lua/configs/lspconfig.lua:19-26`

### Tmux Configuration
- Mouse mode enabled
- Vi mode for copy/paste and status keys
- Plugins: tpm, tmux-sensible, tmux-powerline, tmux-resurrect, tmux-continuum
- Session resurrection enabled for Neovim

## Making Changes

### Adding a New Repository Claude Configuration

1. **Create folder in private Claude repo** (named by repository basename):
   ```bash
   cd ~/.dotfiles-claude-configs
   mkdir -p my-new-repo
   ```

2. **Add components** (all optional, will fall back to default/):
   - `settings.json.template` - With environment variable placeholders
   - `CLAUDE.md` - Repo-specific guidance
   - `agents/`, `commands/`, `skills/`, `hooks/`, `output-styles/` - As needed

3. **Commit and push** to private Claude repo

4. **Sync Claude configs to all repos:**
   ```bash
   # Option 1: Re-run installer (also updates packages/configs)
   ./install.sh

   # Option 2: Just sync Claude configs
   source ./install.sh && sync-claude
   ```

5. **Verify sync** - Check that `$CODE_PATH/my-new-repo/.claude/` was created

### Modifying Configuration Files

**Dotfiles configuration:**
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

**Claude Code configuration:**
- Edit files in `~/.dotfiles-claude-configs/` (the private repo clone)
- Commit and push changes
- Re-run `sync-claude` to update all repos:
  ```bash
  source ./install.sh && sync-claude
  ```

### Adding New Neovim Plugins
Add plugins to `config/nvim/lua/plugins/init.lua`:
```lua
return {
  {
    "username/plugin-name",
    event = 'EventName',
    opts = require "configs.plugin-config",
  },
}
```

### Adding New LSP Servers
Edit `config/nvim/lua/configs/lspconfig.lua`:
- Add to `servers` array for default config
- Create custom setup block for specialized configuration (like gopls)

### Modifying Installation Script

The `install.sh` script is organized into logical sections:
- **OS Detection**: `detect_os()` function
- **Package Manager**: `install_package_manager()`, `install_packages()`
- **Additional Tools**: `setup_additional_tools()` (tmux, nvim, oh-my-zsh, etc.)
- **Claude Config**: `sync_claude()`, `sync_repo_claude_config()`, `sync_claude_component()`, `sync_claude_file()`
- **Config Files**: `install_config_files()`
- **Main Flow**: `main()` orchestrates everything

When modifying:
- Keep functions focused and single-purpose
- Maintain platform compatibility (macOS/Linux/Ubuntu)
- Add error handling for missing dependencies
- Update this documentation with changes

## Environment Variables

### Primary Configuration
- **CODE_PATH**: **Required**. Directory where your code repositories live
  - Personal laptop: `~/Code`
  - Work laptop: `~/Work`
  - GitHub Codespaces: `/workspaces`
- **CLAUDE_REPO**: **Required**. URL to private Claude configuration repository
  - Example: `"git@github.com:username/claude-configs.git"`

### Legacy Support (Backward Compatibility)
- **CLAUDE_CONFIG**: JSON configuration written directly to `~/.claude/settings.json`
- **SNOWFLAKE_PRIVATE_KEY**: Private key for Snowflake (written to `~/.keys/snowflake_private_key.pem`)
- **SNOWFLAKE_CLI_CONFIG**: Snowflake CLI config (written to `~/.snowflake/config.toml`)

### Template Variables
Environment variables used in `settings.json.template` files are repo-specific. Check each template for required variables.
