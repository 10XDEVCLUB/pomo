# pomo - A Pomodoro timer with shell integrations
# https://github.com/10xdevclub/pomo

# Get the directory where this plugin is installed
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"
_POMO_PLUGIN_DIR="${0:h}"

# Source configuration (with defaults)
source "${_POMO_PLUGIN_DIR}/lib/config.zsh"

# Source core functions
source "${_POMO_PLUGIN_DIR}/lib/core.zsh"

# Source notification functions
source "${_POMO_PLUGIN_DIR}/lib/notifications.zsh"

# Add functions directory to fpath for autoloading
fpath=("${_POMO_PLUGIN_DIR}/functions" $fpath)

# Autoload the p10k segment function
autoload -Uz prompt_pomodoro instant_prompt_pomodoro

# Main pomo command
pomo() {
  local cmd="${1:-}"
  shift 2>/dev/null

  case "$cmd" in
    start)
      local type="${1:-work}"
      case "$type" in
        work)       _pomo_start_work ;;
        break)      _pomo_start_break "short" ;;
        long-break) _pomo_start_break "long" ;;
        *)
          echo "Unknown start type: $type"
          echo "Usage: pomo start [work|break|long-break]"
          return 1
          ;;
      esac
      ;;

    stop)
      _pomo_stop
      ;;

    pause)
      _pomo_pause
      ;;

    resume)
      _pomo_resume
      ;;

    skip)
      _pomo_skip
      ;;

    status|s)
      _pomo_status
      ;;

    timer|t)
      if [[ -z "$1" ]]; then
        echo "Usage: pomo timer <duration>"
        echo "Examples: pomo timer 10m, pomo timer 1h30m, pomo timer 90s"
        return 1
      fi
      _pomo_start_timer "$1"
      ;;

    stopwatch|sw)
      _pomo_start_stopwatch
      ;;

    history|h)
      _pomo_show_history
      ;;

    config|c)
      _pomo_config
      ;;

    test-notify)
      _pomo_test_notify
      ;;

    help|--help|-h)
      _pomo_help
      ;;

    "")
      # No argument - show status if running, otherwise show help
      _pomo_read_state
      if [[ "$POMO_STATUS" != "stopped" ]]; then
        _pomo_status
      else
        _pomo_help
      fi
      ;;

    *)
      echo "Unknown command: $cmd"
      _pomo_help
      return 1
      ;;
  esac
}

# Help text
_pomo_help() {
  cat <<'EOF'
pomo - Pomodoro timer with shell integrations

Usage: pomo <command> [options]

Commands:
  start [work|break|long-break]  Start a pomodoro session (default: work)
  stop                           Stop the current timer
  pause                          Pause the current timer
  resume                         Resume a paused timer
  skip                           Skip to the next phase
  status, s                      Show current timer status
  timer, t <duration>            Start a one-off countdown
  stopwatch, sw                  Start a count-up stopwatch
  history, h                     Show today's completed sessions
  config, c                      Show current configuration
  test-notify                    Test notifications and sounds
  help                           Show this help message

Duration formats:
  25m, 1h, 1h30m, 90s, 300 (seconds)

Examples:
  pomo start                     Start a 25-minute work session
  pomo start break               Start a 5-minute break
  pomo timer 10m                 Start a 10-minute timer
  pomo pause                     Pause the current timer
  pomo skip                      Skip to break (or next work session)

Add 'pomodoro' to POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS in your .p10k.zsh
EOF
}

# Ensure state directory exists on load
_pomo_ensure_dirs

# Real-time prompt refresh (experimental)
# Updates the timer display every second while idle at prompt

# Function to enable real-time mode - can be called after plugin loads
pomo_enable_realtime() {
  # Prevent double initialization
  (( _POMO_REALTIME_ENABLED )) && return 0
  typeset -g _POMO_REALTIME_ENABLED=1

  # Enable prompt substitution (required for variable expansion in prompts)
  setopt prompt_subst

  # Set TMOUT if not already set
  [[ -z "$TMOUT" ]] && TMOUT=1

  # Create the refresh widget if zle is available
  _pomo_refresh_widget() {
    # Only refresh if a timer is actually running
    _pomo_read_state 2>/dev/null
    [[ "$POMO_STATUS" != "running" && "$POMO_STATUS" != "paused" ]] && return

    # Update the segment display variables
    _pomo_update_segment 2>/dev/null

    # Force p10k to rebuild prompts, then reset display
    (( ${+functions[powerlevel9k_prepare_prompts]} )) && powerlevel9k_prepare_prompts
    zle .reset-prompt && zle -R
  }
  zle -N _pomo_refresh_widget

  # Set up TRAPALRM, chaining with any existing handler
  if (( ${+functions[TRAPALRM]} )) && [[ "${functions[TRAPALRM]}" != *"_pomo_refresh_widget"* ]]; then
    functions[_pomo_orig_trapalrm]="${functions[TRAPALRM]}"
    TRAPALRM() {
      _pomo_orig_trapalrm "$@"
      zle && zle _pomo_refresh_widget
    }
  elif ! (( ${+functions[TRAPALRM]} )); then
    TRAPALRM() {
      zle && zle _pomo_refresh_widget
    }
  fi

}

# Auto-enable if POMODORO_REALTIME is already set
if [[ "$POMODORO_REALTIME" == "true" ]]; then
  pomo_enable_realtime
else
  # Check on first prompt if POMODORO_REALTIME was set after plugin load
  _pomo_check_realtime() {
    [[ "$POMODORO_REALTIME" == "true" ]] && pomo_enable_realtime
    # Remove this hook after first check
    precmd_functions=(${precmd_functions:#_pomo_check_realtime})
  }
  precmd_functions+=(_pomo_check_realtime)
fi
