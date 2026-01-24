#!/bin/zsh
# Pomo real-time debug script
# Run: source scripts/debug_realtime.zsh

echo "=== Pomo Real-time Debug ==="
echo ""

# Check p10k functions
echo "1. P10k functions available:"
echo "   - powerlevel9k_prepare_prompts: $(( ${+functions[powerlevel9k_prepare_prompts]} )) (1=yes, 0=no)"
echo "   - p10k: $(( ${+functions[p10k]} )) (1=yes, 0=no)"
echo ""

# Check p10k settings
echo "2. P10k settings:"
echo "   - POWERLEVEL9K_TRANSIENT_PROMPT: ${POWERLEVEL9K_TRANSIENT_PROMPT:-not set}"
echo "   - POWERLEVEL9K_INSTANT_PROMPT: ${POWERLEVEL9K_INSTANT_PROMPT:-not set}"
echo "   - POWERLEVEL9K_DISABLE_HOT_RELOAD: ${POWERLEVEL9K_DISABLE_HOT_RELOAD:-not set}"
echo ""

# Check pomo state
echo "3. Pomo state:"
echo "   - POMODORO_REALTIME: ${POMODORO_REALTIME:-not set}"
echo "   - _POMO_REALTIME_ENABLED: ${_POMO_REALTIME_ENABLED:-not set}"
echo "   - TMOUT: ${TMOUT:-not set}"
echo "   - TRAPALRM defined: $(( ${+functions[TRAPALRM]} )) (1=yes, 0=no)"
echo ""

# Check segment variables
echo "4. Segment variables:"
echo "   - _POMO_SEGMENT_TIME: '${_POMO_SEGMENT_TIME:-not set}'"
echo "   - _POMO_SEGMENT_VISIBLE: ${_POMO_SEGMENT_VISIBLE:-not set}"
echo ""

# Test update function
echo "5. Testing _pomo_update_segment..."
if (( ${+functions[_pomo_update_segment]} )); then
  pomo timer 60s 2>/dev/null
  sleep 1
  _pomo_update_segment
  echo "   Before: $_POMO_SEGMENT_TIME"
  sleep 2
  _pomo_update_segment
  echo "   After 2s: $_POMO_SEGMENT_TIME"
  pomo stop 2>/dev/null
else
  echo "   ERROR: _pomo_update_segment not defined"
fi
echo ""

# Test refresh widget
echo "6. Testing refresh mechanism..."
if (( ${+functions[_pomo_refresh_widget]} )); then
  echo "   _pomo_refresh_widget is available"
else
  echo "   WARNING: _pomo_refresh_widget NOT available"
fi

echo ""
echo "=== Debug complete ==="
echo ""
echo "Troubleshooting tips:"
echo "- If _POMO_REALTIME_ENABLED is not set, check POMODORO_REALTIME is set before plugin loads"
echo "- If TRAPALRM is not defined, try running: pomo_enable_realtime"
echo "- Open a new terminal window to pick up nix/home-manager changes"
