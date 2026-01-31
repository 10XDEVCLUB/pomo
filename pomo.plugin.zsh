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

# Autoload the p10k segment functions
autoload -Uz prompt_pomo instant_prompt_pomo
autoload -Uz prompt_pomotags instant_prompt_pomotags
autoload -Uz prompt_pomopomo instant_prompt_pomopomo

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

    flow|f)
      # Parse optional soft target (duration) and tags
      local target=0
      local remaining_args=()

      for arg in "$@"; do
        if [[ "$arg" == +* ]]; then
          # It's a tag, pass through
          remaining_args+=("$arg")
        elif [[ -z "${target//[0-9hms]/}" ]]; then
          # Looks like a duration
          local parsed=$(_pomo_parse_duration "$arg")
          if [[ $parsed -gt 0 ]]; then
            target=$parsed
          else
            remaining_args+=("$arg")
          fi
        else
          remaining_args+=("$arg")
        fi
      done

      local tags=$(_pomo_parse_tags "${remaining_args[@]}")
      _pomo_start_flowtime "$target" "$tags"
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

    yesterday|yd)
      _pomo_query_yesterday
      ;;

    week|wtd)
      _pomo_query_wtd
      ;;

    month|mtd)
      _pomo_query_mtd
      ;;

    recent)
      _pomo_query_recent "${1:-10}"
      ;;

    migrate)
      _pomo_migrate_history_to_events
      ;;

    fix)
      if [[ -z "$1" ]]; then
        # No arguments - show unfixed sessions
        _pomo_show_unfixed
      elif [[ "$1" == "all" ]]; then
        # Fix all unfixed sessions
        shift
        _pomo_fix_all "$1"
      else
        # Fix specific session by index
        local index="$1"
        local action="$2"

        if [[ -z "$action" ]]; then
          echo "Usage: pomo fix <#> <complete|discard|duration>"
          return 1
        fi

        # Get session by index
        local session_json=$(_pomo_get_unfixed_by_index "$index")

        if [[ -z "$session_json" || "$session_json" == "null" ]]; then
          echo "Error: No unfixed session at index $index"
          echo "Run 'pomo fix' to see available sessions"
          return 1
        fi

        local session_id=$(echo "$session_json" | jq -r '.session_id')
        local target_secs=$(echo "$session_json" | jq -r '.target_secs // 0')

        _pomo_fix_session "$session_id" "$action" "$target_secs"
      fi
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
        # Check for unfixed sessions and warn
        local unfixed_count=$(_pomo_count_unfixed 2>/dev/null)
        if [[ "${unfixed_count:-0}" -gt 0 ]]; then
          echo "⚠ ${unfixed_count} unfixed session(s). Run 'pomo fix' to resolve."
          echo ""
        fi
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
  flow, f [duration] [+tags]             Start flowtime (open-ended, optional soft target)

Data Commands:
  today                          Show today's sessions summary
  yesterday, yd                  Show yesterday's sessions summary
  week, wtd                      Show week-to-date summary (since Monday)
  month, mtd                     Show month-to-date summary
  recent [n]                     Show n most recent sessions (default: 10)
  history, h                     Show today's history (legacy format)
  fix                            Show/fix forgotten sessions
  fix <#> complete               Log forgotten session with target duration
  fix <#> <duration>             Log forgotten session with specified duration
  fix <#> discard                Discard forgotten session (not counted)
  fix all discard                Discard all forgotten sessions
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
  pomo flow                      Start open-ended flowtime
  pomo flow 45m +project         Start flowtime with 45min soft target
  pomo today                     Show today's session summary
  pomo query "SELECT * FROM events WHERE type='session.started'"

Add 'pomo' to POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS in your .p10k.zsh
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

    # Refresh the prompt display without causing scrolling
    # Use reset-prompt alone - zle -R can cause display artifacts
    zle .reset-prompt 2>/dev/null
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
