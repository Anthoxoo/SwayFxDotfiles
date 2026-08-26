-- programs.lua: Application and command definitions

-- Terminal emulator
local terminal = "kitty"

-- File manager
local fileManager = "dolphin"

-- Code editor
local codeEditor = "zed"

-- Web browser
local browser = "firefox"

-- Application launcher
-- Priority: fuzzel > wofi > hyprlauncher
local launcher_cmd = "sh -c 'command -v fuzzel >/dev/null 2>&1 && fuzzel || (command -v wofi >/dev/null 2>&1 && wofi || hyprlauncher)'"

-- Power menu
local powermenu = "$HOME/.config/sway/scripts/power_menu.sh"

-- Menu
local menu = "hyprlauncher"

-- Return programs for use in other modules
return {
    terminal = terminal,
    fileManager = fileManager,
    codeEditor = codeEditor,
    browser = browser,
    launcher_cmd = launcher_cmd,
    powermenu = powermenu,
    menu = menu,
}
