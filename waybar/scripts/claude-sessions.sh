#!/bin/bash
# Claude Code session overview for Waybar.
#
# Bar:     󰚩 !1 3m ▸2 ○9   -- 1 blocked on you for 3 min, 2 working, 9 idle
# Tooltip: one line per session with state, name, last-active age, cwd, host.
#
# See claude-sessions-lib.sh for where the roster and the state come from.

# shellcheck source=./claude-sessions-lib.sh
source "$(dirname "$(readlink -f "$0")")/claude-sessions-lib.sh"

sessions=$(claude_sessions_json)

if [ "$sessions" = "[]" ]; then
    echo '{"text":"","tooltip":"No Claude Code sessions running","class":"none"}'
    exit 0
fi

printf '%s' "$sessions" | jq -c \
    --arg home "$HOME" \
    --arg icon "󰚩" \
    --argjson now "$(date +%s)" '
def esc: tostring | gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
def short: if startswith($home) then "~" + .[($home | length):] else . end;
def glyph: {"waiting": "!", "busy": "▸", "idle": "○", "unknown": "·"}[.] // "·";
def pad($n): . as $s | $s + (($n - ($s | length)) as $d
    | if $d > 0 then " " * $d else "" end);
def lpad($n): . as $s | (($n - ($s | length)) as $d
    | if $d > 0 then " " * $d else "" end) + $s;
def ago: if . == null then "?" else ($now - .) as $d
    | if   $d < 60    then "\($d)s"
      elif $d < 3600  then "\(($d / 60) | floor)m"
      elif $d < 86400 then "\(($d / 3600) | floor)h"
      else                 "\(($d / 86400) | floor)d" end end;

. as $all
| ($all | length) as $n
| ($all | map(select(.state == "waiting"))) as $waiting
| ($waiting | length) as $w
| ($all | map(select(.state == "busy")) | length) as $b
| ($n - $w - $b) as $i
| ($all | map(.name | length) | max) as $nw
| ($all | map(.last | ago | length) | max) as $aw
# How long the longest-blocked session has been waiting.
| ($waiting | map(.last | select(. != null)) | min) as $oldest
| {
    # Glyph and count are separated by a space, groups by two, so the
    # counts stay readable instead of running into their icons.
    text: ($icon + "  " + ([
        (if $w > 0 then "! \($w)" + (if $oldest then " \($oldest | ago)" else "" end)
                   else empty end),
        (if $b > 0 then "▸ \($b)" else empty end),
        (if $i > 0 then "○ \($i)" else empty end)
      ] | join("  "))),
    tooltip: (
      "<b>Claude Code</b> — \($n) session\(if $n == 1 then "" else "s" end)"
      + " · \($w) waiting, \($b) busy, \($i) idle\n<tt>"
      + ($all | map(
          "\(.state | glyph) \(.name | esc | pad($nw))  \(.last | ago | lpad($aw))"
          + "  \(.cwd | short | esc)  [\(.entry | esc)]"
        ) | join("\n"))
      + "</tt>\n<i>click: pick a session · right-click: jump to the urgent one</i>"),
    class: (if $w > 0 then "needs-input" elif $b > 0 then "busy" else "idle" end)
  }
'
