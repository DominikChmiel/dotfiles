#!/bin/bash
#
# DEPRECATED: This script is kept for backwards compatibility.
# Please use the new unified setup script instead:
#
#   ./setup.sh wayland
#
# The new setup.sh script provides:
#   - Better error handling
#   - Package checking and installation
#   - Easy switching between X11 and Wayland
#   - Status checking
#
# Redirecting to unified setup script...

echo "=========================================="
echo "NOTICE: setup_wayland.sh is deprecated"
echo "=========================================="
echo ""
echo "This script has been replaced by the unified setup.sh"
echo "Running: ./setup.sh wayland"
echo ""
sleep 2

# Run the unified setup script
exec "$(dirname "$0")/setup.sh" wayland

# Original script below (kept for reference)
exit 0

# ============================================
# ORIGINAL SCRIPT (NO LONGER EXECUTED)
# ============================================

set -e

echo "=========================================="
echo "Wayland/Sway Setup Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Error: Do not run this script as root"
    exit 1
fi

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if package is installed
check_package() {
    pacman -Q "$1" &> /dev/null
}

# Function to install packages
install_packages() {
    echo -e "${YELLOW}The following packages need to be installed:${NC}"
    echo "Core: sway swayidle swaylock swaybg waybar foot"
    echo "Tools: grim slurp wl-clipboard brightnessctl mako"
    echo "Optional: rofi blueman network-manager-applet"
    echo ""
    read -p "Install packages now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pacman -S --needed sway swayidle swaylock swaybg waybar foot \
            grim slurp wl-clipboard brightnessctl mako \
            rofi blueman network-manager-applet \
            xdg-desktop-portal-wlr
        echo -e "${GREEN}Packages installed successfully${NC}"
    else
        echo -e "${YELLOW}Skipping package installation${NC}"
        echo "You can install them later with:"
        echo "  sudo pacman -S sway swayidle swaylock swaybg waybar foot grim slurp wl-clipboard brightnessctl mako rofi"
    fi
    echo ""
}

# Check if on the correct branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "config-wayland" ]; then
    echo -e "${YELLOW}Warning: You are on branch '$CURRENT_BRANCH', not 'config-wayland'${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check and install packages
echo "Checking required packages..."
MISSING_PACKAGES=0
for pkg in sway waybar foot grim slurp wl-clipboard brightnessctl mako rofi; do
    if ! check_package "$pkg"; then
        MISSING_PACKAGES=1
        break
    fi
done

if [ $MISSING_PACKAGES -eq 1 ]; then
    install_packages
else
    echo -e "${GREEN}All required packages are already installed${NC}"
    echo ""
fi

# Create necessary directories
echo "Creating configuration directories..."
mkdir -p ~/.config/sway
mkdir -p ~/.config/waybar
mkdir -p ~/.config/waybar/scripts
mkdir -p ~/.config/foot
mkdir -p ~/.config/mako
mkdir -p ~/Pictures

# Backup existing configs if they exist
echo "Checking for existing configurations..."
for dir in sway waybar foot; do
    if [ -e ~/.config/$dir ] && [ ! -L ~/.config/$dir ]; then
        echo -e "${YELLOW}Backing up existing ~/.config/$dir to ~/.config/${dir}.backup${NC}"
        mv ~/.config/$dir ~/.config/${dir}.backup
    fi
done

# Create symlinks for Wayland configurations
echo "Creating symlinks..."

# Sway configuration
if [ -L ~/.config/sway ]; then
    rm ~/.config/sway
fi
ln -sf $(pwd)/sway ~/.config/sway
echo "  ✓ Linked sway config"

# Waybar configuration
if [ -L ~/.config/waybar ]; then
    rm ~/.config/waybar
fi
ln -sf $(pwd)/waybar ~/.config/waybar
echo "  ✓ Linked waybar config"

# Foot terminal configuration
if [ -L ~/.config/foot ]; then
    rm ~/.config/foot
fi
ln -sf $(pwd)/foot ~/.config/foot
echo "  ✓ Linked foot config"

# Make waybar scripts executable
chmod +x $(pwd)/waybar/scripts/*.sh 2>/dev/null || true
echo "  ✓ Made waybar scripts executable"

echo ""
echo -e "${GREEN}Configuration files linked successfully!${NC}"
echo ""

# Prompt for shell environment setup
echo "=========================================="
echo "Shell Environment Setup"
echo "=========================================="
echo ""
echo "Would you like to configure your shell for Wayland?"
echo "This will add Wayland environment variables to your shell."
echo ""
echo "Options:"
echo "  1) Add auto-detection to .bashrc (recommended)"
echo "  2) Set up auto-start in .profile"
echo "  3) Skip (configure manually later)"
echo ""
read -p "Choose option (1-3): " -n 1 -r
echo ""

case $REPLY in
    1)
        if ! grep -q "bashrc-wayland" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Source Wayland environment if running under Wayland" >> ~/.bashrc
            echo 'if [ "$XDG_SESSION_TYPE" = "wayland" ]; then' >> ~/.bashrc
            echo '    source ~/.bashrc-wayland' >> ~/.bashrc
            echo 'fi' >> ~/.bashrc

            ln -sf $(pwd)/.bashrc-wayland ~/.bashrc-wayland
            echo -e "${GREEN}Added Wayland detection to .bashrc${NC}"
        else
            echo -e "${YELLOW}Wayland configuration already present in .bashrc${NC}"
        fi
        ;;
    2)
        ln -sf $(pwd)/.profile-wayland ~/.profile-wayland

        if ! grep -q "profile-wayland" ~/.profile; then
            echo "" >> ~/.profile
            echo "# Source Wayland profile" >> ~/.profile
            echo 'if [ -f "$HOME/.profile-wayland" ]; then' >> ~/.profile
            echo '    . "$HOME/.profile-wayland"' >> ~/.profile
            echo 'fi' >> ~/.profile
            echo -e "${GREEN}Added Wayland auto-start to .profile${NC}"
        else
            echo -e "${YELLOW}Wayland configuration already present in .profile${NC}"
        fi
        ;;
    3)
        echo "Skipping shell configuration"
        echo "You can manually source .bashrc-wayland or .profile-wayland later"
        ;;
    *)
        echo "Invalid option, skipping"
        ;;
esac

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Check your display outputs:"
echo "   $ swaymsg -t get_outputs"
echo ""
echo "2. Edit ~/.config/sway/config to update:"
echo "   - Output names (search for 'TODO: Update')"
echo "   - Workspace assignments"
echo "   - Wallpaper paths (optional)"
echo ""
echo "3. Test Sway from a TTY:"
echo "   - Press Ctrl+Alt+F2"
echo "   - Login"
echo "   - Run: sway"
echo ""
echo "4. Read the migration guide:"
echo "   $ less $(pwd)/WAYLAND-MIGRATION.md"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""
