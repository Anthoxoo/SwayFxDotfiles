# Hyprland Configuration Structure

## Overview

Your Hyprland configuration is now organized in a modular, clean structure. Each file in `config.d/` has a single, clear responsibility.

## Directory Structure

```
~/.config/hypr/
├── hyprland.lua              # Main entry point - loads all modules
├── hyprland-gui.lua          # HyprMod GUI settings (auto-generated)
├── hyprland-gui-install.sh   # HyprMod installation script
├── hyprpaper.conf            # Wallpaper configuration
└── config.d/
    ├── default.lua           # Monitor, environment, and general settings
    ├── theme.lua             # Visual settings (colors, decorations, blur, shadow)
    ├── animations.lua        # Animation curves and definitions
    ├── input.lua             # Keyboard layout configuration
    ├── gestures.lua          # Multi-finger gesture controls
    ├── layouts.lua           # Layout-specific configs (dwindle, master, scrolling)
    ├── programs.lua          # Program variables (terminal, browser, etc.)
    ├── keybinds.lua          # All keyboard and mouse shortcuts
    ├── autostart.lua         # Background services and startup commands
    ├── application_defaults.lua # Default behavior for specific applications
    ├── window_rules.lua      # Window and layer rules
    ├── swaylock.lua          # Lock screen configuration
    └── misc.lua              # Miscellaneous settings
```

## File Responsibilities

### Core Configuration Files

**`hyprland.lua`**
- Main entry point
- Loads all modules from `config.d/` in the correct order
- No direct configuration here

**`default.lua`**
- Monitor configuration
- Environment variables (cursor theme/size)
- Basic general settings (layout, tearing, border resize)
- Device-specific configurations

**`theme.lua`**
- Visual appearance settings
- Colors and borders
- Decorations (rounding, shadows)
- Blur effects
- Opacity settings

**`animations.lua`**
- Animation curves (bezier and spring)
- Animation definitions for all elements
- Speed and style configurations

### Input & Gestures

**`input.lua`**
- Keyboard layout
- Input device settings

**`gestures.lua`**
- Multi-finger gesture actions
- Workspace switching gestures

### Application & Autostart

**`programs.lua`**
- Program/command definitions
- Returns a table with programs for use in other modules
- Centralized location to change default programs

**`autostart.lua`**
- Background services on startup
- Notification daemons
- Environment setup
- Runs on `hyprland.start` event

**`application_defaults.lua`**
- Default window behavior for specific apps
- Window floating rules by app
- App-specific settings

### User Interaction

**`keybinds.lua`**
- All keyboard shortcuts
- Mouse bindings
- Organized into sections:
  - Basic window management
  - Focus movement
  - Workspace navigation
  - Floating & fullscreen
  - Mouse operations
  - Screenshots
  - Media keys
  - Media player controls

**`layouts.lua`**
- Dwindle layout configuration
- Master layout configuration
- Scrolling layout configuration

### Rules & Policies

**`window_rules.lua`**
- Window rules (suppress events, fixes, etc.)
- Layer rules
- Application-specific window behaviors

**`swaylock.lua`**
- Lock screen program definition
- Exports `lock_cmd` variable used by other modules

**`misc.lua`**
- Miscellaneous settings
- Force default wallpaper
- Hyprland logo display

## Usage

### Adding New Keybinds

1. Open `~/.config/hypr/config.d/keybinds.lua`
2. Add your bind in the appropriate section
3. Reload: `hyprctl reload`

### Changing Default Programs

1. Open `~/.config/hypr/config.d/programs.lua`
2. Update the program variable
3. Reload: `hyprctl reload`

### Customizing Theme

1. Open `~/.config/hypr/config.d/theme.lua`
2. Modify colors, decorations, or blur settings
3. Reload: `hyprctl reload`

### Adding Window Rules

1. Open `~/.config/hypr/config.d/window_rules.lua`
2. Add your window or layer rule
3. Reload: `hyprctl reload`

### Adding Autostart Commands

1. Open `~/.config/hypr/config.d/autostart.lua`
2. Add your command in the `hyprland.start` event handler
3. Reload or restart Hyprland

## Loading Order

The order in `hyprland.lua` matters for dependencies:

1. **default** - Basic setup
2. **theme** - Visual settings
3. **animations** - Animation definitions
4. **input** - Input settings
5. **gestures** - Gesture setup
6. **layouts** - Layout configs
7. **programs** - Program variables
8. **autostart** - Startup commands
9. **application_defaults** - App-specific defaults
10. **keybinds** - Keyboard shortcuts (uses programs)
11. **window_rules** - Window/layer rules
12. **swaylock** - Lock screen
13. **misc** - Miscellaneous settings

## Tips

- Each file should be modified independently
- Keep related settings in their designated files
- Use comments to document custom settings
- Test changes with `hyprctl reload` (non-destructive)
- Full restart with `hyprctl dispatch exit` if needed

## See Also

- [Hyprland Wiki](https://wiki.hypr.land/)
- `hyprctl help` - Dispatcher commands
- Original config backup in swayfxdotfiles
