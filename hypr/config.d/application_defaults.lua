-- application_defaults.lua: translated from sway/config.d/application_defaults
-- Best-effort translations: mark common dialogs/utility windows as floating

hl.window_rule({ name = "yad-floating", match = { class = "Yad" }, float = true })
-- pavucontrol uses a class/name rather than app_id in Hypr's matcher; match by class instead
hl.window_rule({ name = "pavucontrol", match = { class = "Pavucontrol" }, float = true })

-- Generic "dialog" window_type from Sway cannot be matched reliably by Hypr's Lua API
-- Leave as a manual note for now. Remove broad rules that might match too much.
-- See original Sway rules in Dev/other/Swayfxdotfiles/sway/config.d/application_defaults for reference.

-- Many original Sway rules are preserved here as comments for manual review.
-- Original rules available in Swayfxdotfiles; review & refine as needed.
