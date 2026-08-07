# Dotfiles Configuration

Personal dotfiles for Arch Linux with support for both X11 (i3) and Wayland (Sway) environments.

## Features

- **Dual Configuration**: Supports both X11 (i3) and Wayland (Sway)
- **Easy Switching**: Toggle between X11 and Wayland with a single command
- **Unified Setup**: Single script handles both configurations
- **Preserved Keybindings**: Identical keybindings across both environments
- **Status Bar**: i3blocks (X11) / Waybar (Wayland)
- **Terminal**: urxvt (X11) / Foot (Wayland)

## Quick Start

### Initial Setup

Choose your preferred environment:

```bash
# For X11 (i3) setup
./setup.sh x11

# For Wayland (Sway) setup
./setup.sh wayland
```

### Check Current Configuration

```bash
./setup.sh status
```

### Switch Between X11 and Wayland

```bash
./setup.sh switch
```

## Configurations

### X11 (i3) Setup

**Window Manager**: i3-wm
**Status Bar**: i3blocks
**Terminal**: urxvt (daemon mode)
**Compositor**: picom
**Launcher**: rofi
**Notifications**: dunst
**Wallpaper**: nitrogen

**Keybindings**: All custom keybindings preserved
**Integration**: Optional Plasma integration

#### Required Packages (X11)

```bash
sudo pacman -S i3-wm i3blocks dunst nitrogen rofi picom rxvt-unicode
```

### Wayland (Sway) Setup

**Window Manager**: Sway
**Status Bar**: Waybar
**Terminal**: Foot
**Compositor**: Built into Sway
**Launcher**: rofi (with Wayland support)
**Notifications**: mako
**Screenshots**: grim + slurp

**Keybindings**: Identical to i3 setup
**Mode**: Standalone (no DE integration)

#### Required Packages (Wayland)

```bash
sudo pacman -S sway waybar foot mako rofi grim slurp wl-clipboard brightnessctl
```

## File Structure

```
dotfiles/
├── i3/                      # i3 window manager config
│   ├── config               # Main i3 config
│   ├── i3blocks.conf        # Status bar config
│   └── i3blocks-nomedia.conf
├── sway/                    # Sway window manager config
│   └── config               # Main Sway config
├── waybar/                  # Waybar status bar
│   ├── config               # Waybar config (JSON)
│   ├── style.css            # Waybar styling
│   └── scripts/             # Custom scripts
├── foot/                    # Foot terminal config
│   └── foot.ini
├── rofi/                    # Application launcher
│   └── android_notification.rasi
├── powerline/               # Powerline themes
├── .bashrc                  # Main bash configuration
├── .bashrc-wayland          # Wayland-specific env vars
├── .Xresources              # X11 terminal colors
├── picom.conf               # X11 compositor
├── dunstrc                  # Notification daemon (X11)
├── setup.sh                 # Unified setup script ⭐
├── setup_init.sh            # Legacy X11 setup (deprecated)
├── setup_wayland.sh         # Legacy Wayland setup (deprecated)
├── README.md                # This file
└── WAYLAND-MIGRATION.md     # Detailed migration guide
```

## Usage Examples

### Show Current Status

```bash
$ ./setup.sh status

Current Configuration Status
==========================================

Active Configuration: X11 (i3)

Linked Configurations:
  i3:      ✓ Linked
  sway:    ✗ Not linked
  waybar:  ✗ Not linked
  foot:    ✗ Not linked

Shell Environment:
  .bashrc: No Wayland detection
  .bashrc link: ✓ Linked to dotfiles
```

### Switch to Wayland

```bash
$ ./setup.sh switch

Switching Configuration
==========================================
Switching from X11 (i3) to Wayland (Sway)...

Setting Up Wayland (Sway) Configuration
==========================================
✓ Packages already installed
✓ Sway configuration linked
✓ Waybar configuration linked
✓ Foot terminal configuration linked
✓ Wayland detection added to .bashrc

Configuration switched to: Wayland (Sway)
```

### Switch Back to X11

