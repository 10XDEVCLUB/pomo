# pomo event sourcing with DuckDB
# Trial implementation for validating event schema before Rust port

# Database path
: ${POMODORO_DB_PATH:="${POMODORO_STATE_DIR}/pomo.duckdb"}

# Client ID (persistent per machine)
_pomo_client_id_file() {
  echo "${POMODORO_STATE_DIR}/client_id"
}

# Get or create client ID
_pomo_get_client_id() {
  local client_id_file="$(_pomo_client_id_file)"

  if [[ -f "$client_id_file" ]]; then
    cat "$client_id_file"
  else
    _pomo_ensure_dirs
    local client_id=$(_pomo_generate_uuid)
    echo "$client_id" > "$client_id_file"
    echo "$client_id"
  fi
}

# Generate UUID (portable)
_pomo_generate_uuid() {
  if command -v uuidgen &>/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    # Fallback using /dev/urandom
    od -x /dev/urandom 2>/dev/null | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}' | tr '[:upper:]' '[:lower:]'
  fi
}

# Initialize database schema
_pomo_init_db() {
  _pomo_ensure_dirs

  # Check if duckdb is available
  if ! command -v duckdb &>/dev/null; then
    return 1
  fi

  duckdb "$POMODORO_DB_PATH" <<'EOF'
-- Events table (append-only, source of truth)
CREATE TABLE IF NOT EXISTS events (
    id VARCHAR PRIMARY KEY,
    type VARCHAR NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    timestamp TIMESTAMPTZ NOT NULL,
    client_id VARCHAR NOT NULL,
    sequence BIGINT,
    session_id VARCHAR,
    payload JSON NOT NULL,
    context JSON
);

-- Index for common queries
CREATE INDEX IF NOT EXISTS idx_events_type ON events(type);
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON events(timestamp);

-- Sequence counter table
CREATE TABLE IF NOT EXISTS client_sequence (
    client_id VARCHAR PRIMARY KEY,
    last_sequence BIGINT NOT NULL DEFAULT 0
);
EOF
}

# Get next sequence number for this client
_pomo_next_sequence() {
  local client_id="$1"

  duckdb "$POMODORO_DB_PATH" -json <<EOF | jq -r '.[0].seq'
INSERT INTO client_sequence (client_id, last_sequence)
VALUES ('$client_id', 1)
ON CONFLICT (client_id) DO UPDATE SET last_sequence = client_sequence.last_sequence + 1
RETURNING last_sequence as seq;
EOF
}

# Detect git context
_pomo_detect_git_context() {
  local context="{}"

  # Check if in a git repo
  if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    local branch=$(git branch --show-current 2>/dev/null)
    local remote=$(git remote get-url origin 2>/dev/null | sed 's/.*[@:]\([^:]*\)\.git/\1/' | sed 's/.*github.com[:/]//' | sed 's/\.git$//')
    local worktree=$(git rev-parse --show-toplevel 2>/dev/null)
    local dirty_check=$(git status --porcelain 2>/dev/null | head -1)
    local dirty="false"
    [[ -n "$dirty_check" ]] && dirty="true"

    context=$(jq -n \
      --arg branch "$branch" \
      --arg remote "$remote" \
      --arg worktree "$worktree" \
      --arg dirty "$dirty" \
      '{
        git_branch: (if $branch != "" then $branch else null end),
        git_remote: (if $remote != "" then $remote else null end),
        git_worktree: (if $worktree != "" then $worktree else null end),
        git_dirty: ($dirty == "true")
      }')
  fi

  echo "$context"
}

# Detect full context
_pomo_detect_context() {
  local git_context=$(_pomo_detect_git_context)
  local directory="$PWD"
  local hostname=$(hostname -s 2>/dev/null || echo "unknown")
  local timezone=$(date +%Z 2>/dev/null || echo "UTC")
  local local_time=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")
  local day_of_week=$(date +%A | tr '[:upper:]' '[:lower:]')
  local hour=$(date +%H)

  # Determine if working hours (9am-6pm by default)
  local is_working_hours="false"
  if [[ $hour -ge 9 && $hour -lt 18 ]]; then
    is_working_hours="true"
  fi

  # Merge git context with environment context
  echo "$git_context" | jq \
    --arg dir "$directory" \
    --arg host "$hostname" \
    --arg tz "$timezone" \
    --arg local_time "$local_time" \
    --arg dow "$day_of_week" \
    --arg working_hours "$is_working_hours" \
    '. + {
      directory: $dir,
      hostname: $host,
      timezone: $tz,
      local_time: $local_time,
      day_of_week: $dow,
      is_working_hours: ($working_hours == "true")
    }'
}

