# Wayland Migration Guide

This guide helps you transition from the i3+Plasma X11 setup to Sway standalone on Wayland.

## Quick Start

The easiest way to migrate is using the unified setup script:

```bash
# Switch to Wayland configuration
./setup.sh wayland

# Or if you've already setup X11, just switch
./setup.sh switch

# Check current configuration
./setup.sh status
```

For manual installation or detailed information, continue reading below.

## Prerequisites

### Required Packages

Install the core Wayland components:

```bash
sudo pacman -S sway swayidle swaylock swaybg waybar foot
```

### Wayland Tools (X11 replacements)

```bash
sudo pacman -S grim slurp wl-clipboard brightnessctl mako
```

Optional but recommended:

```bash
sudo pacman -S wl-clipboard xdg-desktop-portal-wlr
```

### Additional Tools

```bash
# Rofi with Wayland support
sudo pacman -S rofi

# If you want dunst instead of mako for notifications
sudo pacman -S dunst

# For system tray support
sudo pacman -S network-manager-applet blueman
```

## Installation Steps

### Automatic Installation (Recommended)

```bash
./setup.sh wayland
```

This will:
- Check and install required packages
- Create all necessary symlinks
- Configure shell environment
- Show next steps

### Manual Installation

If you prefer manual setup, from the dotfiles directory:

```bash
# Sway configuration
ln -sf ~/projects/dotfiles/sway ~/.config/sway

# Waybar configuration
ln -sf ~/projects/dotfiles/waybar ~/.config/waybar

# Foot terminal configuration
ln -sf ~/projects/dotfiles/foot ~/.config/foot

# Wayland shell environment
ln -sf ~/projects/dotfiles/.bashrc-wayland ~/.bashrc-wayland

# Add to .bashrc:
echo 'if [ "$XDG_SESSION_TYPE" = "wayland" ]; then' >> ~/.bashrc
echo '    source ~/.bashrc-wayland' >> ~/.bashrc
echo 'fi' >> ~/.bashrc
```

### 2. Configure Display Outputs

**IMPORTANT:** Display output names differ from X11!

Check your output names:

```bash
swaymsg -t get_outputs
```

Example output:
```
Output HDMI-A-1 'Samsung ...'
Output DP-1 'Dell ...'
Output DP-2 'LG ...'
```

Edit `~/.config/sway/config` and update the output sections:

```
# Around line 31-40, add your outputs:
output HDMI-A-1 pos 0 0 res 1920x1080
output DP-1 pos 1920 0 res 2560x1440
output DP-2 pos 4480 0 res 1920x1080

# Set wallpapers (optional):
output HDMI-A-1 bg /path/to/wallpaper.jpg fill
output DP-1 bg /path/to/wallpaper.jpg fill
output DP-2 bg /path/to/wallpaper.jpg fill

# Around line 173-181, update workspace assignments:
workspace $WS1 output DP-1
workspace $WS2 output HDMI-A-1
workspace $WS3 output DP-1
# ... etc
```

### 3. Update Shell Environment

#### Option A: Auto-detect session type

Add to your `~/.bashrc`:

```bash
# Source Wayland environment if running under Wayland
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    source ~/.bashrc-wayland
fi
```

#### Option B: Set in profile

If you want Sway to auto-start on login, add to `~/.profile`:

```bash
# Source Wayland profile
if [ -f "$HOME/.profile-wayland" ]; then
    . "$HOME/.profile-wayland"
fi
```

### 4. Configure Input Devices (Optional)

Edit `~/.config/sway/config` around line 340:

```
# Keyboard configuration
input type:keyboard {
    xkb_layout us
    xkb_options grp:alt_shift_toggle
}

# Touchpad configuration
input type:touchpad {
    tap enabled
    natural_scroll enabled
    dwt enabled
    accel_profile adaptive
    pointer_accel 0.3
}
```

### 5. Test Sway Session

#### From a TTY

1. Switch to TTY (Ctrl+Alt+F2)
2. Login
3. Run: `sway`

#### From Display Manager

Select "Sway" from your login screen session menu.

## Key Differences from i3

### Keybindings

All your keybindings remain the same! The config syntax is identical.

### Tools Replaced

| X11 Tool | Wayland Replacement | Usage |
|----------|---------------------|-------|
| `xclip` | `wl-copy` / `wl-paste` | Clipboard |
| `xbacklight` | `brightnessctl` | Brightness |
| `flameshot` | `grim` + `slurp` | Screenshots |
| `nitrogen` | `swaybg` | Wallpaper |
| `i3-msg` | `swaymsg` | IPC commands |
| `xdotool` | `ydotool` | Automation (needs setup) |

