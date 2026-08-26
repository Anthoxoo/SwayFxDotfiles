-- swaylock.lua: Lock screen configuration (using hyprlock)
-- Expose a global lock_cmd variable used by keybinds and autostart
-- hyprlock reads its config from ~/.config/hypr/hyprlock.conf

lock_cmd = "hyprlock"

-- Note: idle/auto-locking isn't started here. If you want automatic locking on idle,
-- configure hypridle (the Hypr-native idle daemon) or swayidle to call lock_cmd.