# Emit an event to the database
_pomo_emit_event() {
  local event_type="$1"
  local payload="$2"
  local session_id="${3:-}"
  local version="${4:-1}"

  # Skip if duckdb not available
  if ! command -v duckdb &>/dev/null; then
    return 0
  fi

  # Ensure DB is initialized
  if [[ ! -f "$POMODORO_DB_PATH" ]]; then
    _pomo_init_db
  fi

  local event_id=$(_pomo_generate_uuid)
  local client_id=$(_pomo_get_client_id)
  local sequence=$(_pomo_next_sequence "$client_id")
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local context=$(_pomo_detect_context)

  # Escape single quotes in JSON for SQL
  payload=$(echo "$payload" | sed "s/'/''/g")
  context=$(echo "$context" | sed "s/'/''/g")

  duckdb "$POMODORO_DB_PATH" <<EOF
INSERT INTO events (id, type, version, timestamp, client_id, sequence, session_id, payload, context)
VALUES (
  '$event_id',
  '$event_type',
  $version,
  '$timestamp',
  '$client_id',
  $sequence,
  $(if [[ -n "$session_id" ]]; then echo "'$session_id'"; else echo "NULL"; fi),
  '$payload',
  '$context'
);
EOF
}

# Event emission helpers for specific event types

_pomo_emit_session_started() {
  local session_id="$1"
  local session_type="$2"
  local planned_duration="$3"
  local tags="${4:-[]}"

  local payload=$(jq -n \
    --arg sid "$session_id" \
    --arg type "$session_type" \
    --argjson duration "$planned_duration" \
    --argjson tags "$tags" \
    '{
      session_id: $sid,
      session_type: $type,
      planned_duration_secs: $duration,
      tags: $tags
    }')

  _pomo_emit_event "session.started" "$payload" "$session_id"
}

_pomo_emit_session_ended() {
  local session_id="$1"
  local end_reason="$2"
  local actual_duration="$3"
  local notes="${4:-}"

  local payload=$(jq -n \
    --arg sid "$session_id" \
    --arg reason "$end_reason" \
    --argjson duration "$actual_duration" \
    --arg notes "$notes" \
    '{
      session_id: $sid,
      end_reason: $reason,
      actual_duration_secs: $duration,
      notes: (if $notes != "" then $notes else null end)
    }')

  _pomo_emit_event "session.ended" "$payload" "$session_id"
}

_pomo_emit_session_paused() {
  local session_id="$1"
  local reason="${2:-}"

  local payload=$(jq -n \
    --arg sid "$session_id" \
    --arg reason "$reason" \
    '{
      session_id: $sid,
      reason: (if $reason != "" then $reason else null end)
    }')

  _pomo_emit_event "session.paused" "$payload" "$session_id"
}

_pomo_emit_session_resumed() {
  local session_id="$1"
  local pause_duration="$2"

  local payload=$(jq -n \
    --arg sid "$session_id" \
    --argjson pause_dur "$pause_duration" \
    '{
      session_id: $sid,
      pause_duration_secs: $pause_dur
    }')

  _pomo_emit_event "session.resumed" "$payload" "$session_id"
}

# Query helpers

