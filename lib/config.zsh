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
: ${POMODORO_REALTIME:=false}             # Real-time countdown (refresh prompt every second)

# Display settings (for p10k segment)
: ${POMODORO_ICON_WORK:="🍅"}
: ${POMODORO_ICON_BREAK:="☕"}
: ${POMODORO_ICON_PAUSED:="⏸"}
: ${POMODORO_ICON_TIMER:="⏱"}
: ${POMODORO_ICON_STOPWATCH:="⏱"}
: ${POMODORO_ICON_FLOWTIME:="🌊"}

# Colors (p10k color codes)
: ${POMODORO_COLOR_WORK:=1}               # Red
: ${POMODORO_COLOR_BREAK:=2}              # Green
: ${POMODORO_COLOR_WARNING:=3}            # Yellow (last minute)
: ${POMODORO_COLOR_PAUSED:=8}             # Gray
: ${POMODORO_COLOR_TIMER:=4}              # Blue
: ${POMODORO_COLOR_FLOWTIME:=6}           # Cyan
: ${POMODORO_COLOR_FLOWTIME_TARGET:=2}    # Green (when soft target met)

# Warning threshold (seconds remaining to show warning color)
: ${POMODORO_WARNING_THRESHOLD:=60}

# Tags display settings
: ${POMODORO_ICON_TAGS:="#"}               # Text-based, works in all terminals
: ${POMODORO_COLOR_TAGS:=5}                # Magenta
: ${POMODORO_TAGS_FORMAT:="pipe"}          # pipe, plus, comma, hash

# Flowtime soft target notification sound
: ${POMODORO_SOUND_FLOWTIME_TARGET:="/System/Library/Sounds/Pop.aiff"}

# Working hours configuration (for forgotten timer detection heuristics)
# Set to empty string to disable working hours detection
: ${POMODORO_WORKING_HOURS_START:=9}       # 9 AM (24h format, 0-23)
: ${POMODORO_WORKING_HOURS_END:=18}        # 6 PM (24h format, 0-23)
: ${POMODORO_WORKING_DAYS:="1,2,3,4,5"}    # Mon=1, Sun=7 (comma-separated)

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
