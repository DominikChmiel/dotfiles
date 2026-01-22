#!/bin/bash
#
# DEPRECATED: This script is kept for backwards compatibility.
# Please use the new unified setup script instead:
#
#   ./setup.sh x11
#
# The new setup.sh script provides:
#   - Better error handling
#   - Package checking and installation
#   - Easy switching between X11 and Wayland
#   - Status checking
#
# Redirecting to unified setup script...

echo "=========================================="
echo "NOTICE: setup_init.sh is deprecated"
echo "=========================================="
echo ""
echo "This script has been replaced by the unified setup.sh"
echo "Running: ./setup.sh x11"
echo ""
sleep 2

# Run the unified setup script
exec "$(dirname "$0")/setup.sh" x11
