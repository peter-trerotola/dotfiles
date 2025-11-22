# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a dotfiles repository for personal development environment configuration, designed to work on macOS, GitHub Codespaces (Linux), and Ubuntu Server. The repository provides a consistent shell, editor, and tooling setup across different environments with support for multiple environment profiles via `CONFIG_MODE`.

## Installation and Setup

### Basic Installation
```bash
# Clone and run the installer with default configuration
./install.sh

# Install with specific environment configuration
CONFIG_MODE="work-org/main-repo" ./install.sh

# For GitHub Codespaces: attach this dotfiles repo and set CONFIG_MODE in secrets
```

### CONFIG_MODE System

The `CONFIG_MODE` environment variable determines which packages are installed and which Claude Code configuration is used. This supports multiple work environments and personal setups from a single dotfiles repository.

**How it works:**
- If `CONFIG_MODE` is unset or set to `"default"`: Installs core packages only, uses default Claude configuration
- If set to a repo path (e.g., `"work-org/main-repo"`): Installs core + repo-specific packages, uses matching Claude configuration with fallback to defaults

**Available CONFIG_MODE values:**
- `default` - Minimal personal setup
- `work-org/main-repo` - Work organization main repository
- `work-org/other-repo` - Work organization other repository
- `personal/project-name` - Personal project
- (Add new configurations by creating folders in the private Claude repo)

### Package Installation by CONFIG_MODE

**Core packages** (installed in all modes):
- rsync, tmux, btop, ripgrep, zsh, neovim, lua-language-server

**Work-specific packages** (installed only when CONFIG_MODE matches work pattern, e.g., "work-org/*"):
- bazel, kubectl, docker, docker-compose, golang, gh, and other work-specific tools

**Platform support:**
- **macOS & Linux Codespaces**: Uses Homebrew for all packages
- **Ubuntu Server**: Uses apt package manager (some tools may require manual installation)

## Claude Code Configuration System

### Private Configuration Repository

Claude configurations are stored in a separate private repository specified via the `CLAUDE_REPO` environment variable.

**Expected structure:**
```
claude/
├── default/                           # Fallback configuration for all modes
│   ├── settings.json.template         # Settings with env var substitution
│   ├── CLAUDE.md                      # Project memory/guidance
│   ├── agents/                        # Custom AI subagents (*.md files)
│   ├── commands/                      # Slash commands (*.md files)
│   ├── skills/                        # Skills with SKILL.md structure
│   ├── hooks/                         # Hook scripts
│   └── output-styles/                 # Custom output styles
├── work-org/
│   ├── main-repo/
│   │   ├── settings.json.template     # Repo-specific settings (optional)
│   │   ├── CLAUDE.md                  # Repo-specific guidance (optional)
│   │   ├── agents/                    # Repo-specific agents (optional)
│   │   └── ...                        # Other components (optional)
│   └── other-repo/
│       └── ... (same structure, all components optional)
└── personal/
    └── project-name/
        └── ... (same structure)
```

### Layered Fallback System

For each Claude Code component, the installation script uses this precedence:
1. **Repo-specific**: Check if component exists in `CONFIG_MODE` path (e.g., `work-org/main-repo/agents/`)
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
├── install.sh              # Main installation script with CONFIG_MODE support
├── .zshrc                  # Zsh configuration with conditional loading
├── .tmux.conf             # Tmux configuration with plugins
├── CLAUDE.md              # This file
└── config/
    ├── nvim/              # Neovim configuration (NvChad-based)
    │   ├── init.lua       # Entry point for Neovim config
    │   └── lua/
    │       ├── configs/   # LSP and tool configurations
    │       │   └── lspconfig.lua  # Conditional gopls config
    │       └── plugins/   # Plugin configurations
    └── btop/              # btop system monitor configuration
