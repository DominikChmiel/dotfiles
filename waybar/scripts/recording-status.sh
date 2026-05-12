#!/bin/bash
# Recording status script for Waybar

# Check if wf-recorder is running
if pgrep -x wf-recorder > /dev/null; then
    # Recording active - show red circle icon
    echo '{"text":"", "class":"recording"}'
else
    # Not recording - don't show anything
    echo '{"text":"", "class":"idle"}'
fi
