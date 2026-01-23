#!/bin/bash
# Network bandwidth with fixed-width formatting

# Use C locale for consistent number formatting
export LC_NUMERIC=C

# Get default network interface
INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

if [ -z "$INTERFACE" ]; then
    echo "  ---  ---"
    exit
fi

# Read current stats
RX1=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX1=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)

sleep 1

# Read stats again
RX2=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX2=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)

# Calculate rates
RX_RATE=$((RX2 - RX1))
TX_RATE=$((TX2 - TX1))

# Format with fixed width (right-aligned)
format_rate() {
    local rate=$1
    if [ $rate -ge 1048576 ]; then
        # MB/s
        local val=$(echo "scale=1; $rate/1048576" | bc | tr ',' '.')
        printf "%5.1fM" $val
    elif [ $rate -ge 1024 ]; then
        # KB/s
        local val=$(echo "scale=1; $rate/1024" | bc | tr ',' '.')
        printf "%5.1fK" $val
    else
        # B/s
        printf "%5dB" $rate
    fi
}

DOWN=$(format_rate $RX_RATE)
UP=$(format_rate $TX_RATE)

# Font Awesome icons: download () and upload ()
# Output JSON with fixed-width formatting
printf '{"text":"<span font_family=\\\"FontAwesome\\\"></span> <span font_family=\\\"Roboto Mono\\\">%-6s</span>   <span font_family=\\\"FontAwesome\\\"></span> <span font_family=\\\"Roboto Mono\\\">%-6s</span>"}\n' "$DOWN" "$UP"
