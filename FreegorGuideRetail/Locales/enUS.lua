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
L.GOAL_HOME      = "Set your hearthstone at |cff00ff96%s|r"
L.GOAL_FPATH     = "Get the flight path at |cff00ff96%s|r"
L.GOAL_FLY       = "Fly to |cff00ff96%s|r"
L.GOAL_HEARTH    = "Use your hearthstone"
L.GOAL_HEARTH_TO = "Hearth to |cff00ff96%s|r"
L.GOAL_TRAIN     = "Visit your class trainer"
L.GOAL_USE       = "Use %s"
L.GOAL_BUY       = "Buy %s"
L.AUTO_ON        = "Automatic quest accept/turn-in: |cff00ff00on|r (hold Shift to suspend)"
L.AUTO_OFF       = "Automatic quest accept/turn-in: |cffff4040off|r"
L.GOAL_GOLD    = "Have |cffffd100%d gold|r"
L.GOAL_ITEM    = "Get |cffffd100%s|r"
L.GOAL_ITEM_N  = "Get %d x |cffffd100%s|r"
L.GOAL_REP     = "Reach %s with |cff00ff96%s|r"
L.GOAL_ACHIEVE = "Achievement: |cffffd100%s|r"
L.STANDING_1, L.STANDING_2, L.STANDING_3, L.STANDING_4 = "Hated", "Hostile", "Unfriendly", "Neutral"
L.STANDING_5, L.STANDING_6, L.STANDING_7, L.STANDING_8 = "Friendly", "Honored", "Revered", "Exalted"
L.MENU_TITLE       = "Freegor Guide - what to track?"
L.CURRENT_FMT      = "Active guide: %s"
L.CAT_leveling     = "Leveling"
L.CAT_mounts       = "Mounts"
L.CAT_gold         = "Gold & gathering"
L.CAT_reputation   = "Reputation"
L.CAT_achievements = "Achievements & collections"
L.NO_ACHIEVEMENTS  = "This client has no achievement system: these guides track goals the game can check (flight points, ...)."
L.NO_GUIDES_IN_CAT = "No guide in this category for your character yet."
L.PROGRESS_FMT     = "step %d/%d"
L.STEPS_FMT        = "%d steps"
L.LOOP_HINT        = "Circuit: starts over at the end."
L.MINIMAP_HINT     = "Left click: choose a guide. Right click: show/hide the guide. Drag to move."
L.DYN_EMPTY = "Nothing to do here right now."
L.CAT_professions = "Professions"
L.QUEST_FMT    = "quest #%d"

L.HELP = {
  "/freegor - show or hide the guide window",
  "/freegor menu - choose what to track (leveling, mounts, gold, reputation...)",
  "/freegor next | prev - move between steps",
  "/freegor step <n> - jump to a step",
  "/freegor arrow - show or hide the arrow",
  "/freegor auto - automatic quest accept/turn-in on or off",
  "/freegor unskip - show again the steps you skipped in generated guides",
  "/freegor minimap - show or hide the minimap button",
  "/freegor reset - reset the window position",
}
