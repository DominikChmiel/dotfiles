#!/bin/bash
# Remember which workspace each Chromium window lives on, and put them back
# there the next time Chromium starts.
#
# Wayland has no session management: Chromium restores its own windows and tabs
# ("Continue where you left off"), but the compositor has no idea where those
# windows used to be, so all of them pile onto whatever workspace is focused
# when Chromium launches.
#
# This daemon keeps a "window title -> workspace" snapshot while Chromium runs
# and replays it on the next start. Titles are the only handle we have -
# Chromium hands out no stable window ids across restarts - but since the
# restored window shows the same active tab, the title matches.
#
# Started from the sway config via exec_always. The save/restore/status
# subcommands are for debugging by hand.

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sway"
STATE_FILE="$STATE_DIR/chromium-workspaces.json"
LOCK_FILE="$STATE_DIR/chrome-workspaces.lock"
PID_FILE="$STATE_DIR/chrome-workspaces.pid"

# How long after Chromium's first window we keep placing windows. Session
# restore opens them in a burst, but a cold profile can take a while.
RESTORE_GRACE=${RESTORE_GRACE:-30}

# Quiet period before a snapshot is written. Must be longer than the time
# Chromium needs to close all its windows on quit, otherwise the last few close
# events would overwrite a good snapshot with a nearly empty one.
SAVE_DEBOUNCE=${SAVE_DEBOUNCE:-8}

# Upper bound on that quiet period. A window whose title keeps changing (a music
# player, a live dashboard) would otherwise reset the debounce forever and we
# would never write a snapshot at all.
SAVE_MAX_DELAY=${SAVE_MAX_DELAY:-25}

# ================= jq helpers =================

