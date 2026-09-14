#!/bin/bash
# Focus the window hosting a Claude Code session.
#
# Terminal sessions: claude -> shell -> terminal emulator, and the terminal's
# PID is a sway container PID, so walking the process ancestry lands exactly on
# the window.
#
# VSCode: every window belongs to one shared Electron main process (all of them
# report the same PID to sway), so the ancestry walk only narrows it down to
# "some VSCode window". The title carries the workspace folder name, which is
# the session's cwd basename, and that is what picks the right one.
#
# Usage:
#   claude-sessions-focus.sh           # rofi picker over all sessions
#   claude-sessions-focus.sh --urgent  # jump straight to the session that
#                                      # most wants attention

# shellcheck source=./claude-sessions-lib.sh
source "$(dirname "$(readlink -f "$0")")/claude-sessions-lib.sh"

notify() {
    command -v notify-send > /dev/null && notify-send -a "Claude Code" "$1" "$2"
}

ppid_of() {
    ps -o ppid= -p "$1" 2>/dev/null | tr -d ' '
}

# focus_session <pid> <cwd>
focus_session() {
    local pid=$1 cwd=$2 base tree p cons count id
    base=$(basename "$cwd")

    tree=$(swaymsg -t get_tree 2>/dev/null) || return 1

    p=$pid
    while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
        cons=$(printf '%s' "$tree" | jq -c --argjson p "$p" '
            [ recurse(.nodes[]?, .floating_nodes[]?)
              | select(.pid == $p and .name != null and (.nodes | length) == 0)
              | {id, name} ]' 2>/dev/null)
        count=$(printf '%s' "$cons" | jq 'length' 2>/dev/null)

        if [ -n "$count" ] && [ "$count" -gt 0 ]; then
            # One window means it is unambiguous. Several means VSCode, where
            # the workspace folder in the title is the only discriminator.
            # VSCode titles read "<file> - <folder> - Visual Studio Code", so
            # match a whole " - " segment: a substring match would resolve
            # ~/code/cassistant to the cassistant-ledger window.
            id=$(printf '%s' "$cons" | jq -r --arg base "$base" '
                ($base | ascii_downcase) as $b
                | ((map(select(.name | split(" - ")
                               | any(ascii_downcase == $b))) | .[0].id)
                   // (map(select(.name | ascii_downcase | contains($b)))
                       | .[0].id)
                   // .[0].id) // empty')
            [ -n "$id" ] || return 1
            swaymsg "[con_id=$id]" focus > /dev/null 2>&1
            return $?
        fi

        p=$(ppid_of "$p")
    done

    return 1
}

sessions=$(claude_sessions_json)

if [ "$sessions" = "[]" ]; then
    notify "No sessions" "No Claude Code sessions are running."
    exit 0
fi

target=''

if [ "$1" = "--urgent" ]; then
    # Longest-blocked session, else longest-running busy one, else whatever was
    # active most recently.
    target=$(printf '%s' "$sessions" | jq -c '
        (map(select(.state == "waiting")) | sort_by(.last // 0) | .[0])
        // (map(select(.state == "busy")) | sort_by(.last // 0) | .[0])
        // (sort_by(.last // 0) | last)')
elif command -v rofi > /dev/null; then
    theme=()
    [ -f "$HOME/.config/rofi/android_notification.rasi" ] \
        && theme=(-theme "$HOME/.config/rofi/android_notification.rasi")

    menu=$(printf '%s' "$sessions" | jq -r --arg home "$HOME" --argjson now "$(date +%s)" '
def short: if startswith($home) then "~" + .[($home | length):] else . end;
def glyph: {"waiting": "!", "busy": "▸", "idle": "○", "unknown": "·"}[.] // "·";
def ago: if . == null then "?" else ($now - .) as $d
    | if   $d < 60    then "\($d)s"
      elif $d < 3600  then "\(($d / 60) | floor)m"
      elif $d < 86400 then "\(($d / 3600) | floor)h"
      else                 "\(($d / 86400) | floor)d" end end;
.[] | "\(.state | glyph) \(.name)  ·  \(.last | ago)  ·  \(.cwd | short) [\(.entry)]"')

    idx=$(printf '%s\n' "$menu" | rofi -dmenu -i -p "Claude" -format i "${theme[@]}")
    [ -n "$idx" ] || exit 0
    target=$(printf '%s' "$sessions" | jq -c --argjson i "$idx" '.[$i]')
else
    # No rofi: do the useful thing rather than nothing.
    exec "$0" --urgent
fi

[ -n "$target" ] && [ "$target" != "null" ] || exit 0

pid=$(printf '%s' "$target" | jq -r '.pid')
cwd=$(printf '%s' "$target" | jq -r '.cwd')
name=$(printf '%s' "$target" | jq -r '.name')

if ! focus_session "$pid" "$cwd"; then
    notify "Cannot focus $name" \
        "No sway window found for this session (pid $pid). It may be running in a detached terminal or on another host."
fi