```

## Key Configurations

### Zsh Configuration
- Theme: robbyrussell
- Uses powerline-go for enhanced prompt (shows CONFIG_MODE when set)
- Oh My Zsh with conditional plugin loading based on CONFIG_MODE

**Base plugins** (all environments): git, brew, vi-mode

**Work-specific plugins** (when CONFIG_MODE matches work pattern): bazel, docker, docker-compose, gh, golang, kubectl

**Aliases:**
- `vim` → `nvim` (always available)
- Work-specific aliases are loaded conditionally based on CONFIG_MODE pattern matching

### Neovim Setup
- Based on **NvChad v2.5** (imported as a plugin)
- Uses **lazy.nvim** for plugin management
- LSP servers configured: HTML, Bash, Protocol Buffers, Bazel (bzl), gopls
- Format-on-save enabled via `conform.nvim`
- File tree width set to 60 characters

**gopls LSP configuration:**
- Reads `CONFIG_MODE` environment variable at startup
- When CONFIG_MODE is set (non-default), adds Bazel-specific settings:
  - `GOPACKAGESDRIVER` path for Bazel integration
  - Directory filters to exclude bazel-* folders
- When CONFIG_MODE is unset or "default", uses standard gopls settings

Location: `config/nvim/lua/configs/lspconfig.lua:19-46`

### Tmux Configuration
- Mouse mode enabled
- Vi mode for copy/paste and status keys
- Plugins: tpm, tmux-sensible, tmux-powerline, tmux-resurrect, tmux-continuum
- Session resurrection enabled for Neovim

## Making Changes

### Adding a New Environment Configuration

1. **Create folder structure in private Claude repo:**
   ```bash
   cd ~/.dotfiles-claude-configs
   mkdir -p NewOrg/new-repo
   ```

2. **Add components** (all optional, will fall back to default/):
   - `settings.json.template` - With environment variable placeholders
   - `CLAUDE.md` - Repo-specific guidance
   - `agents/`, `commands/`, `skills/`, `hooks/`, `output-styles/` - As needed

3. **Commit and push** to private Claude repo

4. **Use the new configuration:**
   ```bash
   CONFIG_MODE="NewOrg/new-repo" ./install.sh
   ```

5. **Update .zshrc or install.sh** if special package requirements:
   - Add conditional package installation in `install_repo_specific_packages()`
   - Add conditional aliases/plugins in `.zshrc`

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
- Re-run `install.sh` to update `~/.claude/`

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
- **Package Manager**: `install_package_manager()`, `install_core_packages()`, `install_repo_specific_packages()`
- **Additional Tools**: `setup_additional_tools()` (tmux, nvim, oh-my-zsh, etc.)
- **Claude Config**: `setup_claude_config()`, `sync_claude_component()`, `sync_claude_file()`
- **Config Files**: `install_config_files()`
- **Main Flow**: `main()` orchestrates everything

When modifying:
- Keep functions focused and single-purpose
- Maintain platform compatibility (macOS/Linux/Ubuntu)
- Add error handling for missing dependencies
- Update this documentation with changes

## Environment Variables

### Primary Configuration
- **CONFIG_MODE**: Selects which environment configuration to use (default: "default")
  - Examples: `"work-org/main-repo"`, `"personal/project-name"`
- **CLAUDE_REPO**: URL to private Claude configuration repository (optional, required for Claude config sync)
  - Example: `"git@github.com:username/claude-configs.git"`
- **WORK_ORG_PATTERN**: Pattern to match work-related CONFIG_MODE values for installing work-specific packages (optional)
  - Example: `"work-org/*"` (matches any CONFIG_MODE starting with "work-org/")

### Legacy Support (Backward Compatibility)
- **CLAUDE_CONFIG**: JSON configuration written directly to `~/.claude/settings.json` (overrides CONFIG_MODE)
- **SNOWFLAKE_PRIVATE_KEY**: Private key for Snowflake (written to `~/.keys/snowflake_private_key.pem`)
- **SNOWFLAKE_CLI_CONFIG**: Snowflake CLI config (written to `~/.snowflake/config.toml`)

### Template Variables
Environment variables used in `settings.json.template` files are repo-specific. Check each template for required variables.
