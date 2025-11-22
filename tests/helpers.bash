#!/usr/bin/env bash

# Test helper functions and mocks for BATS tests

# =============================================================================
# Mock Functions
# =============================================================================

# Mock uname command
mock_uname() {
  local return_value="$1"
  uname() {
    echo "$return_value"
  }
  export -f uname
}

# Mock os-release file
mock_os_release() {
  local file_path="$1"
  # Override the file check in detect_os
  export OS_RELEASE_FILE="$file_path"
}

# Mock brew command
mock_command() {
  local cmd="$1"
  eval "$cmd() { echo 'mock: $cmd \$@'; return 0; }"
  export -f "$cmd"
}

# Mock git clone
mock_git_clone() {
  local target_dir="$1"
  git() {
    if [ "$1" = "clone" ]; then
      mkdir -p "$target_dir"
      return 0
    fi
    command git "$@"
  }
  export -f git
}

# Mock git pull
mock_git_pull() {
  git() {
    if [ "$1" = "-C" ] && [ "$3" = "pull" ]; then
      echo "Already up to date."
      return 0
    fi
    command git "$@"
  }
  export -f git
}

# =============================================================================
# Test Fixture Helpers
# =============================================================================

# Setup a mock Claude config repository
setup_claude_fixture() {
  local fixture_dir="$PWD/tests/fixtures/claude"

  mkdir -p "$fixture_dir"
  cd "$fixture_dir"

  # Initialize git repo if not already
  if [ ! -d .git ]; then
    git init
    git config user.email "test@test.com"
    git config user.name "Test User"
  fi

  # Create default config
  mkdir -p default/agents default/commands default/skills default/hooks default/output-styles
  cat > default/settings.json.template <<EOF
{
  "test": "default-\${TEST_VAR:-empty}"
}
EOF
  echo "# Default CLAUDE.md" > default/CLAUDE.md
  echo "# Default agent" > default/agents/default.md
  echo "# Default command" > default/commands/test.md

  # Create work-org/main-repo config
  mkdir -p work-org/main-repo/agents
  cat > work-org/main-repo/settings.json.template <<EOF
{
  "test": "work-\${TEST_VAR:-empty}"
}
EOF
  echo "# Work Org Main Repo CLAUDE.md" > work-org/main-repo/CLAUDE.md
  echo "# Work org agent" > work-org/main-repo/agents/work.md

  # Create personal configs
  mkdir -p personal/project-name
  echo "# Personal Project CLAUDE.md" > personal/project-name/CLAUDE.md

  # Commit everything
  git add .
  git commit -m "Test fixture" || true

  cd - > /dev/null
}

# Cleanup test fixtures
cleanup_claude_fixture() {
  rm -rf "$PWD/tests/fixtures/claude"
}

# =============================================================================
# Assertion Helpers
# =============================================================================

# Assert file contains string
assert_file_contains() {
  local file="$1"
  local pattern="$2"

  if [ ! -f "$file" ]; then
    echo "File does not exist: $file"
    return 1
  fi

  if ! grep -q "$pattern" "$file"; then
    echo "File does not contain pattern: $pattern"
    echo "File contents:"
    cat "$file"
    return 1
  fi
}

# Assert command exists
assert_command_exists() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
    echo "Command not found: $cmd"
    return 1
  fi
}

# Assert directory exists and is not empty
assert_directory_not_empty() {
  local dir="$1"

  if [ ! -d "$dir" ]; then
    echo "Directory does not exist: $dir"
    return 1
  fi

  if [ -z "$(ls -A "$dir")" ]; then
    echo "Directory is empty: $dir"
    return 1
  fi
}
