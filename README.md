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

#### Claude Code session overview

The `custom/claude-sessions` Waybar module shows every running Claude Code
session at a glance — terminal and VSCode-hosted, across all projects:

```
󰚩  ! 1 3m  ▸ 2  ○ 9   # 1 blocked on you for 3 min, 2 working, 9 idle
```

Red means at least one session is blocked on a permission prompt, and the age
next to it is how long it has been waiting. Hover for the full list — state,
name, last-active age, the conversation title `/resume` shows, working
directory, terminal vs. VSCode:

```
▸ dotfiles-ec            2m  Claude-code agents overview in swaybar   ~/projects/dotfiles  [term]
· cassistant-ledger-77   3h  Deployment gate design review            ~/code/cassistant-ledger  [vscode]
· cassistant-ledger-82   3h  CI failures                              ~/code/cassistant-ledger  [vscode]
```

The title is what makes five sessions in the same project tellable apart.

| Click | Action |
|-------|--------|
| Left | rofi picker over all sessions (with titles); focuses the window of the one you choose |
| Right | jump straight to the session that most wants attention (longest-blocked, else longest-running, else most recent) |
| Middle | open `claude agents` in a terminal |

How it works:

- **Roster** — `waybar/scripts/claude-sessions-lib.sh` reads Claude Code's own
  session registry at `~/.claude/sessions/<pid>.json`, filtered to PIDs that
  are still alive. No per-project setup, and sessions started before the module
  existed still show up.
- **State** — the registry only carries a `status` field for terminal sessions,
  so `waybar/scripts/claude-sessions-state.sh` is wired in as a Claude Code hook
  and writes `$XDG_RUNTIME_DIR/claude-sessions/<session-id>.json` on every state
  change. That is what covers VSCode-hosted sessions. Hook state wins; the
  registry is the fallback.
- **Updates** — event-driven. Each hook fires `pkill -RTMIN+9 waybar`, so the
  bar updates the moment a session changes. The 60 s `interval` is only a
  safety net for sessions killed without firing `SessionEnd`.
- **Titles** — Claude Code appends the `/resume` conversation title to the
  session transcript as `{"type":"ai-title",...}` and rewrites it as the
  conversation moves on, so the last entry wins. The lookup reads the
  transcript backwards and stops at the first hit rather than parsing
  megabytes: ~40 ms for a dozen sessions, so no cache is needed.
- **Focus** — `waybar/scripts/claude-sessions-focus.sh` walks the process
  ancestry from the session's PID until it hits a PID sway knows as a window.
  For a terminal that lands exactly on the emulator. Every VSCode window shares
  one Electron main process, so there the walk only narrows it to "some VSCode
  window" and the workspace folder in the title picks the right one — matched
  as a whole `" - "` segment, since a substring match would send
  `~/code/cassistant` to the `cassistant-ledger` window.

The hooks live in `~/.claude/settings.json`, outside this repo, so
`./setup.sh wayland` merges them in from `waybar/claude-hooks.json`. The merge
is idempotent and leaves any unrelated hooks alone (it backs the file up first).

Requires `jq`, `rofi` (for the picker) and a Nerd Font for the robot glyph.

#### Required Packages (Wayland)

```bash
sudo pacman -S sway waybar foot mako rofi grim slurp wl-clipboard brightnessctl jq
```

## File Structure

```
dotfiles/
├── i3/                      # i3 window manager config
│   ├── config               # Main i3 config
│   ├── i3blocks.conf        # Status bar config
│   └── i3blocks-nomedia.conf
├── sway/                    # Sway window manager config
│   ├── config               # Main Sway config
│   ├── chrome-workspaces.sh # Saves/restores Chromium window placement
│   └── toggle-recording.sh  # wf-recorder start/stop toggle
├── waybar/                  # Waybar status bar
│   ├── config               # Waybar config (JSON)
│   ├── style.css            # Waybar styling
│   ├── claude-hooks.json    # Claude Code hooks, merged into ~/.claude/settings.json
│   └── scripts/             # Custom scripts
│       ├── claude-sessions-lib.sh    # Session roster (shared)
│       ├── claude-sessions.sh        # Widget renderer
│       ├── claude-sessions-state.sh  # Claude Code hook handler
│       └── claude-sessions-focus.sh  # Picker + window focus
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

#### Window placement (Sway)

VS Code and Sublime Merge are assigned to workspace 3 (Code). They open there
without pulling focus off the workspace you launched them from - press
`$mod+3` to follow.

Chromium windows go back to the workspace they were on before. Chromium itself
restores the windows and tabs ("Continue where you left off"), but Wayland has
no session management, so sway would otherwise drop every restored window onto
whichever workspace happened to be focused. `sway/chrome-workspaces.sh` runs as
a daemon (started via `exec_always`), snapshots "window title -> workspace"
while Chromium runs, and replays it the next time Chromium starts. Matching is
by window title, since Chromium has no stable window ids across restarts.

```bash
# Snapshot lives here
~/.local/state/sway/chromium-workspaces.json

~/.config/sway/chrome-workspaces.sh status    # show the snapshot + daemon state
~/.config/sway/chrome-workspaces.sh save      # snapshot now
~/.config/sway/chrome-workspaces.sh restore   # re-apply the snapshot now
```

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
