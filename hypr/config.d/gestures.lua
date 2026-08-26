-- gestures.lua: Gesture controls for multi-finger input

-- 3-finger horizontal swipe to switch workspaces
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})
