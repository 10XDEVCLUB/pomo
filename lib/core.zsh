# pomo core timer logic

# State file path
_pomo_state_file() {
  echo "${POMODORO_STATE_DIR}/state"
}

_pomo_history_file() {
  echo "${POMODORO_STATE_DIR}/history"
}

# Ensure state directory exists
_pomo_ensure_dirs() {
  mkdir -p "$POMODORO_STATE_DIR"
}

# Parse duration string to seconds
# Supports: 25m, 1h, 1h30m, 90s, 90 (bare number = seconds)
_pomo_parse_duration() {
  local input="$1"
  local total=0

  # Remove spaces
  input="${input// /}"

  # If just a number, treat as seconds
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "$input"
    return 0
  fi

  # Parse hours
  if [[ "$input" =~ ([0-9]+)h ]]; then
    (( total += ${match[1]} * 3600 ))
  fi

  # Parse minutes
  if [[ "$input" =~ ([0-9]+)m ]]; then
    (( total += ${match[1]} * 60 ))
  fi

  # Parse seconds
  if [[ "$input" =~ ([0-9]+)s ]]; then
    (( total += ${match[1]} ))
  fi

  if [[ $total -eq 0 ]]; then
    echo "0"
    return 1
  fi

  echo "$total"
}

# Format seconds to MM:SS or HH:MM:SS
_pomo_format_time() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local mins=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))

  if [[ $hours -gt 0 ]]; then
    printf "%d:%02d:%02d" $hours $mins $secs
  else
    printf "%02d:%02d" $mins $secs
  fi
}

# Write state to file
_pomo_write_state() {
  _pomo_ensure_dirs
  local state_file="$(_pomo_state_file)"

  cat > "$state_file" <<EOF
POMO_MODE="$POMO_MODE"
POMO_STATUS="$POMO_STATUS"
POMO_START_TIME="$POMO_START_TIME"
POMO_DURATION="$POMO_DURATION"
POMO_PAUSE_TIME="$POMO_PAUSE_TIME"
POMO_PAUSE_ELAPSED="$POMO_PAUSE_ELAPSED"
POMO_CYCLE_COUNT="$POMO_CYCLE_COUNT"
POMO_SESSION_WORK_COUNT="$POMO_SESSION_WORK_COUNT"
EOF
}

# Read state from file
_pomo_read_state() {
  local state_file="$(_pomo_state_file)"

  # Reset to defaults
  POMO_MODE=""
  POMO_STATUS="stopped"
  POMO_START_TIME=0
  POMO_DURATION=0
  POMO_PAUSE_TIME=0
  POMO_PAUSE_ELAPSED=0
  POMO_CYCLE_COUNT=0
  POMO_SESSION_WORK_COUNT=0

  if [[ -f "$state_file" ]]; then
    source "$state_file"
  fi
}

# Clear state
_pomo_clear_state() {
  local state_file="$(_pomo_state_file)"
  [[ -f "$state_file" ]] && rm -f "$state_file"

  POMO_MODE=""
  POMO_STATUS="stopped"
  POMO_START_TIME=0
  POMO_DURATION=0
  POMO_PAUSE_TIME=0
  POMO_PAUSE_ELAPSED=0
}

# Get current timestamp
_pomo_now() {
  date +%s
}

# Calculate remaining time
_pomo_remaining() {
  _pomo_read_state

  if [[ "$POMO_STATUS" != "running" && "$POMO_STATUS" != "paused" ]]; then
    echo "0"
    return 1
  fi

  local now=$(_pomo_now)
  local elapsed

  if [[ "$POMO_STATUS" == "paused" ]]; then
    elapsed=$POMO_PAUSE_ELAPSED
  else
    elapsed=$((now - POMO_START_TIME + POMO_PAUSE_ELAPSED))
  fi

  local remaining=$((POMO_DURATION - elapsed))

  if [[ $remaining -lt 0 ]]; then
    remaining=0
  fi

  echo "$remaining"
}

# Calculate elapsed time (for stopwatch)
_pomo_elapsed() {
  _pomo_read_state

  if [[ "$POMO_STATUS" != "running" && "$POMO_STATUS" != "paused" ]]; then
    echo "0"
    return 1
  fi

  local now=$(_pomo_now)
  local elapsed

  if [[ "$POMO_STATUS" == "paused" ]]; then
    elapsed=$POMO_PAUSE_ELAPSED
  else
    elapsed=$((now - POMO_START_TIME + POMO_PAUSE_ELAPSED))
  fi

  echo "$elapsed"
}

