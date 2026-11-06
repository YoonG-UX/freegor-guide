local _, ns = ...

-- Default (English) strings. Missing keys fall back to the key itself.
local L = setmetatable({}, { __index = function(_, k) return k end })
ns.L = L

L.ADDON_NAME      = "Freegor Guide"
L.NO_GUIDE        = "No guide loaded. Click the book button to choose one."
L.STEP_FMT        = "Step %d / %d"
L.GUIDE_DONE      = "Guide complete!"
L.NEXT_GUIDE      = "Next guide: %s"
L.LOAD_NEXT       = "Load next guide"
L.CHOOSE_GUIDE    = "Choose a guide"
L.PREV            = "Previous step"
L.NEXT            = "Next step"
L.SKIP_HINT       = "Click the goal to set the waypoint. Use the arrows to move between steps."
L.MANUAL_HINT     = "Click \"Next\" when done."
L.ARRIVED         = "You have arrived."
L.YARDS_FMT       = "%d yd"
L.OTHER_ZONE      = "Destination is in another zone: %s"
L.LOADED_FMT      = "Guide loaded: %s"
L.UNKNOWN_GUIDE   = "Unknown guide: %s"
L.PARSE_ERROR_FMT = "Error in guide \"%s\", line %d: %s"
L.FILTER_ALL      = "All"
L.LEVELS_FMT      = "levels %d-%d"

-- goal labels
L.GOAL_ACCEPT  = "Accept |cffffd100%s|r"
L.GOAL_TURNIN  = "Turn in |cffffd100%s|r"
L.GOAL_KILL    = "Kill %s"
L.GOAL_COLLECT = "Collect %s"
L.GOAL_DO      = "Complete |cffffd100%s|r"
L.GOAL_TALK    = "Talk to |cff00ff96%s|r"
L.GOAL_GOTO    = "Go to %s"
L.GOAL_LEVEL   = "Reach level %d"
L.QUEST_FMT    = "quest #%d"

L.HELP = {
  "/freegor - show or hide the guide window",
  "/freegor list - choose a guide",
  "/freegor next | prev - move between steps",
  "/freegor step <n> - jump to a step",
  "/freegor arrow - show or hide the arrow",
  "/freegor reset - reset the window position",
}
