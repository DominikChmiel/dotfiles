#!/bin/bash

# Unified Setup Script for X11 (i3) and Wayland (Sway)
# Usage: ./setup.sh [x11|wayland|switch|status]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DOTFILES_DIR="$(pwd)"
STATE_FILE="$HOME/.config/.wm-state"

# Helper functions
print_header() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_package() {
    pacman -Q "$1" &> /dev/null
}

get_current_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "none"
    fi
}

set_current_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$1" > "$STATE_FILE"
}

# Show current status
show_status() {
    print_header "Current Configuration Status"

    CURRENT_STATE=$(get_current_state)

    if [ "$CURRENT_STATE" = "x11" ]; then
        echo -e "Active Configuration: ${GREEN}X11 (i3)${NC}"
    elif [ "$CURRENT_STATE" = "wayland" ]; then
        echo -e "Active Configuration: ${GREEN}Wayland (Sway)${NC}"
    else
        echo -e "Active Configuration: ${YELLOW}None (not configured)${NC}"
    fi

    echo ""
    echo "Linked Configurations:"

    # Check what's currently linked
    if [ -L ~/.config/i3 ]; then
        echo -e "  i3:      ${GREEN}✓ Linked${NC}"
    else
        echo -e "  i3:      ${RED}✗ Not linked${NC}"
    fi

    if [ -L ~/.config/sway ]; then
        echo -e "  sway:    ${GREEN}✓ Linked${NC}"
    else
        echo -e "  sway:    ${RED}✗ Not linked${NC}"
    fi

    if [ -L ~/.config/waybar ]; then
        echo -e "  waybar:  ${GREEN}✓ Linked${NC}"
    else
        echo -e "  waybar:  ${RED}✗ Not linked${NC}"
    fi

    if [ -L ~/.config/foot ]; then
        echo -e "  foot:    ${GREEN}✓ Linked${NC}"
    else
        echo -e "  foot:    ${RED}✗ Not linked${NC}"
    fi

    echo ""
    echo "Shell Environment:"

    if grep -q "bashrc-wayland" ~/.bashrc 2>/dev/null; then
        echo -e "  .bashrc: ${GREEN}Wayland detection enabled${NC}"
    else
        echo -e "  .bashrc: ${YELLOW}No Wayland detection${NC}"
    fi

    if [ -L ~/.bashrc ]; then
        if [ "$(readlink ~/.bashrc)" = "${DOTFILES_DIR}/.bashrc" ]; then
            echo -e "  .bashrc link: ${GREEN}✓ Linked to dotfiles${NC}"
        else
            echo -e "  .bashrc link: ${YELLOW}⚠ Linked elsewhere${NC}"
        fi
    else
        echo -e "  .bashrc link: ${YELLOW}Not linked (standalone file)${NC}"
    fi

    echo ""
}

# Setup common/base configuration
setup_common() {
    print_header "Setting Up Common Configuration"

    # Initialize submodules
    if [ -f .gitmodules ]; then
        echo "Initializing git submodules..."
        git submodule init
        git submodule update
        print_success "Submodules initialized"
    fi

    # Create necessary directories
    mkdir -p ~/.config/systemd/user/
    mkdir -p ~/.config/i3
    mkdir -p ~/.config/dunst
    mkdir -p ~/Pictures

    # Common links (used by both X11 and Wayland)
    echo "Creating common symlinks..."

    [ ! -e ~/.wgetrc ] && ln -sf "$DOTFILES_DIR/.wgetrc" ~/.wgetrc
    [ ! -e ~/.nanorc ] && ln -sf "$DOTFILES_DIR/.nanorc" ~/.nanorc
    [ ! -e ~/.inputrc ] && ln -sf "$DOTFILES_DIR/.inputrc" ~/.inputrc
    [ ! -e ~/.dircolors ] && ln -sf "$DOTFILES_DIR/.dircolors" ~/.dircolors
    [ ! -e ~/.direnvrc ] && ln -sf "$DOTFILES_DIR/.direnvrc" ~/.direnvrc
    [ ! -e ~/.face ] && ln -sf "$DOTFILES_DIR/.face" ~/.face
    [ ! -e ~/.face.icon ] && ln -sf "$DOTFILES_DIR/.face" ~/.face.icon
    [ ! -e ~/.tmux.conf ] && ln -sf "$DOTFILES_DIR/.tmux.conf" ~/.tmux.conf
    [ ! -e ~/.config/rofi ] && ln -sf "$DOTFILES_DIR/rofi" ~/.config/rofi
    [ ! -e ~/.config/powerline ] && ln -sf "$DOTFILES_DIR/powerline" ~/.config/powerline

    print_success "Common configuration linked"
}

