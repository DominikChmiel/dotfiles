#!/bin/bash
# Toggle screen recording with wf-recorder

if pgrep -x wf-recorder > /dev/null; then
    # Recording is active, stop it
    pkill -SIGINT wf-recorder
    notify-send "Screen Recording" "Recording stopped" -t 2000
else
    # Start recording with area selection
    FILENAME=~/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4
    wf-recorder -g "$(slurp)" -f "$FILENAME" &
    notify-send "Screen Recording" "Recording started" -t 2000
fi
