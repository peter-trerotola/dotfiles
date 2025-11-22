# Dotfiles Test Suite

Comprehensive testing for the dotfiles installation script, including unit tests and integration tests.

## Overview

The test suite consists of two main components:

1. **Unit Tests (BATS)** - Test individual functions in isolation with mocked dependencies
2. **Integration Tests (Docker)** - Test full installation on different operating systems

## Quick Start

```bash
# Run all tests
./tests/run_tests.sh

# Run only unit tests
./tests/run_tests.sh --unit-only

# Run only integration tests
./tests/run_tests.sh --integration-only

# Run only Ubuntu integration test
./tests/run_tests.sh --ubuntu-only
```

## Prerequisites

### For Unit Tests (BATS)

Install BATS (Bash Automated Testing System):

```bash
# macOS
brew install bats-core

# Linux (Ubuntu/Debian)
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### For Integration Tests (Docker)

Install Docker:
- macOS: [Docker Desktop](https://www.docker.com/products/docker-desktop)
- Linux: [Docker Engine](https://docs.docker.com/engine/install/)

## Test Structure

```
tests/
├── README.md                    # This file
├── run_tests.sh                 # Main test runner
├── install.bats                 # BATS unit tests
├── helpers.bash                 # Test helper functions and mocks
├── integration_test.sh          # Integration test script (runs in Docker)
├── Dockerfile.ubuntu            # Ubuntu integration test
├── Dockerfile.codespaces        # Codespaces integration test
└── fixtures/
    └── claude/                  # Mock Claude config repository
```

## Unit Tests (BATS)

Unit tests test individual bash functions in isolation using mocked dependencies.

### Running Unit Tests

```bash
# Via test runner
./tests/run_tests.sh --unit-only

# Directly with BATS
bats tests/install.bats

# Run specific test
bats -f "process_template" tests/install.bats
```

### What's Tested

- **OS Detection**: `detect_os()` correctly identifies macOS, Ubuntu, and Linux
- **Template Processing**: `process_template()` substitutes environment variables
- **Claude File Sync**: `sync_claude_file()` uses repo-specific or falls back to default
- **Claude Component Sync**: `sync_claude_component()` syncs directories with fallback
- **CONFIG_MODE Logic**: Package installation varies based on CONFIG_MODE
- **Git Operations**: Clone and pull operations for Claude config repo

### Test Coverage

Current coverage includes:
- ✅ OS detection (macOS, Ubuntu, Linux)
- ✅ Template variable substitution
- ✅ Layered fallback for Claude components
- ✅ Repo-specific vs default file selection
- ✅ Directory sync with --delete flag
- ✅ CONFIG_MODE conditional logic
- ✅ Git clone vs pull logic

### Adding New Unit Tests

Add tests to `tests/install.bats`:

```bash
@test "description of what you're testing" {
  # Arrange
  export TEST_VAR="value"
  setup_test_fixture

  # Act
  run function_to_test

  # Assert
  [ "$status" -eq 0 ]
  [ "$output" = "expected output" ]
}
```

## Integration Tests (Docker)

Integration tests run the full installation script in Docker containers simulating different operating systems.

### Running Integration Tests

```bash
# All integration tests
./tests/run_tests.sh --integration-only

# Ubuntu only
./tests/run_tests.sh --ubuntu-only