# Setup X11 (i3) configuration
setup_x11() {
    print_header "Setting Up X11 (i3) Configuration"

    # Check for required packages
    MISSING_X11=()
    for pkg in i3-wm i3blocks dunst nitrogen rofi picom; do
        if ! check_package "$pkg"; then
            MISSING_X11+=("$pkg")
        fi
    done

    if [ ${#MISSING_X11[@]} -gt 0 ]; then
        print_warning "Missing X11 packages: ${MISSING_X11[*]}"
        read -p "Install missing packages? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo pacman -S --needed "${MISSING_X11[@]}"
            print_success "Packages installed"
        fi
    fi

    # Setup common first
    setup_common

    # Link .bashrc if not already a link to our version
    if [ ! -L ~/.bashrc ] || [ "$(readlink ~/.bashrc)" != "${DOTFILES_DIR}/.bashrc" ]; then
        if [ -f ~/.bashrc ] && [ ! -L ~/.bashrc ]; then
            mv ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d-%H%M%S)
            print_warning "Backed up existing .bashrc"
        fi
        ln -sf "$DOTFILES_DIR/.bashrc" ~/.bashrc
    fi

    # Link .profile if not already linked
    if [ ! -L ~/.profile ] || [ "$(readlink ~/.profile)" != "${DOTFILES_DIR}/.profile" ]; then
        if [ -f ~/.profile ] && [ ! -L ~/.profile ]; then
            mv ~/.profile ~/.profile.backup.$(date +%Y%m%d-%H%M%S)
            print_warning "Backed up existing .profile"
        fi
        ln -sf "$DOTFILES_DIR/.profile" ~/.profile
    fi

    # X11 specific links
    ln -sf "$DOTFILES_DIR/.Xresources" ~/.Xresources
    ln -sf "$DOTFILES_DIR/picom.conf" ~/.config/picom.conf

    # i3 configuration
    if [ -e ~/.config/i3 ] && [ ! -L ~/.config/i3 ]; then
        mv ~/.config/i3 ~/.config/i3.backup.$(date +%Y%m%d-%H%M%S)
        print_warning "Backed up existing i3 config"
    fi
    [ -L ~/.config/i3 ] && rm ~/.config/i3
    ln -sf "$DOTFILES_DIR/i3" ~/.config/i3

    # Dunst configuration
    [ ! -e ~/.config/dunst/dunstrc ] && ln -sf "$DOTFILES_DIR/dunstrc" ~/.config/dunst/dunstrc

    # Plasma integration (optional)
    if check_package "plasma-workspace"; then
        print_warning "Plasma detected. Setting up i3+Plasma integration..."
        ln -sf "$DOTFILES_DIR/i3.service" ~/.config/systemd/user/
        systemctl --user daemon-reload
        systemctl --user add-wants plasma-workspace@x11.target i3.service 2>/dev/null || true
        systemctl --user mask plasma-kwin_x11.service 2>/dev/null || true
        print_success "Plasma integration configured"
    fi

    # Configure rofi theme path
    if [ -f "$DOTFILES_DIR/i3blocks-contrib/shutdown_menu/shutdown_menu" ]; then
        sed -i 's|ROFI_OPTIONS=(-width -11 -location 3 -hide-scrollbar -bw 2)|ROFI_OPTIONS=(-width -11 -location 3 -hide-scrollbar -bw 2 -theme ~/.config/rofi/android_notification.rasi)|g' \
            "$DOTFILES_DIR/i3blocks-contrib/shutdown_menu/shutdown_menu"
    fi

    # Remove Wayland shell configuration if present
    if grep -q "bashrc-wayland" ~/.bashrc 2>/dev/null; then
        print_warning "Removing Wayland shell configuration..."
        sed -i '/bashrc-wayland/d' ~/.bashrc
        sed -i '/XDG_SESSION_TYPE.*wayland/d' ~/.bashrc
    fi

    set_current_state "x11"

    print_success "X11 (i3) configuration complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Log out and select 'i3' or 'Plasma + i3' session"
    echo "  2. Your keybindings and workspaces are ready to use"
    echo ""
}

# Setup Wayland (Sway) configuration
setup_wayland() {
    print_header "Setting Up Wayland (Sway) Configuration"

    # Check for required packages
    MISSING_WAYLAND=()
    for pkg in sway waybar foot grim slurp wl-clipboard brightnessctl mako rofi; do
        if ! check_package "$pkg"; then
            MISSING_WAYLAND+=("$pkg")
        fi
    done

    if [ ${#MISSING_WAYLAND[@]} -gt 0 ]; then
        print_warning "Missing Wayland packages: ${MISSING_WAYLAND[*]}"
        read -p "Install missing packages? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo pacman -S --needed "${MISSING_WAYLAND[@]}" xdg-desktop-portal-wlr
            print_success "Packages installed"
        fi
    fi

    # Setup common first
    setup_common

    # Sway configuration
    if [ -e ~/.config/sway ] && [ ! -L ~/.config/sway ]; then
        mv ~/.config/sway ~/.config/sway.backup.$(date +%Y%m%d-%H%M%S)
        print_warning "Backed up existing sway config"
    fi
    [ -L ~/.config/sway ] && rm ~/.config/sway
    ln -sf "$DOTFILES_DIR/sway" ~/.config/sway

    # Waybar configuration
    if [ -e ~/.config/waybar ] && [ ! -L ~/.config/waybar ]; then
        mv ~/.config/waybar ~/.config/waybar.backup.$(date +%Y%m%d-%H%M%S)
        print_warning "Backed up existing waybar config"
    fi
    [ -L ~/.config/waybar ] && rm ~/.config/waybar
    ln -sf "$DOTFILES_DIR/waybar" ~/.config/waybar

    # Foot terminal configuration
    if [ -e ~/.config/foot ] && [ ! -L ~/.config/foot ]; then
        mv ~/.config/foot ~/.config/foot.backup.$(date +%Y%m%d-%H%M%S)
        print_warning "Backed up existing foot config"
    fi
    [ -L ~/.config/foot ] && rm ~/.config/foot
    ln -sf "$DOTFILES_DIR/foot" ~/.config/foot

    # Mako configuration (optional)
    mkdir -p ~/.config/mako

    # Make waybar scripts executable
    chmod +x "$DOTFILES_DIR/waybar/scripts/"*.sh 2>/dev/null || true

    # Setup Wayland shell environment
    ln -sf "$DOTFILES_DIR/.bashrc-wayland" ~/.bashrc-wayland

    if ! grep -q "bashrc-wayland" ~/.bashrc 2>/dev/null; then
        echo "" >> ~/.bashrc
        echo "# Source Wayland environment if running under Wayland" >> ~/.bashrc
        echo 'if [ "$XDG_SESSION_TYPE" = "wayland" ]; then' >> ~/.bashrc
        echo '    source ~/.bashrc-wayland' >> ~/.bashrc
        echo 'fi' >> ~/.bashrc
        print_success "Added Wayland detection to .bashrc"
    else
        print_success "Wayland detection already in .bashrc"
    fi

    set_current_state "wayland"

    print_success "Wayland (Sway) configuration complete!"
    echo ""
    echo "IMPORTANT - Next steps:"
    echo "  1. Check your display outputs:"
    echo "     $ swaymsg -t get_outputs"
    echo ""
    echo "  2. Edit ~/.config/sway/config to update:"
    echo "     - Output names (search for 'TODO')"
    echo "     - Workspace assignments"
    echo ""
    echo "  3. Test from TTY (Ctrl+Alt+F2):"
    echo "     - Login and run: sway"
    echo ""
    echo "  4. Or select 'Sway' from your display manager"
    echo ""
    echo "  5. Read the migration guide:"
    echo "     $ less $DOTFILES_DIR/WAYLAND-MIGRATION.md"
    echo ""
}

# Switch between X11 and Wayland
switch_config() {
    CURRENT_STATE=$(get_current_state)

    if [ "$CURRENT_STATE" = "none" ]; then
        print_error "No configuration detected. Run setup first."
        echo "Usage: $0 x11    # Setup X11"
        echo "       $0 wayland # Setup Wayland"
        exit 1
    fi

    print_header "Switching Configuration"

    if [ "$CURRENT_STATE" = "x11" ]; then
        echo "Switching from X11 (i3) to Wayland (Sway)..."
        setup_wayland
    else
        echo "Switching from Wayland (Sway) to X11 (i3)..."
        setup_x11
    fi
}

# Show usage
show_usage() {
    echo "Unified Setup Script for X11 and Wayland"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  x11        Setup X11 (i3) configuration"
    echo "  wayland    Setup Wayland (Sway) configuration"
    echo "  switch     Switch between X11 and Wayland"
    echo "  status     Show current configuration status"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 x11        # Setup and switch to i3"
    echo "  $0 wayland    # Setup and switch to Sway"
    echo "  $0 switch     # Toggle between current configs"
    echo "  $0 status     # Show what's currently configured"
    echo ""
}

# Main script
main() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Do not run this script as root"
        exit 1
    fi

    case "${1:-}" in
        x11)
            setup_x11
            ;;
        wayland)
            setup_wayland
            ;;
        switch)
            switch_config
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
