#!/usr/bin/env bash
set -e

# Integration test script for Docker-based testing
# This script runs inside Docker containers to test actual installation

echo "=========================================="
echo "Integration Test for install.sh"
echo "CODE_PATH: ${CODE_PATH:-not set}"
echo "OS: $(uname -a)"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test tracking
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# =============================================================================
# Pre-installation Tests
# =============================================================================

info "Running pre-installation checks..."

# Check script exists
if [ -f "./install.sh" ]; then
    pass "install.sh exists"
else
    fail "install.sh not found"
    exit 1
fi

# Check script is executable
if [ -x "./install.sh" ]; then
    pass "install.sh is executable"
else
    info "Making install.sh executable"
    chmod +x ./install.sh || {
        fail "chmod failed"
        exit 1
    }
    if [ -x "./install.sh" ]; then
        pass "install.sh is now executable"
    else
        fail "Could not make install.sh executable"
        exit 1
    fi
fi

# =============================================================================
# Setup Test Environment
# =============================================================================

info "Setting up test environment..."

# Create mock Claude repo if using fixture
if [[ "$CLAUDE_REPO" == file://* ]]; then
    info "Setting up Claude fixture repository"
    source tests/helpers.bash
    setup_claude_fixture
    pass "Claude fixture repository created"
fi

# Set test environment variables
export TEST_VAR="integration_test_value"

# =============================================================================
# Run Installation
# =============================================================================

info "Running installation script..."

# Run install.sh
if ./install.sh; then
    pass "Installation completed successfully"
else
    fail "Installation failed"
    exit 1
fi

# =============================================================================
# Post-installation Tests
# =============================================================================

info "Running post-installation verification..."

# Check core tools are installed/available
check_command() {
    local cmd=$1
    if command -v "$cmd" &> /dev/null; then
        pass "$cmd is available"
        return 0
    else
        fail "$cmd is not available"
        return 1
    fi
}

# Core packages (should be installed in all modes)
check_command "zsh"
check_command "tmux"
check_command "nvim"

# Check config files were copied
check_file() {
    local file=$1
    if [ -f "$file" ]; then
        pass "$file exists"
        return 0
    else
        fail "$file not found"
        return 1
    fi
}

check_file "$HOME/.zshrc"
check_file "$HOME/.tmux.conf"

# Check Oh My Zsh was installed
if [ -d "$HOME/.oh-my-zsh" ]; then
    pass "Oh My Zsh is installed"
else
    fail "Oh My Zsh not found"
fi

# Check tmux plugins
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
    pass "Tmux Plugin Manager is installed"
else
    fail "Tmux Plugin Manager not found"
fi

# Check NvChad
if [ -d "$HOME/.config/nvim" ]; then
    pass "Neovim config is installed"
else
    fail "Neovim config not found"
fi

# =============================================================================
# Claude Configuration Tests
# =============================================================================

info "Verifying Claude Code configuration..."

# Check .claude directory
if [ -d "$HOME/.claude" ]; then
    pass ".claude directory exists"
else
    fail ".claude directory not found"
fi

# Check settings.json was generated
if [ -f "$HOME/.claude/settings.json" ]; then
    pass "settings.json was generated"

    # Verify template substitution worked
    if grep -q "integration_test_value" "$HOME/.claude/settings.json" 2>/dev/null; then
        pass "Template variable substitution worked"
    else
        info "Template substitution check skipped (no template vars)"
    fi
else
    fail "settings.json not found"
fi

# Check CLAUDE.md
if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    pass "CLAUDE.md was synced"
else
    info "CLAUDE.md not found (optional)"
fi

# Check for Claude components directories
for component in agents commands skills hooks output-styles; do
    if [ -d "$HOME/.claude/$component" ]; then
        pass "$component directory was synced"
    else
        info "$component directory not found (optional)"
    fi
done

# =============================================================================
# CODE_PATH Specific Tests
# =============================================================================

info "Verifying CODE_PATH-based configuration..."

# Check that plugins are loaded in .zshrc
if grep -q "bazel" "$HOME/.zshrc"; then
    pass "Bazel plugin is configured"
else
    fail "Bazel plugin not found in .zshrc"
fi

# Check that CODE_PATH repos have .claude directories
if [ -n "$CODE_PATH" ] && [ -d "$CODE_PATH" ]; then
    for repo_dir in "$CODE_PATH"/*; do
        if [ -d "$repo_dir" ]; then
            repo_name=$(basename "$repo_dir")
            if [ -d "$repo_dir/.claude" ]; then
                pass "$repo_name has .claude directory"
            else
                fail "$repo_name missing .claude directory"
            fi
        fi
    done
fi

# =============================================================================
# Idempotency Test (Re-run)
# =============================================================================

info "Testing idempotency (re-running install.sh)..."

if ./install.sh; then
    pass "Second installation run completed successfully"
else
    fail "Second installation run failed"
fi

# Verify configs still exist after re-run
if [ -f "$HOME/.zshrc" ] && [ -f "$HOME/.claude/settings.json" ]; then
    pass "Configuration files still exist after re-run"
else
    fail "Configuration files missing after re-run"
fi

# =============================================================================
# Test Summary
# =============================================================================

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo "=========================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
