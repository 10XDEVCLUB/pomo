#!/usr/bin/env zsh
# Test runner script for pomo
#
# Usage:
#   ./run-tests.zsh           # Run all tests
#   ./run-tests.zsh <file>    # Run specific test file
#
# Dependencies are automatically installed if missing:
#   - zunit (test framework)
#   - revolver (spinner for zunit)
#
# Optional dependencies for full test coverage:
#   - duckdb (event sourcing tests)
#   - jq (context detection tests)

set -e

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

# Install revolver if missing (required by zunit)
if [[ ! -d ".revolver" ]]; then
  echo "Installing revolver (zunit dependency)..."
  git clone --depth 1 https://github.com/molovo/revolver.git .revolver
  echo ""
fi

# Add revolver to PATH
export PATH="$SCRIPT_DIR/.revolver:$PATH"

# Install zunit if missing
if [[ ! -x ".zunit-framework/zunit" ]] && ! command -v zunit &>/dev/null; then
  echo "Installing zunit test framework..."
  git clone --depth 1 https://github.com/zunit-zsh/zunit.git .zunit-framework
  echo ""
fi

# Find zunit
ZUNIT=""
if [[ -x ".zunit-framework/zunit" ]]; then
  ZUNIT=".zunit-framework/zunit"
elif command -v zunit &>/dev/null; then
  ZUNIT="zunit"
else
  echo "Error: zunit installation failed"
  exit 1
fi

# Check optional dependencies
echo "Checking dependencies..."
if command -v duckdb &>/dev/null; then
  echo "  duckdb: $(duckdb --version 2>/dev/null | head -1)"
else
  echo "  duckdb: not installed (event tests will be skipped)"
fi

if command -v jq &>/dev/null; then
  echo "  jq: $(jq --version 2>/dev/null)"
else
  echo "  jq: not installed (context tests will be skipped)"
fi
echo ""

echo "Running pomo unit tests with zunit..."
echo ""

# Run tests
if [[ -n "$1" ]]; then
  # Run specific test file
  "$ZUNIT" "$1"
else
  # Run all tests
  "$ZUNIT"
fi
