#!/bin/bash
# Shared roster for the Claude Code session widget.
#
# The roster comes from Claude Code's own session registry
# (~/.claude/sessions/<pid>.json), which covers every entrypoint -- terminal
# and VSCode-hosted -- across all projects, with no per-project setup.
#
# Live state is overlaid from the hook-written files in
# $XDG_RUNTIME_DIR/claude-sessions/, because the registry only reports a
# "status" field for terminal sessions; VSCode-hosted ones carry none.
# Hook state therefore wins, and the registry is the fallback.
#
# Sourced by claude-sessions.sh (renders the bar) and
# claude-sessions-focus.sh (focuses a session's window).

CLAUDE_SESSIONS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
CLAUDE_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
CLAUDE_STATE_DIR="$CLAUDE_RUNTIME_DIR/claude-sessions"
CLAUDE_SIGNAL=9

# Emits a JSON array, sorted by urgency then name:
#   [{pid, sessionId, name, cwd, entry, state, last}]
# where `state` is waiting|busy|idle|unknown and `last` is an epoch-seconds
# timestamp for when that state was last observed.
claude_sessions_json() {
    local live_files=() live_sids=() f sf pid sid states

    for f in "$CLAUDE_SESSIONS_DIR"/*.json; do
        [ -e "$f" ] || continue
        pid=$(basename "$f" .json)
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        # Keeps a session killed mid-turn from showing a stale "busy".
        kill -0 "$pid" 2>/dev/null || continue
        live_files+=("$f")
        sid=$(sed -n 's/.*"sessionId":"\([^"]*\)".*/\1/p' "$f")
        [ -n "$sid" ] && live_sids+=("$sid")
    done

    # Drop state files for sessions that are gone; SessionEnd does not fire on
    # a SIGKILL. The file name is the session id, so no parsing needed.
    for sf in "$CLAUDE_STATE_DIR"/*.json; do
        [ -e "$sf" ] || continue
        sid=$(basename "$sf" .json)
        [[ " ${live_sids[*]} " == *" $sid "* ]] || rm -f "$sf"
    done

    if [ ${#live_files[@]} -eq 0 ]; then
        echo '[]'
        return
    fi

    states='{}'
    if compgen -G "$CLAUDE_STATE_DIR/*.json" > /dev/null; then
        states=$(jq -s 'map(select(.session_id) | {(.session_id): .}) | add // {}' \
            "$CLAUDE_STATE_DIR"/*.json 2>/dev/null)
    fi
    [ -n "$states" ] || states='{}'

    jq -s -c --argjson states "$states" '
def rank: {"waiting": 0, "busy": 1, "idle": 2, "unknown": 3}[.] // 3;
# Registry timestamps are epoch ms, hook timestamps epoch seconds.
def secs: if . == null then null elif . > 1e12 then (. / 1000 | floor) else floor end;

[ .[]
  | . as $r
  | ($states[$r.sessionId // ""] // null) as $h
  | {
      pid: $r.pid,
      sessionId: ($r.sessionId // ""),
      name: ($r.name // "session"),
      cwd: ($r.cwd // "?"),
      entry: ({"cli": "term", "claude-vscode": "vscode"}[$r.entrypoint // ""]
              // ($r.entrypoint // "?")),
      # Hook state first; registry status as fallback; otherwise unknown --
      # a VSCode session that has not hit a hook yet since the widget went in.
      state: ($h.state
              // (if ($r.status // "") == "" then "unknown"
                  elif $r.status == "busy" then "busy"
                  else "idle" end)),
      # Tie the timestamp to whichever source supplied the state, so a waiting
      # session reports how long it has been blocked rather than a heartbeat.
      last: (if $h.state then ($h.ts | secs)
             else (($r.statusUpdatedAt // $r.updatedAt // $r.startedAt) | secs)
             end)
    }
]
| sort_by([(.state | rank), .name])
' "${live_files[@]}"
}
