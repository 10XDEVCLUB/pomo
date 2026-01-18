# pomo configuration
# Override these in your .zshrc before sourcing the plugin

# Pomodoro durations (in seconds)
: ${POMODORO_WORK_DURATION:=1500}         # 25 minutes
: ${POMODORO_SHORT_BREAK:=300}            # 5 minutes
: ${POMODORO_LONG_BREAK:=900}             # 15 minutes
: ${POMODORO_CYCLES_BEFORE_LONG:=4}       # Long break after N work sessions

# Sound settings
: ${POMODORO_SOUND_ENABLED:=true}
: ${POMODORO_SOUND_WORK_END:="/System/Library/Sounds/Submarine.aiff"}
: ${POMODORO_SOUND_BREAK_END:="/System/Library/Sounds/Glass.aiff"}
: ${POMODORO_SOUND_TIMER_END:="/System/Library/Sounds/Ping.aiff"}

# Notification settings
: ${POMODORO_NOTIFY_ENABLED:=true}

# Behavior settings
: ${POMODORO_AUTO_START_BREAK:=false}     # Auto-start break after work ends
: ${POMODORO_AUTO_START_WORK:=false}      # Auto-start work after break ends

# Display settings (for p10k segment)
: ${POMODORO_ICON_WORK:="🍅"}
: ${POMODORO_ICON_BREAK:="☕"}
: ${POMODORO_ICON_PAUSED:="⏸"}
: ${POMODORO_ICON_TIMER:="⏱"}
: ${POMODORO_ICON_STOPWATCH:="⏱"}

# Colors (p10k color codes)
: ${POMODORO_COLOR_WORK:=1}               # Red
: ${POMODORO_COLOR_BREAK:=2}              # Green
: ${POMODORO_COLOR_WARNING:=3}            # Yellow (last minute)
: ${POMODORO_COLOR_PAUSED:=8}             # Gray
: ${POMODORO_COLOR_TIMER:=4}              # Blue

# Warning threshold (seconds remaining to show warning color)
: ${POMODORO_WARNING_THRESHOLD:=60}

# State directory (XDG compliant)
: ${POMODORO_STATE_DIR:="${XDG_STATE_HOME:-$HOME/.local/state}/pomo"}

# Migration: move state from old directory if it exists
_pomo_migrate_state() {
  local old_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh-pomodoro-p10k"
  local new_dir="$POMODORO_STATE_DIR"

  # Only migrate if old directory exists and new directory doesn't have state
  if [[ -d "$old_dir" && ! -f "$new_dir/state" ]]; then
    mkdir -p "$new_dir"

    # Move state file if it exists
    if [[ -f "$old_dir/state" ]]; then
      mv "$old_dir/state" "$new_dir/state"
    fi

    # Move history file if it exists
    if [[ -f "$old_dir/history" ]]; then
      mv "$old_dir/history" "$new_dir/history"
    fi

    # Remove old directory if empty
    rmdir "$old_dir" 2>/dev/null

    # Notify user of migration (only once)
    echo "pomo: Migrated state from zsh-pomodoro-p10k to pomo"
  fi
}

# Run migration on load
_pomo_migrate_state