### Screenshot Commands

```bash
# Full screen
grim ~/Pictures/screenshot.png

# Select area (configured as Print key)
grim -g "$(slurp)" ~/Pictures/screenshot.png

# Current window
grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" ~/Pictures/screenshot.png
```

### Clipboard Commands

```bash
# Copy to clipboard
echo "text" | wl-copy

# Paste from clipboard
wl-paste

# Copy file contents
wl-copy < file.txt
```

## Waybar vs i3blocks

Waybar is configured via JSON and styled with CSS.

- Config: `~/.config/waybar/config`
- Style: `~/.config/waybar/style.css`
- Scripts: `~/.config/waybar/scripts/`

Key features:
- Better integration with Wayland
- CSS styling for fine-tuned appearance
- Built-in modules for most common tasks
- MPRIS support for media player info

## Foot Terminal

Foot is designed for speed and is one of the fastest terminal emulators on Wayland (comparable to urxvt launch times).

Configuration: `~/.config/foot/foot.ini`

Key features:
- Instant launch times
- Low memory footprint
- Excellent font rendering
- True transparency support
- Wayland-native

## Troubleshooting

### Applications Not Using Wayland

Check if environment variables are set:

```bash
echo $XDG_SESSION_TYPE  # Should be "wayland"
echo $WAYLAND_DISPLAY   # Should be "wayland-0" or similar
```

Force specific apps to use Wayland:

```bash
# Chromium/Chrome
chromium --enable-features=UseOzonePlatform --ozone-platform=wayland

# Firefox (should auto-detect with MOZ_ENABLE_WAYLAND=1)
firefox

# Electron apps (VSCode, etc.)
code --enable-features=UseOzonePlatform --ozone-platform=wayland
```

### Screen Tearing or Stuttering

Sway has native compositing, but you can adjust:

```
# In ~/.config/sway/config
max_render_time 5
```

### HiDPI Displays

```
# In ~/.config/sway/config
output HDMI-A-1 scale 1.5
output DP-1 scale 2
```

### Applications Using XWayland

XWayland is enabled by default. Check if an app is using it:

```bash
swaymsg -t get_tree | jq '.. | select(.shell?) | {name, shell}'
```

Apps with `"shell": "xwayland"` are running via XWayland.

## Switching Between X11 and Wayland

### Using the Setup Script (Easiest)

```bash
# Switch to the other configuration
./setup.sh switch

# Check what's currently active
./setup.sh status
```

### Manual Switching

Your configurations coexist, so you can:

1. **At login screen**: Select "i3" or "Sway" session
2. **Configuration files**: Both `~/.config/i3/` and `~/.config/sway/` exist
3. **Shell environment**: Auto-detects session type via `$XDG_SESSION_TYPE`

### Reverting to X11 Permanently

```bash
./setup.sh x11
```

This will:
- Ensure X11 configuration is linked
- Remove Wayland-specific shell configuration
- Preserve your Wayland configs (just not linked)

## Migration Checklist

- [ ] Install required packages
- [ ] Link configuration files
- [ ] Check output names with `swaymsg -t get_outputs`
- [ ] Update output configuration in sway config
- [ ] Update workspace-to-output assignments
- [ ] Set wallpapers (optional)
- [ ] Configure input devices
- [ ] Source Wayland environment in shell
- [ ] Test Sway session from TTY
- [ ] Verify keybindings work
- [ ] Test applications (browser, terminal, file manager)
- [ ] Configure waybar to your liking
- [ ] Set up screenshot shortcuts
- [ ] Test clipboard operations

## Additional Resources

- Sway documentation: `man 5 sway`
- Waybar wiki: https://github.com/Alexays/Waybar/wiki
- Sway wiki: https://github.com/swaywm/sway/wiki
- Arch Wiki Sway: https://wiki.archlinux.org/title/Sway

## Quick Reference

### Common Sway Commands

```bash
# Reload configuration
swaymsg reload

# Get output information
swaymsg -t get_outputs

# Get window information
swaymsg -t get_tree

# Move workspace to different output
swaymsg move workspace to output right
swaymsg move workspace to output DP-1
```

### Waybar Reload

```bash
# Restart waybar
pkill waybar && waybar &
```