JQ_DEF='
def ischrome: ((.app_id // .window_properties.class // "") | ascii_downcase
  | startswith("chrom") or startswith("google-chrome"));
def iswin: (.type == "con" or .type == "floating_con") and ischrome;
def clean: (. // "") | gsub("[\t\n]"; " ");
'

# [{title, workspace}, ...] for every Chromium window, scratchpad excluded
JQ_SNAPSHOT="$JQ_DEF"'
[ .. | objects
  | select(.type == "workspace" and ((.name | startswith("__")) | not))
  | .name as $ws
  | [ .. | objects | select(iswin) | {title: (.name | clean), workspace: $ws} ]
] | flatten'

# id<TAB>title for every Chromium window currently mapped
JQ_LIST="$JQ_DEF"'
[ .. | objects | select(iswin) ] | .[] | [.id, (.name | clean)] | @tsv'

# workspace name holding container $id
JQ_WS_OF="$JQ_DEF"'
.. | objects | select(.type == "workspace") | .name as $ws
| [ .. | objects | select(.id? == $id) ] | select(length > 0) | $ws'

log() { printf '[chrome-workspaces] %s\n' "$*" >&2; }

tree() { swaymsg -t get_tree 2>/dev/null; }

snapshot() { tree | jq -c "$JQ_SNAPSHOT"; }

chrome_count() { tree | jq "$JQ_SNAPSHOT | length" 2>/dev/null || echo 0; }

ws_of_con() { tree | jq -r --argjson id "$1" "$JQ_WS_OF" 2>/dev/null | head -1; }

# ================= Title matching =================

# Chromium window titles are "<active tab> - Chromium", often with an unread
# counter in front ("(3) Inbox - ..."). Strip both so a title still matches when
# the counter moved on between sessions.
normalize() {
    local t=$1
    [[ $t =~ ^\([0-9]+\)[[:space:]]+(.*)$ ]] && t=${BASH_REMATCH[1]}
    t=${t% - Chromium}
    t=${t% - Google Chrome}
    t=${t% — Chromium}
    t=$(printf '%s' "$t" | tr -s '[:space:]' ' ')
    t=${t# }
    t=${t% }
    printf '%s' "${t,,}"
}

declare -A WANT      # normalized title -> workspace
declare -A WANTN     # normalized title -> how many windows still expected
declare -A PLACED    # con id -> 1 once we moved it

load_wanted() {
    WANT=(); WANTN=()
    [[ -s $STATE_FILE ]] || return 1
    local title ws key
    while IFS=$'\t' read -r title ws; do
        [[ -n $ws ]] || continue
        key=$(normalize "$title")
        [[ -n $key ]] || continue
        if [[ -z ${WANT[$key]:-} ]]; then
            WANT[$key]=$ws
            WANTN[$key]=1
        else
            WANTN[$key]=$(( WANTN[$key] + 1 ))
        fi
    done < <(jq -r '.[] | [.title, .workspace] | @tsv' "$STATE_FILE" 2>/dev/null)
    (( ${#WANT[@]} > 0 ))
}

# Sets MATCH_KEY/MATCH_WS on success.
lookup() {
    local key=$1 k
    MATCH_KEY=; MATCH_WS=
    if [[ -n ${WANT[$key]:-} ]]; then
        MATCH_KEY=$key
        MATCH_WS=${WANT[$key]}
        return 0
    fi
    # Fall back to a prefix match: titles drift ("... and 3 more tabs", a page
    # that finished loading under a longer name, ...).
    for k in "${!WANT[@]}"; do
        (( ${#k} >= 8 )) || continue
        if [[ $key == "$k"* || $k == "$key"* ]]; then
            MATCH_KEY=$k
            MATCH_WS=${WANT[$k]}
            return 0
        fi
    done
    return 1
}

consume() {
    local k=$1
    if (( ${WANTN[$k]:-0} > 1 )); then
        WANTN[$k]=$(( WANTN[$k] - 1 ))
    else
        unset 'WANT[$k]'
        unset 'WANTN[$k]'
    fi
}

try_place() {
    local id=$1 title=$2 key
    [[ -n $id && $id != 0 ]] || return
    [[ -z ${PLACED[$id]:-} ]] || return
    key=$(normalize "$title")
    # An empty or bare "chromium" title means the window has not settled yet;
    # a later title event will bring the real one.
    [[ -n $key && $key != chromium && $key != "new tab" ]] || return
    lookup "$key" || return
    PLACED[$id]=1
    consume "$MATCH_KEY"
    if [[ $(ws_of_con "$id") != "$MATCH_WS" ]]; then
        swaymsg "[con_id=$id] move container to workspace \"$MATCH_WS\"" >/dev/null
        log "placed '$title' on $MATCH_WS"
    fi
}

# Walk the windows that are already mapped and place whatever we recognise.
place_existing() {
    local wid wtitle
    while IFS=$'\t' read -r wid wtitle; do
        try_place "$wid" "$wtitle"
    done < <(tree | jq -r "$JQ_LIST")
}

# ================= Saving =================

do_save() {
    local snap n
    snap=$(snapshot) || return
    n=$(printf '%s' "$snap" | jq 'length' 2>/dev/null) || return
    if (( n == 0 )); then
        log "no Chromium windows, keeping previous snapshot"
        return
    fi
    mkdir -p "$STATE_DIR"
    printf '%s\n' "$snap" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
    log "saved $n window placements"
}

# ================= Daemon =================

# One daemon at a time. sway's exec_always starts a fresh one on every reload,
# so the new instance takes over from the old. The handover goes through a lock
# file and our own pid file rather than pgrep: a command line matching
# "chrome-workspaces.sh daemon" is not proof it *is* the daemon (any shell or
# editor mentioning the script matches too, and killing those is no fun).
acquire_lock() {
    exec 9>"$LOCK_FILE" || return 1
    if ! flock -n 9; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ $pid =~ ^[0-9]+$ ]] &&
           [[ $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) == *chrome-workspaces.sh* ]]; then
            log "replacing running daemon (pid $pid)"
            kill "$pid" 2>/dev/null
        fi
        flock -w 10 9 || { log "another daemon is still holding $LOCK_FILE"; return 1; }
    fi
    printf '%s\n' "$$" > "$PID_FILE"
}

now() { printf '%s' "${EPOCHSECONDS:-$(date +%s)}"; }

SUB_PID=0

cleanup() {
    trap - EXIT
    (( SUB_PID > 0 )) && kill "$SUB_PID" 2>/dev/null
    pkill -P $$ 2>/dev/null
    rm -f "$PID_FILE"
}

RESTORE_UNTIL=0
SAVE_AT=0
SAVE_DEADLINE=0
LAST_CLOSE=0
HAVE_CHROME=0

handle_event() {
    local ev change id app title
    # Cheap prefilter: most window events in a session are not Chromium's, and
    # this daemon should not fork a jq for every title change in every app.
    [[ $1 == *hrom* ]] || return
    ev=$(printf '%s' "$1" | jq -r '
        [ (.change // ""),
          (.container.id // 0),
          ((.container.app_id // .container.window_properties.class // "") | ascii_downcase),
          ((.container.name // "") | gsub("[\t\n]"; " ")) ] | @tsv' 2>/dev/null) || return
    IFS=$'\t' read -r change id app title <<<"$ev"
    [[ $app == chrom* || $app == google-chrome* ]] || return

    case $change in
        new)
            if (( RESTORE_UNTIL == 0 && HAVE_CHROME == 0 )); then
                if load_wanted; then
                    PLACED=()
                    RESTORE_UNTIL=$(( $(now) + RESTORE_GRACE ))
                    log "Chromium started, restoring ${#WANT[@]} window placements"
                    # Catch windows that were mapped before we saw this event -
                    # at login Chromium can outrun the daemon's first subscribe.
                    place_existing
                else
                    log "Chromium started, no snapshot to restore"
                fi
            fi
            HAVE_CHROME=1
            ;;
        close)
            LAST_CLOSE=$(now)
            (( $(chrome_count) == 0 )) && HAVE_CHROME=0
            ;;
    esac

    if (( RESTORE_UNTIL > 0 )); then
        try_place "$id" "$title"
    else
        # Any move/open/close/rename is worth recording, after things settle.
        SAVE_AT=$(( $(now) + SAVE_DEBOUNCE ))
        (( SAVE_DEADLINE == 0 )) && SAVE_DEADLINE=$(( $(now) + SAVE_MAX_DELAY ))
    fi
}

tick() {
    local t
    t=$(now)
    if (( RESTORE_UNTIL > 0 && t >= RESTORE_UNTIL )); then
        RESTORE_UNTIL=0
        WANT=(); WANTN=(); PLACED=()
        SAVE_AT=$(( t + 2 ))
        SAVE_DEADLINE=$(( t + SAVE_MAX_DELAY ))
        log "restore window over, tracking placements again"
    fi
    if (( SAVE_AT > 0 )); then
        local due=0
        (( t >= SAVE_AT )) && due=1
        # Events still streaming in past the cap: save anyway, unless a window
        # just closed - that may be Chromium shutting down, and half a snapshot
        # is worse than a slightly stale one.
        (( SAVE_DEADLINE > 0 && t >= SAVE_DEADLINE && t - LAST_CLOSE >= SAVE_DEBOUNCE )) && due=1
        if (( due )); then
            SAVE_AT=0
            SAVE_DEADLINE=0
            do_save
        fi
    fi
}

daemon() {
    mkdir -p "$STATE_DIR"
    acquire_lock || exit 1
    HAVE_CHROME=$([[ $(chrome_count) -gt 0 ]] && echo 1 || echo 0)

    exec 3< <(swaymsg -t subscribe -m '["window"]')
    SUB_PID=$!
    trap cleanup EXIT
    # A bare trap would run the handler and then resume the loop; exit explicitly
    # so a new instance taking over can actually replace this one.
    trap 'exit 0' INT TERM

    local line rc
    while :; do
        IFS= read -r -t 2 -u 3 line
        rc=$?
        if (( rc == 0 )); then
            handle_event "$line"
        elif (( rc <= 128 )); then
            log "sway event stream closed, exiting"
            break
        fi
        tick
    done
}

# ================= Entry point =================

command -v jq >/dev/null || { log "jq is required"; exit 1; }

# Sourced (by a test) rather than run: stop here, functions are all the caller wants.
[[ ${BASH_SOURCE[0]} == "$0" ]] || return 0

main() {
    case ${1:-daemon} in
        daemon)
            daemon
            ;;
        save)
            do_save
            ;;
        restore)
            load_wanted || { log "no snapshot at $STATE_FILE"; exit 1; }
            place_existing
            ;;
        status)
            echo "state file: $STATE_FILE"
            if [[ -s $STATE_FILE ]]; then
                jq -r '.[] | "  \(.workspace)\t\(.title)"' "$STATE_FILE"
            else
                echo "  (empty)"
            fi
            pid=$(cat "$PID_FILE" 2>/dev/null)
            if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
                echo "daemon: running (pid $pid)"
            else
                echo "daemon: not running"
            fi
            ;;
        *)
            echo "usage: ${0##*/} [daemon|save|restore|status]" >&2
            exit 1
            ;;
    esac
}

main "$@"
