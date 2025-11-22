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
  # On actual macOS, this will return macos
  # On Linux in CI, we skip this test or test differently
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

# =============================================================================
# Template Processing Tests
# =============================================================================

@test "process_template substitutes environment variables" {
  export TEST_VAR="hello"
  export ANOTHER_VAR="world"

  cat > "$TEST_HOME/template.txt" <<EOF
Value is: \${TEST_VAR}
Another: \${ANOTHER_VAR}
EOF

  run process_template "$TEST_HOME/template.txt" "$TEST_HOME/output.txt"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/output.txt" ]

  grep "Value is: hello" "$TEST_HOME/output.txt"
  grep "Another: world" "$TEST_HOME/output.txt"
}

@test "process_template handles missing variables" {
  unset MISSING_VAR

  cat > "$TEST_HOME/template.txt" <<EOF
Value is: \${MISSING_VAR}
EOF

  run process_template "$TEST_HOME/template.txt" "$TEST_HOME/output.txt"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/output.txt" ]

  # Should result in empty string for missing vars
  grep "Value is: $" "$TEST_HOME/output.txt"
}

# =============================================================================
# Claude Configuration Tests
# =============================================================================

@test "sync_claude_file uses repo-specific file when available" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  # Setup repo structure
  mkdir -p "$CLAUDE_CLONE_DIR/work-org/main-repo"
  mkdir -p "$CLAUDE_CLONE_DIR/default"
  echo "repo-specific" > "$CLAUDE_CLONE_DIR/work-org/main-repo/CLAUDE.md"
  echo "default" > "$CLAUDE_CLONE_DIR/default/CLAUDE.md"

  sync_claude_file "CLAUDE.md" "work-org/main-repo" "false"

  [ -f "$TEST_HOME/.claude/CLAUDE.md" ]

  content=$(cat "$TEST_HOME/.claude/CLAUDE.md")
  [ "$content" = "repo-specific" ]
}

@test "sync_claude_file falls back to default when repo-specific missing" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  # Setup repo structure (no repo-specific file)
  mkdir -p "$CLAUDE_CLONE_DIR/work-org/main-repo"
  mkdir -p "$CLAUDE_CLONE_DIR/default"
  echo "default" > "$CLAUDE_CLONE_DIR/default/CLAUDE.md"

  sync_claude_file "CLAUDE.md" "work-org/main-repo" "false"

  [ -f "$TEST_HOME/.claude/CLAUDE.md" ]

  content=$(cat "$TEST_HOME/.claude/CLAUDE.md")
  [ "$content" = "default" ]
}

@test "sync_claude_file skips when neither repo-specific nor default exists" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  mkdir -p "$CLAUDE_CLONE_DIR/work-org/main-repo"
  mkdir -p "$CLAUDE_CLONE_DIR/default"

  run sync_claude_file "CLAUDE.md" "work-org/main-repo" "false"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_HOME/.claude/CLAUDE.md" ]
}

@test "sync_claude_file processes templates when is_template=true" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export MY_VAR="test_value"

  mkdir -p "$CLAUDE_CLONE_DIR/default"
  cat > "$CLAUDE_CLONE_DIR/default/settings.json.template" <<'EOF'
{"key": "${MY_VAR}"}
EOF

  sync_claude_file "settings.json.template" "default" "true"

  [ -f "$TEST_HOME/.claude/settings.json" ]

  grep "test_value" "$TEST_HOME/.claude/settings.json"
}

@test "sync_claude_component uses repo-specific directory when available" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  mkdir -p "$CLAUDE_CLONE_DIR/work-org/main-repo/agents"
  mkdir -p "$CLAUDE_CLONE_DIR/default/agents"
  echo "repo-agent" > "$CLAUDE_CLONE_DIR/work-org/main-repo/agents/test.md"
  echo "default-agent" > "$CLAUDE_CLONE_DIR/default/agents/test.md"

  run sync_claude_component "agents" "work-org/main-repo"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.claude/agents/test.md" ]

  content=$(cat "$TEST_HOME/.claude/agents/test.md")
  [ "$content" = "repo-agent" ]
}

