#!/usr/bin/env zsh
# Test runner script for pomo
#
# Usage:
#   ./run-tests.zsh           # Run all tests
#   ./run-tests.zsh <file>    # Run specific test file
#
# Prerequisites:
#   - zsh installed
#   - zunit installed or .zunit-framework present
#
# Installing zunit:
#   git clone https://github.com/zunit-zsh/zunit.git .zunit-framework
#   cd .zunit-framework && zsh build.zsh

set -e

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR"

# Add local dependencies to PATH
if [[ -d ".revolver" ]]; then
  export PATH="$SCRIPT_DIR/.revolver:$PATH"
fi

# Find zunit
ZUNIT=""
if [[ -x ".zunit-framework/zunit" ]]; then
  ZUNIT=".zunit-framework/zunit"
elif command -v zunit &>/dev/null; then
  ZUNIT="zunit"
else
  echo "Error: zunit not found"
  echo ""
  echo "Install zunit with:"
  echo "  git clone https://github.com/zunit-zsh/zunit.git .zunit-framework"
  echo "  cd .zunit-framework && zsh build.zsh"
  exit 1
fi

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