# Generic date range query helper
_pomo_query_range() {
  local start_date="$1"
  local end_date="${2:-CURRENT_TIMESTAMP}"
  local label="${3:-Sessions}"

  if ! command -v duckdb &>/dev/null || [[ ! -f "$POMODORO_DB_PATH" ]]; then
    echo "DuckDB not available or database not initialized"
    return 1
  fi

  duckdb "$POMODORO_DB_PATH" -markdown <<EOF
WITH session_starts AS (
  SELECT
    json_extract_string(payload, '\$.session_id') as session_id,
    json_extract_string(payload, '\$.session_type') as session_type,
    timestamp as started_at
  FROM events
  WHERE type = 'session.started'
    AND timestamp >= $start_date
    AND timestamp < $end_date
),
session_ends AS (
  SELECT
    json_extract_string(payload, '\$.session_id') as session_id,
    json_extract_string(payload, '\$.end_reason') as end_reason,
    CAST(json_extract(payload, '\$.actual_duration_secs') AS INTEGER) as duration_secs
  FROM events
  WHERE type = 'session.ended'
    AND timestamp >= $start_date
    AND timestamp < $end_date
)
SELECT
  s.session_type as "Type",
  COUNT(*) as "Sessions",
  ROUND(COALESCE(SUM(e.duration_secs) / 60.0, 0), 0)::INTEGER as "Minutes",
  ROUND(COALESCE(SUM(e.duration_secs) / 3600.0, 0), 1) as "Hours"
FROM session_starts s
LEFT JOIN session_ends e ON s.session_id = e.session_id
GROUP BY s.session_type
ORDER BY s.session_type;
EOF
}

# Get today's sessions summary
_pomo_query_today() {
  echo "Today's sessions:"
  _pomo_query_range "CURRENT_DATE" "CURRENT_DATE + INTERVAL 1 DAY"
}

# Get yesterday's sessions summary
_pomo_query_yesterday() {
  echo "Yesterday's sessions:"
  _pomo_query_range "CURRENT_DATE - INTERVAL 1 DAY" "CURRENT_DATE"
}

# Get week-to-date sessions summary
_pomo_query_wtd() {
  echo "Week to date (since Monday):"
  _pomo_query_range "date_trunc('week', CURRENT_DATE)" "CURRENT_DATE + INTERVAL 1 DAY"
}

# Get month-to-date sessions summary
_pomo_query_mtd() {
  echo "Month to date:"
  _pomo_query_range "date_trunc('month', CURRENT_DATE)" "CURRENT_DATE + INTERVAL 1 DAY"
}

# Get recent sessions
_pomo_query_recent() {
  local limit="${1:-10}"

  if ! command -v duckdb &>/dev/null || [[ ! -f "$POMODORO_DB_PATH" ]]; then
    return 1
  fi

  duckdb "$POMODORO_DB_PATH" -markdown <<EOF
WITH session_data AS (
  SELECT
    json_extract_string(payload, '$.session_id') as session_id,
    json_extract_string(payload, '$.session_type') as session_type,
    timestamp as started_at,
    json_extract_string(context, '$.git_branch') as git_branch
  FROM events
  WHERE type = 'session.started'
  ORDER BY timestamp DESC
  LIMIT $limit
)
SELECT
  strftime(started_at, '%Y-%m-%d %H:%M') as "Started",
  session_type as "Type",
  COALESCE(git_branch, '-') as "Branch"
FROM session_data;
EOF
}

# Run arbitrary SQL query
_pomo_query() {
  local sql="$1"

  if ! command -v duckdb &>/dev/null || [[ ! -f "$POMODORO_DB_PATH" ]]; then
    echo "DuckDB not available or database not initialized"
    return 1
  fi

  duckdb "$POMODORO_DB_PATH" -markdown <<< "$sql"
}

# Open DuckDB shell
_pomo_db_shell() {
  if ! command -v duckdb &>/dev/null; then
    echo "DuckDB not installed. Run: brew install duckdb"
    return 1
  fi

  if [[ ! -f "$POMODORO_DB_PATH" ]]; then
    _pomo_init_db
  fi

  echo "Opening pomo database. Try: SELECT * FROM events LIMIT 5;"
  duckdb "$POMODORO_DB_PATH"
}

# =============================================================================
# Forgotten Timer Detection & Fix
# =============================================================================

