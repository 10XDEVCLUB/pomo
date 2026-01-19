# Contributing to pomo

Thank you for your interest in contributing to pomo! This document provides guidelines and instructions for contributing.

## Development Setup

### Prerequisites

- zsh 5.0 or later
- macOS (for notification and sound features)
- Git

### Clone the Repository

```bash
git clone https://github.com/10xdevclub/pomo.git
cd pomo
```

### Install Test Dependencies

The test suite uses [zunit](https://github.com/zunit-zsh/zunit). Install the dependencies:

```bash
# Clone zunit
git clone --depth 1 https://github.com/zunit-zsh/zunit.git .zunit-framework
cd .zunit-framework && zsh build.zsh && cd ..

# Clone revolver (zunit dependency)
git clone --depth 1 https://github.com/molovo/revolver.git .revolver
```

### Load the Plugin for Development

To test the plugin interactively, source it in your shell:

```bash
source pomo.plugin.zsh
```

## Running Tests

Run the full test suite:

```bash
./run-tests.zsh
```

Run a specific test file:

```bash
./run-tests.zsh tests/parse_duration.zunit
```

### Test Structure

```
tests/
├── _support/
│   └── bootstrap.zsh       # Test helpers and environment setup
├── _output/                # Test output (gitignored)
├── parse_duration.zunit    # Duration parsing tests
├── format_time.zunit       # Time formatting tests
├── state_management.zunit  # State persistence tests
├── timer_operations.zunit  # Timer start/stop/pause/resume tests
├── time_calculations.zunit # Remaining/elapsed time tests
├── skip_cycle.zunit        # Pomodoro cycle tests
├── history.zunit           # Session history tests
└── command_dispatcher.zunit # Main command tests
```

### Writing Tests

Tests use the zunit framework. Here's a basic example:

```zsh
#!/usr/bin/env zunit

@setup {
  load _support/bootstrap.zsh
  pomo_test_cleanup
  pomo_mock_time 1000000
}

@teardown {
  pomo_test_cleanup
  pomo_restore_time
}

@test 'my feature works correctly' {
  run _pomo_start_work
  assert $state equals 0
  assert "$output" contains "Started"
}
```

Key test helpers in `bootstrap.zsh`:
- `pomo_test_cleanup` - Reset state between tests
- `pomo_mock_time <timestamp>` - Mock the current time
- `pomo_restore_time` - Restore real time
- `pomo_set_state <mode> <status> ...` - Set up test state

## Code Style

### Shell Script Guidelines

- Use 2-space indentation
- Use `local` for function-scoped variables
- Prefix internal functions with `_pomo_`
- Use `[[ ]]` for conditionals (zsh-style)
- Quote variables: `"$var"` not `$var`

### Function Documentation

Add a comment above functions explaining their purpose:

```zsh
# Parse duration string to seconds
# Supports: 25m, 1h, 1h30m, 90s, 90 (bare number = seconds)
_pomo_parse_duration() {
  ...
}
```

### Naming Conventions

- Public commands: `pomo <command>`
- Internal functions: `_pomo_<name>`
- Configuration variables: `POMODORO_<NAME>`
- State variables: `POMO_<NAME>`

## Submitting Changes

### Before Submitting

1. **Run the tests** - Ensure all tests pass:
   ```bash
   ./run-tests.zsh
   ```

2. **Test manually** - Load the plugin and verify your changes work:
   ```bash
   source pomo.plugin.zsh
   pomo start work
   pomo status
   ```

3. **Check for regressions** - Test related functionality

### Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Commit with a clear message
7. Push to your fork
8. Open a Pull Request

### Commit Messages

Use clear, descriptive commit messages:

```
Add warning notification before timer ends

- Add POMODORO_WARNING_THRESHOLD config option
- Send notification 1 minute before completion
- Add tests for warning functionality
```

## Project Structure

```
pomo/
├── pomo.plugin.zsh      # Main entry point and command dispatcher
├── lib/
│   ├── config.zsh       # Configuration defaults
│   ├── core.zsh         # Timer logic and state management
│   └── notifications.zsh # macOS notifications and sounds
├── functions/
│   ├── _pomo            # Zsh completion
│   └── prompt_pomodoro  # Powerlevel10k segment
├── tests/               # Test suite
├── sounds/              # Custom sound files (optional)
├── flake.nix            # Nix package definition
└── run-tests.zsh        # Test runner
```

## Areas for Contribution

- **Bug fixes** - Check the issue tracker
- **New features** - Discuss in an issue first
- **Documentation** - README improvements, examples
- **Tests** - Increase coverage, edge cases
- **Platform support** - Linux notifications, other shells

## Questions?

Open an issue for questions or discussion about potential contributions.