# Check if timer has completed
_pomo_is_completed() {
  _pomo_read_state

  if [[ "$POMO_STATUS" != "running" ]]; then
    return 1
  fi

  # Stopwatch never completes
  if [[ "$POMO_MODE" == "stopwatch" ]]; then
    return 1
  fi

  local remaining=$(_pomo_remaining)
  [[ $remaining -le 0 ]]
}

# Start a pomodoro work session
_pomo_start_work() {
  _pomo_read_state

  POMO_MODE="work"
  POMO_STATUS="running"
  POMO_START_TIME=$(_pomo_now)
  POMO_DURATION=$POMODORO_WORK_DURATION
  POMO_PAUSE_TIME=0
  POMO_PAUSE_ELAPSED=0

  _pomo_write_state
  echo "Started pomodoro work session ($(_pomo_format_time $POMO_DURATION))"
}

# Start a break
_pomo_start_break() {
  _pomo_read_state

  local break_type="${1:-short}"

  POMO_MODE="break"
  POMO_STATUS="running"
  POMO_START_TIME=$(_pomo_now)
  POMO_PAUSE_TIME=0
  POMO_PAUSE_ELAPSED=0

  if [[ "$break_type" == "long" ]]; then
    POMO_DURATION=$POMODORO_LONG_BREAK
    echo "Started long break ($(_pomo_format_time $POMO_DURATION))"
  else
    POMO_DURATION=$POMODORO_SHORT_BREAK
    echo "Started short break ($(_pomo_format_time $POMO_DURATION))"
  fi

  _pomo_write_state
}

# Start a generic timer
_pomo_start_timer() {
  local duration_str="$1"
  local duration=$(_pomo_parse_duration "$duration_str")

  if [[ $duration -eq 0 ]]; then
    echo "Invalid duration: $duration_str"
    echo "Examples: 10m, 1h30m, 90s, 300"
    return 1
  fi

  POMO_MODE="timer"
  POMO_STATUS="running"
  POMO_START_TIME=$(_pomo_now)
  POMO_DURATION=$duration
  POMO_PAUSE_TIME=0
  POMO_PAUSE_ELAPSED=0
  POMO_CYCLE_COUNT=0
  POMO_SESSION_WORK_COUNT=0

  _pomo_write_state
  echo "Timer started: $(_pomo_format_time $duration)"
}

# Start stopwatch (count up)
_pomo_start_stopwatch() {
  POMO_MODE="stopwatch"
  POMO_STATUS="running"
  POMO_START_TIME=$(_pomo_now)
  POMO_DURATION=0
  POMO_PAUSE_TIME=0
  POMO_PAUSE_ELAPSED=0
  POMO_CYCLE_COUNT=0
  POMO_SESSION_WORK_COUNT=0

  _pomo_write_state
  echo "Stopwatch started"
}

# Stop the timer
_pomo_stop() {
  _pomo_read_state

  if [[ "$POMO_STATUS" == "stopped" ]]; then
    echo "No timer running"
    return 1
  fi

  local elapsed=$(_pomo_elapsed)
  echo "Stopped after $(_pomo_format_time $elapsed)"

  _pomo_clear_state
}

# Pause the timer
_pomo_pause() {
  _pomo_read_state

  if [[ "$POMO_STATUS" != "running" ]]; then
    echo "No timer running to pause"
    return 1
  fi

  local now=$(_pomo_now)
  POMO_PAUSE_ELAPSED=$((now - POMO_START_TIME + POMO_PAUSE_ELAPSED))
  POMO_PAUSE_TIME=$now
  POMO_STATUS="paused"

  _pomo_write_state
  echo "Timer paused at $(_pomo_format_time $POMO_PAUSE_ELAPSED)"
}

# Resume the timer
_pomo_resume() {
  _pomo_read_state

  if [[ "$POMO_STATUS" != "paused" ]]; then
    echo "No timer paused to resume"
    return 1
  fi

  POMO_START_TIME=$(_pomo_now)
  POMO_STATUS="running"

  _pomo_write_state
  echo "Timer resumed"
}

# Skip to next phase (for pomodoro)
_pomo_skip() {
  _pomo_read_state

  if [[ "$POMO_STATUS" == "stopped" ]]; then
    echo "No timer running"
    return 1
  fi

  if [[ "$POMO_MODE" == "work" ]]; then
    # Increment work count
    (( POMO_SESSION_WORK_COUNT++ ))
    (( POMO_CYCLE_COUNT++ ))

    # Log completed work session
    _pomo_log_session "work" "$POMO_DURATION"

    # Determine break type
    if [[ $((POMO_CYCLE_COUNT % POMODORO_CYCLES_BEFORE_LONG)) -eq 0 ]]; then
      echo "Work session complete! Starting long break..."
      _pomo_start_break "long"
    else
      echo "Work session complete! Starting short break..."
      _pomo_start_break "short"
    fi
  elif [[ "$POMO_MODE" == "break" ]]; then
    _pomo_log_session "break" "$POMO_DURATION"
    echo "Break complete! Starting work session..."
    _pomo_start_work
  else
    echo "Skip only works in pomodoro mode"
    return 1
  fi
}