# Format relative time for display (e.g., "2h 10m", "3d", "Yesterday 9 AM")
_pomo_format_relative_time() {
  local timestamp="$1"  # ISO timestamp or Unix epoch
  local now=$(date +%s)

  # Convert ISO timestamp to epoch if needed
  local epoch
  if [[ "$timestamp" =~ ^[0-9]+$ ]]; then
    epoch="$timestamp"
  else
    # Try to parse ISO format
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" +%s 2>/dev/null || \
            date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" +%s 2>/dev/null || \
            echo "$now")
  fi

  local diff=$((now - epoch))
  local days=$((diff / 86400))
  local hours=$(((diff % 86400) / 3600))
  local mins=$(((diff % 3600) / 60))

  if [[ $days -gt 1 ]]; then
    echo "${days}d ago"
  elif [[ $days -eq 1 ]]; then
    local time_str=$(date -j -f "%s" "$epoch" "+%-I:%M %p" 2>/dev/null || echo "")
    echo "Yesterday $time_str"
  elif [[ $hours -gt 0 ]]; then
    echo "${hours}h ${mins}m ago"
  elif [[ $mins -gt 0 ]]; then
    echo "${mins}m ago"
  else
    echo "Just now"
  fi
}

# Count unfixed sessions (sessions with no corresponding session.ended event)
_pomo_count_unfixed() {
  if ! command -v duckdb &>/dev/null || [[ ! -f "$POMODORO_DB_PATH" ]]; then
    echo "0"
    return
  fi

  local count=$(duckdb "$POMODORO_DB_PATH" -csv <<'EOF' 2>/dev/null | tail -1
SELECT COUNT(*) as count
FROM events started
WHERE started.type = 'session.started'
AND json_extract_string(started.payload, '$.session_id') NOT IN (
  SELECT json_extract_string(payload, '$.session_id')
  FROM events
  WHERE type = 'session.ended'
)
EOF
)

  echo "${count:-0}"
}

# Query unfixed sessions with details
_pomo_query_unfixed() {
  if ! command -v duckdb &>/dev/null || [[ ! -f "$POMODORO_DB_PATH" ]]; then
    echo "DuckDB not available or database not initialized"
    return 1
  fi

  # Return JSON array of unfixed sessions
  duckdb "$POMODORO_DB_PATH" -json <<'EOF'
WITH unfixed AS (
  SELECT
    json_extract_string(payload, '$.session_id') as session_id,
    json_extract_string(payload, '$.session_type') as session_type,
    CAST(COALESCE(json_extract(payload, '$.planned_duration_secs'), 0) AS INTEGER) as target_secs,
    timestamp as started_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - timestamp))::INTEGER as elapsed_secs,
    EXTRACT(HOUR FROM timestamp)::INTEGER as started_hour,
    EXTRACT(DOW FROM timestamp)::INTEGER as started_dow,
    EXTRACT(DOW FROM CURRENT_TIMESTAMP)::INTEGER as current_dow,
    DATE(timestamp) as started_date,
    CURRENT_DATE as today_date
  FROM events
  WHERE type = 'session.started'
  AND json_extract_string(payload, '$.session_id') NOT IN (
    SELECT json_extract_string(payload, '$.session_id')
    FROM events
    WHERE type = 'session.ended'
  )
)
SELECT
  session_id,
  session_type,
  target_secs,
  started_at,
  elapsed_secs,
  started_hour,
  started_dow,
  current_dow,
  started_date,
  today_date,
  -- Calculate hint
  CASE
    WHEN started_date < today_date - 1 THEN 'old (multiple days)'
    WHEN started_date = today_date - 1 THEN 'yesterday'
    WHEN started_dow IN (0, 6) AND current_dow NOT IN (0, 6) THEN 'spans weekend'
    WHEN target_secs > 0 AND elapsed_secs > target_secs THEN 'overdue'
    WHEN elapsed_secs > 14400 THEN 'over 4 hours'  -- 4 hours
    ELSE 'recent'
  END as hint
FROM unfixed
ORDER BY started_at DESC
EOF
}

