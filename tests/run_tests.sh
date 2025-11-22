#!/bin/bash
set -e

# Main test runner for dotfiles
# Runs both BATS unit tests and Docker integration tests

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test modes
RUN_UNIT=true
RUN_INTEGRATION=true
RUN_UBUNTU=true
RUN_CODESPACES=true

# Parse command line arguments
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Run tests for dotfiles installation script.

OPTIONS:
    -u, --unit-only         Run only unit tests (BATS)
    -i, --integration-only  Run only integration tests (Docker)
    --ubuntu-only          Run only Ubuntu Docker tests
    --codespaces-only      Run only Codespaces Docker tests
    -h, --help             Show this help message

EXAMPLES:
    $0                     # Run all tests
    $0 --unit-only        # Run only BATS unit tests
    $0 --ubuntu-only      # Run only Ubuntu Docker integration test
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--unit-only)
            RUN_INTEGRATION=false
            shift
            ;;
        -i|--integration-only)
            RUN_UNIT=false
            shift
            ;;
        --ubuntu-only)
            RUN_UNIT=false
            RUN_CODESPACES=false
            shift
            ;;
        --codespaces-only)
            RUN_UNIT=false
            RUN_UBUNTU=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Change to repo root
cd "$(dirname "$0")/.."

echo -e "${BLUE}=========================================="
echo "Dotfiles Test Runner"
echo -e "==========================================${NC}"
echo ""

# =============================================================================
# Unit Tests (BATS)
# =============================================================================

if $RUN_UNIT; then
    echo -e "${BLUE}Running Unit Tests (BATS)...${NC}"
    echo ""

    # Check if bats is installed
    if ! command -v bats &> /dev/null; then
        echo -e "${YELLOW}BATS not found. Installing...${NC}"
        if command -v brew &> /dev/null; then
            brew install bats-core
        else
            echo -e "${RED}Error: BATS not installed and Homebrew not available.${NC}"
            echo "Please install BATS manually:"
            echo "  - macOS: brew install bats-core"
            echo "  - Linux: https://bats-core.readthedocs.io/en/stable/installation.html"
            exit 1
        fi
    fi

    # Run BATS tests
    if bats tests/install.bats; then
        echo -e "${GREEN}✓ Unit tests passed${NC}"
        echo ""
    else
        echo -e "${RED}✗ Unit tests failed${NC}"
        exit 1
    fi
fi

# =============================================================================
# Integration Tests (Docker)
# =============================================================================

if $RUN_INTEGRATION; then
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Error: Docker not found.${NC}"
        echo "Docker is required for integration tests."
        echo "Install Docker from: https://www.docker.com/get-started"
        exit 1
    fi

    # Ubuntu integration test
    if $RUN_UBUNTU; then
        echo -e "${BLUE}Running Ubuntu Integration Test...${NC}"
        echo ""

        docker build -f tests/Dockerfile.ubuntu -t dotfiles-test-ubuntu .

        if docker run --rm dotfiles-test-ubuntu; then
            echo -e "${GREEN}✓ Ubuntu integration test passed${NC}"
            echo ""
        else
            echo -e "${RED}✗ Ubuntu integration test failed${NC}"
            exit 1
        fi
    fi

    # Codespaces integration test
    if $RUN_CODESPACES; then
        echo -e "${BLUE}Running Codespaces Integration Test...${NC}"
        echo ""

        # Setup fixtures first
        source tests/helpers.bash
        setup_claude_fixture

        docker build -f tests/Dockerfile.codespaces -t dotfiles-test-codespaces .

        if docker run --rm dotfiles-test-codespaces; then
            echo -e "${GREEN}✓ Codespaces integration test passed${NC}"
            echo ""
        else
            echo -e "${RED}✗ Codespaces integration test failed${NC}"
            cleanup_claude_fixture
            exit 1
        fi

        cleanup_claude_fixture
    fi
fi

# =============================================================================
# Summary
# =============================================================================

echo -e "${GREEN}=========================================="
echo "All Tests Passed!"
echo -e "==========================================${NC}"
echo ""
echo "Test summary:"
if $RUN_UNIT; then
    echo "  ✓ Unit tests (BATS)"
fi
if $RUN_INTEGRATION; then
    if $RUN_UBUNTU; then
        echo "  ✓ Ubuntu integration test"
    fi
    if $RUN_CODESPACES; then
        echo "  ✓ Codespaces integration test"
    fi
fi
echo ""
