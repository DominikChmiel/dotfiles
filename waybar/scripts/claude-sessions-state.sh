#!/bin/bash
# Claude Code session-state hook for Waybar.
#
# Wired up from ~/.claude/settings.json. The hook payload arrives on stdin and
# the state to record is passed as $1 -- the hook matcher already tells the
# events apart, so this never has to parse a notification type itself.
#
# Usage: claude-sessions-state.sh busy|idle|waiting|end

STATE="${1:-idle}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
STATE_DIR="$RUNTIME_DIR/claude-sessions"
SIGNAL=9

payload=$(cat)
session_id=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)

# Nothing to record without a session id, but never fail the hook.
[ -n "$session_id" ] || exit 0

mkdir -p "$STATE_DIR" 2>/dev/null

if [ "$STATE" = "end" ]; then
    rm -f "$STATE_DIR/$session_id.json"
else
    cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
    tmp="$STATE_DIR/.$session_id.$$.tmp"
    if jq -n --arg id "$session_id" --arg state "$STATE" --arg cwd "$cwd" \
        '{session_id: $id, state: $state, cwd: $cwd, ts: (now | floor)}' \
        > "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$STATE_DIR/$session_id.json"
    else
        rm -f "$tmp"
    fi
fi

pkill -RTMIN+$SIGNAL waybar 2>/dev/null

exit 0
