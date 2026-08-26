-- hyprland.lua: Main Hyprland configuration
-- This file loads all modular configuration files from config.d/
-- Each module has a single responsibility

-- Load GUI helpers (hyprland-gui for HyprMod settings)
require("hyprland-gui")

-- Set up package path to load config.d modules
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.config/hypr/config.d/?.lua"

-- ============================================
-- Load Configuration Modules (order matters)
-- ============================================

-- Core settings
require("default")         -- Monitor and basic display setup
require("theme")           -- Visual settings (colors, decorations, blur)
require("animations")      -- Animation curves and definitions

-- Input and device settings
require("input")           -- Keyboard layout
require("gestures")        -- Multi-finger gestures

-- Layout configurations
require("layouts")         -- Dwindle, Master, Scrolling layouts

-- Applications and auto-start
require("programs")        -- Program variables (will be used in keybinds)
require("autostart")       -- Background services and startup
require("application_defaults") -- Default applications

-- User interactions
require("keybinds")        -- All keyboard and mouse shortcuts

-- Rules and policies
require("window_rules")    -- Window and layer rules

-- Security and session
require("swaylock")        -- Lock screen configuration