```bash
$ ./setup.sh switch

Switching Configuration
==========================================
Switching from Wayland (Sway) to X11 (i3)...

[Setup process continues...]
```

## Configuration Details

### Keybindings

All keybindings are identical between i3 and Sway:

**Modifier**: `Mod4+Mod1+Shift+Ctrl` (Super+Alt+Shift+Ctrl)
**Meh**: `Mod1+Shift+Ctrl` (Alt+Shift+Ctrl)

| Action | Keybinding |
|--------|-----------|
| Terminal | `$mod+space` or `$mod+t` |
| Launcher | `$mod+o` |
| Kill window | `$meh+q` |
| Workspaces | `$mod+[1-0]` |
| Move to workspace | `$meh+[1-0]` |
| File manager | `$mod+e` |
| Screenshot | `Print` |
| Volume up/down | `XF86AudioRaiseVolume/LowerVolume` |
| Brightness up/down | `XF86MonBrightnessUp/Down` |

### Workspaces

Persistent workspaces with icons:

1. Chromium
2. Chromium
3. Code
4. Code
5. Bash
6. General
7. General
8. Teams
9. General
10. Mail

### Environment Variables (Wayland)

Automatically set when running under Wayland:

- `XDG_SESSION_TYPE=wayland`
- `XDG_CURRENT_DESKTOP=sway`
- `QT_QPA_PLATFORM=wayland`
- `MOZ_ENABLE_WAYLAND=1`
- `ELECTRON_OZONE_PLATFORM_HINT=wayland`

## Tool Replacements

| Function | X11 | Wayland |
|----------|-----|---------|
| Window Manager | i3 | Sway |
| Terminal | urxvt | Foot |
| Status Bar | i3blocks | Waybar |
| Clipboard | xclip | wl-copy/wl-paste |
| Screenshots | flameshot | grim + slurp |
| Brightness | xbacklight | brightnessctl |
| Wallpaper | nitrogen | swaybg |
| Compositor | picom | (built-in) |

## Migrating from X11 to Wayland

For detailed migration instructions, see [WAYLAND-MIGRATION.md](WAYLAND-MIGRATION.md).

Key steps:
1. Run `./setup.sh wayland`
2. Check output names: `swaymsg -t get_outputs`
3. Edit `~/.config/sway/config` to update outputs
4. Test from TTY or select "Sway" from display manager

## Reverting Changes

Your original configurations are always preserved:

- Backups are created with timestamp suffixes (`.backup.YYYYMMDD-HHMMSS`)
- Symlinks are used, so your dotfiles repo is never modified
- You can always switch back: `./setup.sh switch`
- Original branch structure is preserved in git

## Troubleshooting

### Configuration Not Working

```bash
# Check what's linked
./setup.sh status

# Re-run setup
./setup.sh x11    # or wayland
```

### Wayland Apps Not Using Native Protocol

Check environment variables:

```bash
echo $XDG_SESSION_TYPE  # Should be "wayland"
echo $WAYLAND_DISPLAY   # Should be set
```

Re-source shell configuration:

```bash
source ~/.bashrc
```

### Display Outputs Not Correct (Wayland)

Check output names:

```bash
swaymsg -t get_outputs
```

Update in `~/.config/sway/config` (search for "TODO").

## Contributing

This is a personal dotfiles repository, but feel free to:

- Report issues
- Suggest improvements
- Fork and adapt for your own use

## License

See [LICENSE](LICENSE) file.

## Branches

- `master`: Stable X11 (i3) configuration
- `config-wayland`: Wayland (Sway) configuration
- Both are kept in sync and can be easily switched

## Additional Resources

- [i3 User's Guide](https://i3wm.org/docs/userguide.html)
- [Sway Wiki](https://github.com/swaywm/sway/wiki)
- [Waybar Documentation](https://github.com/Alexays/Waybar/wiki)
- [Arch Wiki - Sway](https://wiki.archlinux.org/title/Sway)
- [Arch Wiki - i3](https://wiki.archlinux.org/title/I3)