# Handle timer completion
_pomo_handle_completion() {
  _pomo_read_state

  if [[ "$POMO_MODE" == "work" ]]; then
    (( POMO_SESSION_WORK_COUNT++ ))
    (( POMO_CYCLE_COUNT++ ))
    _pomo_log_session "work" "$POMO_DURATION"

    # Notify
    _pomo_alert "work_end"

    if [[ "$POMODORO_AUTO_START_BREAK" == "true" ]]; then
      if [[ $((POMO_CYCLE_COUNT % POMODORO_CYCLES_BEFORE_LONG)) -eq 0 ]]; then
        _pomo_start_break "long"
      else
        _pomo_start_break "short"
      fi
    else
      _pomo_clear_state
    fi
  elif [[ "$POMO_MODE" == "break" ]]; then
    _pomo_log_session "break" "$POMO_DURATION"
    _pomo_alert "break_end"

    if [[ "$POMODORO_AUTO_START_WORK" == "true" ]]; then
      _pomo_start_work
    else
      _pomo_clear_state
    fi
  elif [[ "$POMO_MODE" == "timer" ]]; then
    _pomo_alert "timer_end"
    _pomo_clear_state
  fi
}

# Log completed session to history
_pomo_log_session() {
  _pomo_ensure_dirs
  local type="$1"
  local duration="$2"
  local history_file="$(_pomo_history_file)"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  echo "$timestamp|$type|$duration" >> "$history_file"
}

# Show today's history
_pomo_show_history() {
  local history_file="$(_pomo_history_file)"
  local today=$(date +"%Y-%m-%d")

  if [[ ! -f "$history_file" ]]; then
    echo "No history yet"
    return
  fi

  local work_count=0
  local work_time=0
  local break_time=0

  while IFS='|' read -r timestamp type duration; do
    if [[ "$timestamp" == "$today"* ]]; then
      if [[ "$type" == "work" ]]; then
        (( work_count++ ))
        (( work_time += duration ))
      elif [[ "$type" == "break" ]]; then
        (( break_time += duration ))
      fi
    fi
  done < "$history_file"

  echo "Today's pomodoro sessions:"
  echo "  Work sessions: $work_count"
  echo "  Total work time: $(_pomo_format_time $work_time)"
  echo "  Total break time: $(_pomo_format_time $break_time)"
}

# Show current status
_pomo_status() {
  _pomo_read_state

  if [[ "$POMO_STATUS" == "stopped" ]]; then
    echo "No timer running"
    _pomo_show_history
    return
  fi

  local mode_display
  case "$POMO_MODE" in
    work)      mode_display="Work session" ;;
    break)     mode_display="Break" ;;
    timer)     mode_display="Timer" ;;
    stopwatch) mode_display="Stopwatch" ;;
    *)         mode_display="$POMO_MODE" ;;
  esac

  echo "Mode: $mode_display"
  echo "Status: $POMO_STATUS"

  if [[ "$POMO_MODE" == "stopwatch" ]]; then
    echo "Elapsed: $(_pomo_format_time $(_pomo_elapsed))"
  else
    echo "Remaining: $(_pomo_format_time $(_pomo_remaining))"
  fi

  if [[ "$POMO_MODE" == "work" || "$POMO_MODE" == "break" ]]; then
    echo "Cycle: $POMO_CYCLE_COUNT / $POMODORO_CYCLES_BEFORE_LONG"
    echo "Work sessions today: $POMO_SESSION_WORK_COUNT"
  fi
}

# Show/edit configuration
_pomo_config() {
  echo "Current configuration:"
  echo "  Work duration:     $(_pomo_format_time $POMODORO_WORK_DURATION)"
  echo "  Short break:       $(_pomo_format_time $POMODORO_SHORT_BREAK)"
  echo "  Long break:        $(_pomo_format_time $POMODORO_LONG_BREAK)"
  echo "  Cycles before long: $POMODORO_CYCLES_BEFORE_LONG"
  echo "  Sound enabled:     $POMODORO_SOUND_ENABLED"
  echo "  Notifications:     $POMODORO_NOTIFY_ENABLED"
  echo "  Auto-start break:  $POMODORO_AUTO_START_BREAK"
  echo "  Auto-start work:   $POMODORO_AUTO_START_WORK"
  echo ""
  echo "To customize, set these variables in your .zshrc before sourcing the plugin."
}
