# dotfiles

This repository contains the configurations for my dev environment and is used on GH linux codespaces or Mac OS.

## Features

- Brew installation for most packages
- Neovim w/ NvChad and some other customizations
- zsh w/ Oh My ZSH
- Some common aliases
- Snowflake configuration via GH Secrets

## Usage

### Basic Installation
```bash
# Clone and run the installer
./install.sh

# Or with specific environment configuration
CONFIG_MODE="work-org/main-repo" WORK_ORG_PATTERN="work-org/*" CLAUDE_REPO="git@github.com:user/claude-configs.git" ./install.sh
```

### GitHub Codespaces
Attach this dotfiles repo to your codespace configuration and set `CONFIG_MODE` in your codespace secrets.

### Configuration Modes
- `default` - Minimal personal setup
- `work-org/main-repo` - Work environment with additional tools
- See `CLAUDE.md` for more details

## Testing

A comprehensive test suite is available to verify installation across different platforms.

```bash
# Run all tests (requires bats-core and Docker)
./tests/run_tests.sh

# Run only unit tests
./tests/run_tests.sh --unit-only

# Run only integration tests
./tests/run_tests.sh --integration-only
```

See [tests/README.md](tests/README.md) for detailed testing documentation.

## Customization

Feel free to modify these files to fit your own workflow and preferences. See `CLAUDE.md` for architecture details and guidance on adding new configurations.
