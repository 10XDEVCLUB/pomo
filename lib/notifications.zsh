# pomo notifications (macOS)

# Send a macOS notification
_pomo_notify() {
  local title="$1"
  local message="$2"
  local subtitle="${3:-}"

  [[ "$POMODORO_NOTIFY_ENABLED" != "true" ]] && return

  if [[ -n "$subtitle" ]]; then
    osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\"" 2>/dev/null &
  else
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null &
  fi
}

# Play a sound file
_pomo_play_sound() {
  local sound_file="$1"

  [[ "$POMODORO_SOUND_ENABLED" != "true" ]] && return
  [[ ! -f "$sound_file" ]] && return

  # Play in background so it doesn't block
  afplay "$sound_file" 2>/dev/null &
}

# Combined alert (notification + sound) for different events
_pomo_alert() {
  local event="$1"

  case "$event" in
    work_end)
      _pomo_notify "Pomodoro" "Work session complete!" "Time for a break"
      _pomo_play_sound "$POMODORO_SOUND_WORK_END"
      ;;
    break_end)
      _pomo_notify "Pomodoro" "Break is over!" "Ready to focus?"
      _pomo_play_sound "$POMODORO_SOUND_BREAK_END"
      ;;
    timer_end)
      _pomo_notify "Timer" "Time's up!" ""
      _pomo_play_sound "$POMODORO_SOUND_TIMER_END"
      ;;
    warning)
      # Optional: 1-minute warning
      _pomo_notify "Pomodoro" "1 minute remaining" ""
      ;;
  esac
}

# Test notifications (useful for debugging)
_pomo_test_notify() {
  echo "Testing notification..."
  _pomo_notify "Test" "This is a test notification" "Subtitle here"
  echo "Testing sound..."
  _pomo_play_sound "$POMODORO_SOUND_WORK_END"
  echo "Done!"
}