# Codespaces only
./tests/run_tests.sh --codespaces-only
```

### What's Tested

- Full installation process from start to finish
- Package manager installation (Homebrew on Codespaces, apt on Ubuntu)
- Core package installation
- Config file copying
- Oh My Zsh installation
- Tmux plugin installation
- NvChad installation
- Claude configuration sync
- CONFIG_MODE specific behavior
- Idempotency (re-running install.sh)

### Test Scenarios

1. **Ubuntu 22.04** (`Dockerfile.ubuntu`)
   - Uses apt package manager
   - Tests default CONFIG_MODE
   - Verifies core packages installation
   - Tests config file deployment

2. **GitHub Codespaces** (`Dockerfile.codespaces`)
   - Uses Homebrew (Linux)
   - Tests VideoAmp/central CONFIG_MODE
   - Verifies work-specific packages
   - Tests conditional alias loading

### Integration Test Output

The integration test script provides colored output:
- 🟢 `✓` = Test passed
- 🔴 `✗` = Test failed
- 🟡 `ℹ` = Information/optional check

Example output:
```
==========================================
Integration Test for install.sh
CONFIG_MODE: default
OS: Linux x86_64
==========================================
ℹ Running pre-installation checks...
✓ install.sh exists
✓ install.sh is executable
...
==========================================
Test Summary
==========================================
Passed: 25
Failed: 0
==========================================
All tests passed!
```

## Mock Claude Repository

For testing, we use a mock Claude configuration repository in `tests/fixtures/claude/`.

### Structure

```
tests/fixtures/claude/
├── default/
│   ├── settings.json.template
│   ├── CLAUDE.md
│   ├── agents/
│   ├── commands/
│   └── ...
├── VideoAmp/
│   └── central/
│       ├── settings.json.template
│       └── ...
└── peter-trerotola/
    └── quantum-2123/
        └── ...
```

The fixture is automatically created by `setup_claude_fixture()` in `helpers.bash`.

## Continuous Integration

### GitHub Actions (Example)

```yaml
name: Test Dotfiles

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install BATS
        run: |
          sudo apt-get update
          sudo apt-get install -y bats

      - name: Run Unit Tests
        run: ./tests/run_tests.sh --unit-only

      - name: Run Integration Tests
        run: ./tests/run_tests.sh --integration-only
```

## Troubleshooting

### BATS Tests Failing

**Problem**: Tests fail with "command not found: bats"
**Solution**: Install BATS using instructions above

**Problem**: Tests fail with mock-related errors
**Solution**: Ensure `tests/helpers.bash` is in the same directory as `install.bats`

### Docker Tests Failing

**Problem**: Docker build fails
**Solution**: Ensure Docker daemon is running: `docker ps`

**Problem**: Integration tests timeout
**Solution**: First run may be slow due to package downloads. Subsequent runs use Docker cache.

**Problem**: Permission errors in Docker
**Solution**: Tests run as non-root user. If issues persist, check Dockerfile USER directives.

### Fixture Issues

**Problem**: Claude fixture not found
**Solution**: Fixture is auto-created. Ensure `setup_claude_fixture()` is called before tests that need it.

## Test Development Workflow

1. **Write test first** (TDD approach)
   ```bash
   # Add test to tests/install.bats
   @test "new feature works" {
     run new_function
     [ "$status" -eq 0 ]
   }
   ```

2. **Run test to see it fail**
   ```bash
   bats tests/install.bats -f "new feature"
   ```

3. **Implement feature in install.sh**

4. **Run test to see it pass**
   ```bash
   bats tests/install.bats -f "new feature"
   ```

5. **Run full test suite**
   ```bash
   ./tests/run_tests.sh
   ```

## Best Practices

1. **Keep tests independent** - Each test should set up and tear down its own environment
2. **Use descriptive test names** - Test names should clearly describe what's being tested
3. **Test edge cases** - Include tests for error conditions and boundary cases
4. **Mock external dependencies** - Don't rely on network or external services in unit tests
5. **Use integration tests sparingly** - They're slower; use unit tests for detailed logic testing
6. **Keep fixtures minimal** - Only include what's necessary for tests to pass

## Performance

- **Unit tests**: ~5-10 seconds for full suite
- **Integration tests**: ~2-5 minutes per OS (first run), ~30-60 seconds (cached)
- **Full suite**: ~5-10 minutes (first run), ~2-3 minutes (cached)

## Contributing

When adding new features to `install.sh`:

1. Add unit tests in `tests/install.bats`
2. Add integration test assertions in `tests/integration_test.sh` if needed
3. Update this README if adding new test files or scenarios
4. Ensure all tests pass before committing

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Bash Testing Guide](https://github.com/bats-core/bats-core#writing-tests)
