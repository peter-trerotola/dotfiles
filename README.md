# dotfiles

[![Test Dotfiles](https://github.com/peter-trerotola/dotfiles/actions/workflows/test.yml/badge.svg)](https://github.com/peter-trerotola/dotfiles/actions/workflows/test.yml)

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
CODE_PATH=~/Code CLAUDE_REPO="git@github.com:user/claude-configs.git" ./install.sh
```

### GitHub Codespaces
Attach this dotfiles repo to your codespace configuration and set these secrets:
- `CODE_PATH` - Set to `/workspaces`
- `CLAUDE_REPO` - Your private Claude configuration repository URL

### Environment Variables
- `CODE_PATH` - Directory where your code repos live (e.g., `~/Code`, `~/Work`, `/workspaces`)
- `CLAUDE_REPO` - URL to your private Claude configuration repository
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