# Display unfixed sessions in a human-readable format
_pomo_show_unfixed() {
  local count=$(_pomo_count_unfixed)

  if [[ "$count" == "0" ]]; then
    echo "No unfixed sessions"
    return 0
  fi

  echo "Unfixed sessions:"
  echo ""

  local json=$(_pomo_query_unfixed)

  if ! command -v jq &>/dev/null; then
    echo "(Install jq for detailed display)"
    echo "Found $count unfixed session(s)"
    return 0
  fi

  # Header
  printf "  %-3s %-20s %-12s %-10s %-12s %s\n" "#" "Started" "Type" "Target" "Elapsed" "Hint"
  printf "  %-3s %-20s %-12s %-10s %-12s %s\n" "---" "--------------------" "------------" "----------" "------------" "----"

  # Parse JSON and display rows
  local idx=1
  echo "$json" | jq -r '.[] | [.session_id, .session_type, .target_secs, .started_at, .elapsed_secs, .hint] | @tsv' | while IFS=$'\t' read -r sid stype target started elapsed hint; do
    # Format started time
    local started_display=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" "+%b %d %I:%M %p" 2>/dev/null || echo "$started")

    # Format target
    local target_display="--"
    if [[ "$target" != "0" && "$target" != "null" ]]; then
      target_display=$(_pomo_format_time "$target")
    fi

    # Format elapsed
    local hours=$((elapsed / 3600))
    local mins=$(((elapsed % 3600) / 60))
    local elapsed_display
    if [[ $hours -gt 24 ]]; then
      local days=$((hours / 24))
      elapsed_display="${days}d"
    elif [[ $hours -gt 0 ]]; then
      elapsed_display="${hours}h ${mins}m"
    else
      elapsed_display="${mins}m"
    fi

    printf "  %-3s %-20s %-12s %-10s %-12s %s\n" "$idx" "$started_display" "$stype" "$target_display" "$elapsed_display" "$hint"
    ((idx++))
  done

  echo ""
  echo "Commands:"
  echo "  pomo fix <#> complete     Log with target duration (if target exists)"
  echo "  pomo fix <#> <duration>   Log with specified duration (e.g., 18m, 1h)"
  echo "  pomo fix <#> discard      Discard without logging to stats"
  echo "  pomo fix all discard      Discard all unfixed sessions"
}

# Get session details by index (1-based)
_pomo_get_unfixed_by_index() {
  local index="$1"
  local json=$(_pomo_query_unfixed)

  if ! command -v jq &>/dev/null; then
    echo ""
    return 1
  fi

  # jq uses 0-based indexing
  echo "$json" | jq -r ".[$((index - 1))]"
}

# Fix a specific session
_pomo_fix_session() {
  local session_id="$1"
  local action="$2"  # complete, discard, or a duration
  local target_secs="${3:-0}"  # Original planned duration

  if [[ -z "$session_id" || -z "$action" ]]; then
    echo "Usage: _pomo_fix_session <session_id> <complete|discard|duration> [target_secs]"
    return 1
  fi

  local end_reason
  local actual_duration=0
  local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  case "$action" in
    complete)
      if [[ "$target_secs" -eq 0 ]]; then
        echo "Error: Cannot use 'complete' for session without target"
        echo "Use a specific duration instead: pomo fix <#> 25m"
        return 1
      fi
      end_reason="forgotten-complete"
      actual_duration="$target_secs"
      ;;
    discard)
      end_reason="forgotten-discarded"
      actual_duration=0
      ;;
    *)
      # Assume it's a duration
      actual_duration=$(_pomo_parse_duration "$action")
      if [[ "$actual_duration" -eq 0 ]]; then
        echo "Error: Invalid action or duration: $action"
        return 1
      fi
      end_reason="forgotten-partial"
      ;;
  esac

  # Get the original start timestamp for calculating forgotten_for
  local start_info=$(duckdb "$POMODORO_DB_PATH" -json <<EOF
SELECT timestamp, EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - timestamp))::INTEGER as forgotten_for
FROM events
WHERE type = 'session.started'
AND json_extract_string(payload, '\$.session_id') = '$session_id'
LIMIT 1
EOF
)

  local forgotten_for=$(echo "$start_info" | jq -r '.[0].forgotten_for // 0')

  # Emit session.ended event with fix metadata
  local payload=$(jq -n \
    --arg sid "$session_id" \
    --arg reason "$end_reason" \
    --argjson actual "$actual_duration" \
    --argjson planned "$target_secs" \
    --argjson forgotten "$forgotten_for" \
    --arg fixed_at "$now" \
    '{
      session_id: $sid,
      end_reason: $reason,
      actual_duration_secs: $actual,
      planned_duration_secs: $planned,
      forgotten_for_secs: $forgotten,
      fixed_at: $fixed_at
    }')

  _pomo_emit_event "session.ended" "$payload" "$session_id"

  case "$end_reason" in
    forgotten-complete)
      echo "Logged session as complete ($(_pomo_format_time $actual_duration))"
      ;;
    forgotten-partial)
      echo "Logged session with duration $(_pomo_format_time $actual_duration)"
      ;;
    forgotten-discarded)
      echo "Session discarded (not counted in stats)"
      ;;
  esac
}