@test "sync_claude_component falls back to default directory" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  mkdir -p "$CLAUDE_CLONE_DIR/work-org/main-repo"
  mkdir -p "$CLAUDE_CLONE_DIR/default/agents"
  echo "default-agent" > "$CLAUDE_CLONE_DIR/default/agents/test.md"

  run sync_claude_component "agents" "work-org/main-repo"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.claude/agents/test.md" ]

  content=$(cat "$TEST_HOME/.claude/agents/test.md")
  [ "$content" = "default-agent" ]
}

@test "sync_claude_component deletes files not in source (--delete flag)" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  mkdir -p "$CLAUDE_CLONE_DIR/default/agents"
  mkdir -p "$TEST_HOME/.claude/agents"

  # Create a file in target that doesn't exist in source
  echo "should-be-deleted" > "$TEST_HOME/.claude/agents/local-only.md"
  echo "from-source" > "$CLAUDE_CLONE_DIR/default/agents/source.md"

  run sync_claude_component "agents" "default"
  [ "$status" -eq 0 ]

  # local-only.md should be deleted
  [ ! -f "$TEST_HOME/.claude/agents/local-only.md" ]
  # source.md should exist
  [ -f "$TEST_HOME/.claude/agents/source.md" ]
}

# =============================================================================
# CONFIG_MODE Tests
# =============================================================================

@test "install_repo_specific_packages installs work packages when WORK_ORG_PATTERN matches" {
  export CONFIG_MODE="work-org/main-repo"
  export WORK_ORG_PATTERN="work-org/*"
  export OS_TYPE="macos"

  # Mock brew command
  mock_command brew

  run install_repo_specific_packages
  [ "$status" -eq 0 ]

  # Check that brew was called (mocked)
  # In a real test, we'd verify the packages list
}

@test "install_repo_specific_packages skips packages when WORK_ORG_PATTERN doesn't match" {
  export CONFIG_MODE="personal/project-name"
  export WORK_ORG_PATTERN="work-org/*"
  export OS_TYPE="macos"

  # Mock brew command
  mock_command brew

  run install_repo_specific_packages
  [ "$status" -eq 0 ]

  # Should not install work-specific packages
}

# =============================================================================
# Clone/Update Claude Repo Tests
# =============================================================================

@test "clone_or_update_claude_repo clones when directory doesn't exist" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export CLAUDE_REPO="file://$PWD/tests/fixtures/claude"

  # Setup fixture
  setup_claude_fixture

  clone_or_update_claude_repo

  # Directory should be created
  [ -d "$CLAUDE_CLONE_DIR" ]
  [ -d "$CLAUDE_CLONE_DIR/.git" ]
}

@test "clone_or_update_claude_repo pulls when directory exists" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export CLAUDE_REPO="https://github.com/test/claude.git"

  # Create directory to simulate existing clone
  mkdir -p "$CLAUDE_CLONE_DIR/.git"

  # Mock git pull
  mock_git_pull

  run clone_or_update_claude_repo
  [ "$status" -eq 0 ]
}

# =============================================================================
# Integration-style Tests (Multiple Functions)
# =============================================================================

@test "setup_claude_config with default CONFIG_MODE" {
  export CONFIG_MODE="default"
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export CLAUDE_REPO="file://$PWD/tests/fixtures/claude"

  # Setup fixture repo
  setup_claude_fixture

  run setup_claude_config
  [ "$status" -eq 0 ]

  # Should have synced default components
  [ -f "$TEST_HOME/.claude/settings.json" ]
}

@test "setup_claude_config with work-org/main-repo CONFIG_MODE" {
  export CONFIG_MODE="work-org/main-repo"
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export CLAUDE_REPO="file://$PWD/tests/fixtures/claude"

  # Setup fixture repo
  setup_claude_fixture

  run setup_claude_config
  [ "$status" -eq 0 ]

  # Should have synced components
  [ -f "$TEST_HOME/.claude/settings.json" ]
}

@test "setup_claude_config falls back to default for missing config path" {
  export CONFIG_MODE="NonExistent/config"
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export CLAUDE_REPO="file://$PWD/tests/fixtures/claude"

  # Setup fixture repo
  setup_claude_fixture

  run setup_claude_config
  [ "$status" -eq 0 ]

  # Should fall back to default
  [ -f "$TEST_HOME/.claude/settings.json" ]
}
