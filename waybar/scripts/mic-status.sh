#!/bin/bash
# Microphone status script for Waybar

MIC="alsa_input.usb-Focusrite_Scarlett_2i4_USB-00.HiFi__Mic1__source"

# Check if mic is muted
MUTED=$(pactl get-source-mute "$MIC" | awk '{print $2}')

if [ "$MUTED" = "yes" ]; then
    echo " "
else
    echo " "
fi
