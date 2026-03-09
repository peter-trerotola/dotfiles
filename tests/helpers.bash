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
  export OS_RELEASE_FILE="$file_path"
}

# Mock brew command
mock_command() {
  local cmd="$1"
  eval "$cmd() { echo 'mock: $cmd \$@'; return 0; }"
  export -f "$cmd"
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
