#!/usr/bin/env bats

# BATS tests for install.sh
# Run with: bats tests/install.bats

load 'helpers'

setup() {
  # Source the install script functions (main won't auto-execute)
  source ./install.sh

  # Setup test environment
  export TEST_MODE=1
  export TEST_HOME="${BATS_TEST_TMPDIR}/home"
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME"
}

teardown() {
  # Cleanup test environment
  rm -rf "$TEST_HOME"
}

# =============================================================================
# OS Detection Tests
# =============================================================================

@test "detect_os returns 'macos' on Darwin" {
  if [ "$(uname)" = "Darwin" ]; then
    result=$(detect_os)
    [ "$result" = "macos" ]
  else
    skip "Test only runs on macOS"
  fi
}

@test "detect_os returns 'ubuntu' on Ubuntu" {
  mock_uname "Linux"
  cat > /tmp/os-release <<EOF
ID=ubuntu
EOF
  mock_os_release "/tmp/os-release"
  run detect_os
  [ "$status" -eq 0 ]
  [ "$output" = "ubuntu" ]
  rm /tmp/os-release
}

@test "detect_os returns 'linux' on other Linux" {
  mock_uname "Linux"
  cat > /tmp/os-release <<EOF
ID=debian
EOF
  mock_os_release "/tmp/os-release"
  run detect_os
  [ "$status" -eq 0 ]
  [ "$output" = "linux" ]
  rm /tmp/os-release
}

@test "detect_os returns 'linux' on Codespaces (even if Ubuntu)" {
  export CODESPACES=true
  mock_uname "Linux"
  cat > /tmp/os-release <<EOF
ID=ubuntu
EOF
  mock_os_release "/tmp/os-release"
  run detect_os
  [ "$status" -eq 0 ]
  [ "$output" = "linux" ]
  rm /tmp/os-release
  unset CODESPACES
}

# =============================================================================
# Go Installation Tests (Ubuntu)
# =============================================================================

@test "install_go_ubuntu skips if go already installed" {
  function go() { echo "go version go1.23.4 linux/amd64"; }
  export -f go

  run install_go_ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Go already installed" ]]

  unset -f go
}

@test "install_go_ubuntu uses correct version and URL" {
  skip "Tested in integration tests"
}

# =============================================================================
# CLAUDE_CONFIG Tests
# =============================================================================

@test "apply_claude_config creates settings.json when CLAUDE_CONFIG is set" {
  export CLAUDE_CONFIG='{"test_key": "test_value"}'

  run apply_claude_config
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Applying CLAUDE_CONFIG" ]]

  [ -f "$HOME/.claude/settings.json" ]

  content=$(cat "$HOME/.claude/settings.json")
  [ "$content" = '{"test_key": "test_value"}' ]
}

@test "apply_claude_config does nothing when CLAUDE_CONFIG is not set" {
  unset CLAUDE_CONFIG

  run apply_claude_config
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  [ ! -f "$HOME/.claude/settings.json" ]
}

@test "apply_claude_config works without CLAUDE_REPO" {
  unset CLAUDE_REPO
  export CLAUDE_CONFIG='{"standalone": true}'

  run apply_claude_config
  [ "$status" -eq 0 ]

  [ -f "$HOME/.claude/settings.json" ]

  grep "standalone" "$HOME/.claude/settings.json"
}
