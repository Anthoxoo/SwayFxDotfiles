-- default.lua: Basic display and system settings

-- ============================================
-- Monitor Configuration
-- ============================================

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

-- ============================================
-- Environment Variables
-- ============================================

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ============================================
-- General Settings
-- ============================================

hl.config({
    general = {
        layout = "dwindle",
        resize_on_border = false,
        allow_tearing = false,
    },
})

-- ============================================
-- Device Configuration
-- ============================================

-- Example per-device config for external mouse
-- hl.device({
--     name = "epic-mouse-v1",
--     sensitivity = -0.5,
-- })
