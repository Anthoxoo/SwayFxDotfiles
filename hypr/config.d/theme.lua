-- theme.lua: Visual settings and color scheme
-- Colors from black-white-ish palette

-- ============================================
-- Decorations, Blur and Basic Colors
-- ============================================
hl.config({
    decoration = {
        rounding = 0,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
        },
    },
    general = {
        border_size = 1,
        gaps_in = 4,
        gaps_out = 4,
        col = {
            active_border = { colors = {"#798186", "#cacccc"}, angle = 45 },
            inactive_border = "#1e1e1e",
        },
    },
})

-- ============================================
-- Cursor / GTK preferences
-- ============================================
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")

-- Exporting environment variables for consistency with theme
hl.exec_cmd("export XCURSOR_THEME=breeze_cursors || true")
hl.exec_cmd("export XCURSOR_SIZE=24 || true")

-- Note: font / GTK theming is handled via import-gsettings script
