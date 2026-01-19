#!/usr/bin/env zsh
# Test bootstrap file for pomo
# This sets up an isolated testing environment

# Get the plugin directory (two levels up from tests/_support)
POMO_TEST_DIR="${0:A:h:h:h}"

# Create a temporary directory for test state
export POMO_TEST_STATE_DIR=$(mktemp -d)
export POMODORO_STATE_DIR="$POMO_TEST_STATE_DIR"

# Disable notifications and sounds during tests
export POMODORO_NOTIFY_ENABLED="false"
export POMODORO_SOUND_ENABLED="false"

# Set standard test durations
export POMODORO_WORK_DURATION=1500
export POMODORO_SHORT_BREAK=300
export POMODORO_LONG_BREAK=900
export POMODORO_CYCLES_BEFORE_LONG=4

# Disable auto-start features for predictable tests
export POMODORO_AUTO_START_BREAK="false"
export POMODORO_AUTO_START_WORK="false"

# Source the plugin files directly (not the main plugin to avoid migration)
source "${POMO_TEST_DIR}/lib/config.zsh"
source "${POMO_TEST_DIR}/lib/core.zsh"
source "${POMO_TEST_DIR}/lib/notifications.zsh"

# Helper function to clean up test state between tests
pomo_test_cleanup() {
  # Use nullglob to avoid errors when directory is empty
  setopt localoptions nullglob
  rm -rf "$POMO_TEST_STATE_DIR"/* 2>/dev/null || true
  # Reset global state variables
  POMO_MODE=""
  POMO_STATUS="stopped"
  POMO_START_TIME=0
  POMO_DURATION=0
  POMO_PAUSE_TIME=0
  POMO_PAUSE_ELAPSED=0
  POMO_CYCLE_COUNT=0
  POMO_SESSION_WORK_COUNT=0
}

# Helper function to mock _pomo_now for time-dependent tests
# Usage: pomo_mock_time 1234567890
pomo_mock_time() {
  local mock_time="$1"
  eval "_pomo_now() { echo $mock_time; }"
}

# Helper to restore real time
pomo_restore_time() {
  eval '_pomo_now() { date +%s; }'
}

# Helper to create a state file directly for testing
pomo_set_state() {
  local mode="$1"
  local status="$2"
  local start_time="${3:-0}"
  local duration="${4:-0}"
  local pause_time="${5:-0}"
  local pause_elapsed="${6:-0}"
  local cycle_count="${7:-0}"
  local session_work_count="${8:-0}"

  POMO_MODE="$mode"
  POMO_STATUS="$status"
  POMO_START_TIME="$start_time"
  POMO_DURATION="$duration"
  POMO_PAUSE_TIME="$pause_time"
  POMO_PAUSE_ELAPSED="$pause_elapsed"
  POMO_CYCLE_COUNT="$cycle_count"
  POMO_SESSION_WORK_COUNT="$session_work_count"

  _pomo_write_state
}

# Clean up on test exit
trap 'rm -rf "$POMO_TEST_STATE_DIR"' EXIT
