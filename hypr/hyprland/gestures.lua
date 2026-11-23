local vars = require("variables")
local fn   = require("utils.functions")

hl.config({
    gestures = {
        workspace_swipe_distance                 = 700,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new               = true,
    },
})

hl.gesture({ fingers = vars.workspaceSwipeFingers, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = vars.gestureFingers, direction = "up", action = "special", workspace_name = "special" })
hl.gesture({
    fingers   = vars.gestureFingers,
    direction = "down",
    action    = fn.toggle("specialws"),
})
hl.gesture({
    fingers   = vars.gestureFingersMore,
    direction = "down",
    action    = function()
        -- Same as the sleep bind: the shell falls back to plain suspend without hibernation
        hl.dispatch(hl.dsp.global("caelestia:sleep"))
    end,
})