# Fix all unfixed sessions with the same action
_pomo_fix_all() {
  local action="$1"

  if [[ "$action" != "discard" ]]; then
    echo "Error: 'fix all' only supports 'discard'"
    echo "Usage: pomo fix all discard"
    return 1
  fi

  local json=$(_pomo_query_unfixed)
  local count=$(echo "$json" | jq -r 'length')

  if [[ "$count" -eq 0 ]]; then
    echo "No unfixed sessions to fix"
    return 0
  fi

  echo "Discarding $count unfixed session(s)..."

  echo "$json" | jq -r '.[].session_id' | while read -r sid; do
    _pomo_fix_session "$sid" "discard" "0"
  done

  echo "Done."
}

# =============================================================================
# Migration
# =============================================================================

# Migrate existing history to events
_pomo_migrate_history_to_events() {
  local history_file="$(_pomo_history_file)"

  if [[ ! -f "$history_file" ]]; then
    echo "No history file to migrate"
    return 0
  fi

  if ! command -v duckdb &>/dev/null; then
    echo "DuckDB not installed"
    return 1
  fi

  _pomo_init_db

  local count=0
  local client_id=$(_pomo_get_client_id)

  while IFS='|' read -r timestamp type duration; do
    local session_id=$(_pomo_generate_uuid)

    # Convert timestamp to ISO format
    local iso_timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "${timestamp}Z")

    # Emit start event
    local start_payload=$(jq -n \
      --arg sid "$session_id" \
      --arg type "$type" \
      --argjson duration "$duration" \
      '{session_id: $sid, session_type: $type, planned_duration_secs: $duration, tags: [], migrated: true}')

    start_payload=$(echo "$start_payload" | sed "s/'/''/g")

    duckdb "$POMODORO_DB_PATH" <<EOF
INSERT INTO events (id, type, version, timestamp, client_id, sequence, session_id, payload, context)
VALUES (
  '$(_pomo_generate_uuid)',
  'session.started',
  1,
  '$iso_timestamp',
  '$client_id',
  $count,
  '$session_id',
  '$start_payload',
  '{"migrated": true}'
);
EOF

    # Emit end event
    local end_payload=$(jq -n \
      --arg sid "$session_id" \
      --argjson duration "$duration" \
      '{session_id: $sid, end_reason: "completed", actual_duration_secs: $duration, migrated: true}')

    end_payload=$(echo "$end_payload" | sed "s/'/''/g")

    # Calculate end timestamp
    local end_timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$iso_timestamp" -v+${duration}S +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$iso_timestamp")

    duckdb "$POMODORO_DB_PATH" <<EOF
INSERT INTO events (id, type, version, timestamp, client_id, sequence, session_id, payload, context)
VALUES (
  '$(_pomo_generate_uuid)',
  'session.ended',
  1,
  '$end_timestamp',
  '$client_id',
  $((count + 1)),
  '$session_id',
  '$end_payload',
  '{"migrated": true}'
);
EOF

    ((count += 2))
  done < "$history_file"

  echo "Migrated $((count / 2)) sessions from history file"

  # Rename old history file
  mv "$history_file" "${history_file}.migrated"
  echo "Renamed history file to ${history_file}.migrated"
}
