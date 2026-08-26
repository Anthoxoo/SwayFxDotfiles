-- autostart.lua: start background services translated from sway/config.d/autostart_applications
hl.on("hyprland.start", function ()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &")
    hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY SWAYSOCK || true")
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK || true")

    -- Wallpaper
    hl.exec_cmd("swaybg -i /home/antoine/Dev/other/Swayfxdotfiles/walls/black-white-ish/3-climb.jpg -m fill &")

    -- Status bar
    hl.exec_cmd("waybar &")

    -- Idle / lock management (hypridle)
    hl.exec_cmd("pidof hypridle || hypridle &")

    -- Notifications and helpers
    hl.exec_cmd("mako &")
    hl.exec_cmd("autotiling &")
    hl.exec_cmd("sleep 2 && firewall-applet &")

    -- Import GTK/desktop settings if user has the script
    hl.exec_cmd("$HOME/.config/sway/scripts/import-gsettings &")
end)
