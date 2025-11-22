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

  # Setup repo structure (using repo name only, not org/repo)
  mkdir -p "$CLAUDE_CLONE_DIR/central"
  mkdir -p "$CLAUDE_CLONE_DIR/default"
  echo "repo-specific" > "$CLAUDE_CLONE_DIR/central/CLAUDE.md"
  echo "default" > "$CLAUDE_CLONE_DIR/default/CLAUDE.md"

  sync_claude_file "CLAUDE.md" "central" "false" "$TEST_HOME/.claude"

  [ -f "$TEST_HOME/.claude/CLAUDE.md" ]

  content=$(cat "$TEST_HOME/.claude/CLAUDE.md")
  [ "$content" = "repo-specific" ]
}

@test "sync_claude_file falls back to default when repo-specific missing" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  # Setup repo structure (no repo-specific file)
  mkdir -p "$CLAUDE_CLONE_DIR/central"
  mkdir -p "$CLAUDE_CLONE_DIR/default"
  echo "default" > "$CLAUDE_CLONE_DIR/default/CLAUDE.md"

  sync_claude_file "CLAUDE.md" "central" "false" "$TEST_HOME/.claude"

  [ -f "$TEST_HOME/.claude/CLAUDE.md" ]

  content=$(cat "$TEST_HOME/.claude/CLAUDE.md")
  [ "$content" = "default" ]
}

@test "sync_claude_file skips when neither repo-specific nor default exists" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  mkdir -p "$CLAUDE_CLONE_DIR/central"
  mkdir -p "$CLAUDE_CLONE_DIR/default"

  run sync_claude_file "CLAUDE.md" "central" "false" "$TEST_HOME/.claude"
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

  sync_claude_file "settings.json.template" "default" "true" "$TEST_HOME/.claude"

  [ -f "$TEST_HOME/.claude/settings.json" ]

  grep "test_value" "$TEST_HOME/.claude/settings.json"
}

@test "sync_claude_component uses repo-specific directory when available" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  mkdir -p "$CLAUDE_CLONE_DIR/central/agents"
  mkdir -p "$CLAUDE_CLONE_DIR/default/agents"
  echo "repo-agent" > "$CLAUDE_CLONE_DIR/central/agents/test.md"
  echo "default-agent" > "$CLAUDE_CLONE_DIR/default/agents/test.md"

  run sync_claude_component "agents" "central" "$TEST_HOME/.claude"
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.claude/agents/test.md" ]

  content=$(cat "$TEST_HOME/.claude/agents/test.md")
  [ "$content" = "repo-agent" ]
}

@test "sync_claude_component falls back to default directory" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"

  mkdir -p "$CLAUDE_CLONE_DIR/central"
  mkdir -p "$CLAUDE_CLONE_DIR/default/agents"
  echo "default-agent" > "$CLAUDE_CLONE_DIR/default/agents/test.md"

  run sync_claude_component "agents" "central" "$TEST_HOME/.claude"
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

  run sync_claude_component "agents" "default" "$TEST_HOME/.claude"
  [ "$status" -eq 0 ]

  # local-only.md should be deleted
  [ ! -f "$TEST_HOME/.claude/agents/local-only.md" ]
  # source.md should exist
  [ -f "$TEST_HOME/.claude/agents/source.md" ]
}

# =============================================================================
# CODE_PATH Tests
# =============================================================================

@test "sync_claude requires CODE_PATH to be set" {
  unset CODE_PATH
  export CLAUDE_REPO="file://$PWD/tests/fixtures/claude"

  run sync_claude
  [ "$status" -eq 1 ]
  [[ "$output" =~ "CODE_PATH" ]]
}

@test "sync_claude requires CLAUDE_REPO to be set" {
  export CODE_PATH="$TEST_HOME/code"
  unset CLAUDE_REPO

  run sync_claude
  [ "$status" -eq 1 ]
  [[ "$output" =~ "CLAUDE_REPO" ]]
}

@test "sync_claude syncs all repos under CODE_PATH" {
  export CODE_PATH="$TEST_HOME/code"
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export CLAUDE_REPO="file://$PWD/tests/fixtures/claude"

  # Setup fixture
  setup_claude_fixture

  # Create test repos under CODE_PATH
  mkdir -p "$CODE_PATH/central"
  mkdir -p "$CODE_PATH/test-repo"

  run sync_claude
  [ "$status" -eq 0 ]

  # Check that .claude dirs were created for each repo
  [ -d "$CODE_PATH/central/.claude" ]
  [ -d "$CODE_PATH/test-repo/.claude" ]

  # Check that default config was synced to $HOME/.claude
  [ -d "$HOME/.claude" ]
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

@test "sync_repo_claude_config syncs repo-specific config" {
  export CLAUDE_CLONE_DIR="$TEST_HOME/claude-configs"
  export CLAUDE_REPO="file://$PWD/tests/fixtures/claude"

  # Setup fixture repo
  setup_claude_fixture

  # Clone the repo first
  clone_or_update_claude_repo

  # Create a test repo directory
  local repo_path="$TEST_HOME/code/central"
  mkdir -p "$repo_path"

  run sync_repo_claude_config "$repo_path"
  [ "$status" -eq 0 ]

  # Should have synced components to repo's .claude directory
  [ -f "$repo_path/.claude/settings.json" ]
  [ -f "$repo_path/.claude/CLAUDE.md" ]
}
