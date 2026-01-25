#!/bin/zsh
# Pomo cycle test script
# Sets up quick work/break cycles for testing
# Run: source scripts/test_pomodoro_cycle.zsh

echo "=== Pomo Cycle Test Setup ==="
echo ""

# Override durations for quick testing
export POMODORO_WORK_DURATION=30        # 30 seconds
export POMODORO_SHORT_BREAK=5           # 5 seconds
export POMODORO_LONG_BREAK=10           # 10 seconds
export POMODORO_CYCLES_BEFORE_LONG=2    # Long break after 2 work sessions

# Enable auto-start for continuous cycling
export POMODORO_AUTO_START_BREAK=true
export POMODORO_AUTO_START_WORK=true

# Enable real-time countdown
export POMODORO_REALTIME=true

# Enable notifications and sounds
export POMODORO_SOUND_ENABLED=true
export POMODORO_NOTIFY_ENABLED=true

echo "Configuration set:"
echo "  Work duration:     ${POMODORO_WORK_DURATION}s"
echo "  Short break:       ${POMODORO_SHORT_BREAK}s"
echo "  Long break:        ${POMODORO_LONG_BREAK}s"
echo "  Cycles before long: ${POMODORO_CYCLES_BEFORE_LONG}"
echo "  Auto-start break:  ${POMODORO_AUTO_START_BREAK}"
echo "  Auto-start work:   ${POMODORO_AUTO_START_WORK}"
echo "  Real-time:         ${POMODORO_REALTIME}"
echo ""

# Enable real-time if not already enabled
if [[ -z "$_POMO_REALTIME_ENABLED" ]]; then
  if (( ${+functions[pomo_enable_realtime]} )); then
    pomo_enable_realtime
  else
    echo "WARNING: pomo_enable_realtime not available"
  fi
fi

echo ""
echo "Ready to test! Run:"
echo "  pomo start          # Start 30s work session"
echo "  pomo stop           # Stop the cycle"
echo ""
echo "Expected cycle:"
echo "  Work (30s) -> Break (5s) -> Work (30s) -> Long Break (10s) -> ..."
