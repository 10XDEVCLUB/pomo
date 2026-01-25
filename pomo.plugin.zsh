# pomo - A Pomodoro timer with shell integrations
# https://github.com/pomopomo-app/pomo-zsh

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

# Source event sourcing (DuckDB integration)
source "${_POMO_PLUGIN_DIR}/lib/events.zsh"

# Add functions directory to fpath for autoloading
fpath=("${_POMO_PLUGIN_DIR}/functions" $fpath)

# Autoload the p10k segment function
autoload -Uz prompt_pomodoro instant_prompt_pomodoro

# Parse tags from arguments (e.g., +project +coding)
_pomo_parse_tags() {
  local tags="[]"
  local tag_array=()

  for arg in "$@"; do
    if [[ "$arg" == +* ]]; then
      tag_array+=("\"${arg#+}\"")
    fi
  done

  if [[ ${#tag_array[@]} -gt 0 ]]; then
    tags="[$(IFS=,; echo "${tag_array[*]}")]"
  fi

  echo "$tags"
}

# Main pomo command
pomo() {
  local cmd="${1:-}"
  shift 2>/dev/null

  case "$cmd" in
    start)
      local type="${1:-work}"
      shift 2>/dev/null
      local tags=$(_pomo_parse_tags "$@")

      case "$type" in
        work)       _pomo_start_work "$tags" ;;
        break)      _pomo_start_break "short" ;;
        long-break) _pomo_start_break "long" ;;
        +*)
          # If first arg is a tag, assume work session
          tags=$(_pomo_parse_tags "$type" "$@")
          _pomo_start_work "$tags"
          ;;
        *)
          echo "Unknown start type: $type"
          echo "Usage: pomo start [work|break|long-break] [+tag1 +tag2 ...]"
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
        echo "Usage: pomo timer <duration> [+tag1 +tag2 ...]"
        echo "Examples: pomo timer 10m, pomo timer 1h30m +meeting"
        return 1
      fi
      local duration="$1"
      shift
      local tags=$(_pomo_parse_tags "$@")
      _pomo_start_timer "$duration" "$tags"
      ;;

    stopwatch|sw|track)
      local tags=$(_pomo_parse_tags "$@")
      _pomo_start_stopwatch "$tags"
      ;;

    history|h)
      _pomo_show_history
      ;;

    config|c)
      _pomo_config
      ;;

    # New event-sourcing commands
    query|q)
      if [[ -z "$1" ]]; then
        echo "Usage: pomo query \"SQL statement\""
        echo "Example: pomo query \"SELECT * FROM events LIMIT 10\""
        return 1
      fi
      _pomo_query "$1"
      ;;

    db)
      _pomo_db_shell
      ;;

    today)
      _pomo_query_today
      ;;

    recent)
      _pomo_query_recent "${1:-10}"
      ;;

    migrate)
      _pomo_migrate_history_to_events
      ;;

    context)
      # Show current detected context
      _pomo_detect_context | jq .
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

Timer Commands:
  start [work|break|long-break] [+tags]  Start a pomodoro session (default: work)
  stop                                   Stop the current timer
  pause                                  Pause the current timer
  resume                                 Resume a paused timer
  skip                                   Skip to the next phase
  status, s                              Show current timer status
  timer, t <duration> [+tags]            Start a one-off countdown
  stopwatch, sw, track [+tags]           Start a count-up stopwatch/tracker

Data Commands:
  today                          Show today's sessions summary
  recent [n]                     Show n most recent sessions (default: 10)
  history, h                     Show today's history (legacy format)
  query, q "SQL"                 Run a SQL query against the events database
  db                             Open DuckDB shell for interactive queries
  context                        Show current detected context (git, directory)
  migrate                        Migrate legacy history file to events database

Config Commands:
  config, c                      Show current configuration
  test-notify                    Test notifications and sounds
  help                           Show this help message

Tags:
  Add tags with + prefix: pomo start +project +coding
  Tags are stored with sessions and can be queried

Duration formats:
  25m, 1h, 1h30m, 90s, 300 (seconds)

Examples:
  pomo start                     Start a 25-minute work session
  pomo start +client-a +feature  Start work with tags
  pomo start break               Start a 5-minute break
  pomo timer 10m +meeting        Start a 10-minute timer with tag
  pomo track +deep-work          Start tracking time (stopwatch)
  pomo today                     Show today's session summary
  pomo query "SELECT * FROM events WHERE type='session.started'"

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

    # Refresh the prompt display
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
