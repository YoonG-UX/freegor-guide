local _, ns = ...
local L = ns.L
local C = ns.Compat
local Parser = ns.Parser
local Freegor = ns.Freegor

local Engine = {}
ns.Engine = Engine

Engine.guide = nil      -- active parsed guide
Engine.stepIndex = 1
Engine.waypoint = nil   -- { mapID, x, y, title }

local pendingErrors = {}
local turnedIn = {}     -- quests turned in this session (flags can lag behind the event)
local arrived = {}      -- [goal] = true once the player reached a goto goal
local hold = false      -- true after the player moved back manually: no auto-advance

---------------------------------------------------------------------------
-- Guide registry
---------------------------------------------------------------------------

-- Register a guide from text. Usable by any addon: Freegor:RegisterGuide([[ ... ]])
function Freegor:RegisterGuide(text)
  local guide, err, line = Parser.Parse(text)
  if not guide then
    local title = text:match("guide%s+([^\n]+)") or "?"
    table.insert(pendingErrors, L.PARSE_ERROR_FMT:format(title, line or 0, err))
    return false
  end
  if not ns.guides[guide.title] then
    table.insert(ns.guideOrder, guide.title)
  end
  ns.guides[guide.title] = guide
  return true
end

function Freegor:GetGuides()
  local list = {}
  for _, title in ipairs(ns.guideOrder) do list[#list + 1] = ns.guides[title] end
  return list
end

---------------------------------------------------------------------------
-- Goal evaluation
---------------------------------------------------------------------------

local function questDone(q) return turnedIn[q] or C.IsQuestCompleted(q) end

-- Map ID a goto goal points to (explicit zone, else the guide zone, else the player's map).
function Engine:GoalMap(goal)
  if goal.zone then
    local id = C.ResolveMap(goal.zone)
    if id then return id end
  end
  local g = self.guide
  if g then
    for _, ref in ipairs(g.zone) do
      local id = C.ResolveMap(ref)
      if id then return id end
    end
  end
  return C.GetPlayerMap()
end

-- Actions observed in game. `actions[goal]` is set when an event matching an
-- action goal of the *current* step fires; `talked[npcID]` when the player
-- opens any dialog with that NPC this session.
local actions = {}
local talked = {}
Engine.actions, Engine.talked = actions, talked

local function lc(s) return s and s:lower() or nil end
local function textMatches(goal, name)
  if not name or name == "" then return false end
  name = name:lower()
  for _, t in ipairs({ lc(goal.text), lc(goal.fr) }) do
    if t and t ~= "" and (name == t or name:find(t, 1, true) or t:find(name, 1, true)) then return true end
  end
  return false
end

local PRIMARY = {
  accept = true, turnin = true, ["do"] = true, level = true,
  home = true, fpath = true, fly = true, hearth = true, train = true,
}
local function isPrimary(goal)
  local t = goal.type
  return PRIMARY[t] or ((t == "kill" or t == "collect") and goal.quest ~= nil)
end

-- Returns status, progressText.
-- status: "done", "todo", or "info" (does not decide completion).
function Engine:GoalStatus(goal)
  local t = goal.type
  if t == "accept" then
    return (C.IsOnQuest(goal.quest) or questDone(goal.quest)) and "done" or "todo"
  elseif t == "turnin" then
    return questDone(goal.quest) and "done" or "todo"
  elseif t == "do" or ((t == "kill" or t == "collect") and goal.quest) then
    if questDone(goal.quest) then return "done" end
    if not C.IsOnQuest(goal.quest) then return "todo" end
    if goal.objective then
      local o = C.GetObjectives(goal.quest)[goal.objective]
      if o then
        local prog = (o.numRequired and o.numRequired > 0)
          and ("%d/%d"):format(o.numFulfilled or 0, o.numRequired) or nil
        return o.finished and "done" or "todo", prog
      end
    end
    return C.IsQuestReady(goal.quest) and "done" or "todo"
  elseif t == "level" then
    return UnitLevel("player") >= goal.level and "done" or "todo"
  elseif t == "home" then
    return (actions[goal] or textMatches(goal, C.GetBindLocation())) and "done" or "todo"
  elseif t == "fpath" then
    if actions[goal] then return "done" end
    for name in pairs(ns.cdb.taxi or {}) do
      if textMatches(goal, name) then return "done" end
    end
    return "todo"
  elseif t == "fly" or t == "hearth" or t == "train" then
    return actions[goal] and "done" or "todo"
  elseif t == "talk" then
    return (goal.npc and talked[goal.npc]) and "done" or "info"
  elseif t == "goto" then
    return arrived[goal] and "done" or "info"
  end
  return "info"
end

local function hasPrimary(step)
  for _, goal in ipairs(step.goals) do
    if isPrimary(goal) then return true end
  end
  return false
end

local function firstGoto(step)
  for _, goal in ipairs(step.goals) do
    if goal.type == "goto" then return goal end
  end
end

local function talkGoals(step)
  local out = {}
  for _, goal in ipairs(step.goals) do
    if goal.type == "talk" and goal.npc then out[#out + 1] = goal end
  end
  return out
end

-- How a step completes, in order of precedence:
--   1. all "primary" goals done (quests, level, actions);
--   2. otherwise, talking to every NPC named with |n;
--   3. otherwise, arriving at the goto;
--   4. otherwise the player presses "Next" (manual step).
function Engine:StepKind(step)
  if hasPrimary(step) then return "primary" end
  if #talkGoals(step) > 0 then return "talk" end
  if firstGoto(step) then return "goto" end
  return "manual"
end

function Engine:StepComplete(step)
  local kind = self:StepKind(step)
  if kind == "primary" then
    for _, goal in ipairs(step.goals) do
      if isPrimary(goal) and self:GoalStatus(goal) ~= "done" then return false end
    end
    return true
  elseif kind == "talk" then
    for _, goal in ipairs(talkGoals(step)) do
      if not talked[goal.npc] then return false end
    end
    return true
  elseif kind == "goto" then
    return arrived[firstGoto(step)] == true
  end
  return false
end

function Engine:IsManualStep(step)
  return self:StepKind(step) == "manual"
end

-- A step can hold several NPCs standing close together, each introduced by
-- its own goto. The arrow points to the first one that still has an
-- unfinished quest goal.
function Engine:ActiveGoto(step)
  local groups, cur = {}, nil
  for _, g in ipairs(step.goals) do
    if g.type == "goto" then
      cur = { goto = g, goals = {} }
      groups[#groups + 1] = cur
    elseif cur then
      table.insert(cur.goals, g)
    end
  end
  for _, gr in ipairs(groups) do
    for _, g in ipairs(gr.goals) do
      if isPrimary(g) and self:GoalStatus(g) ~= "done" then return gr.goto end
    end
  end
  return groups[1] and groups[1].goto
end

-- Where to resume a guide: the first unfinished quest/action step, preceded by
-- the travel or talk steps that lead to it.
function Engine:ResumeIndex()
  local steps = self.guide.steps
  local j = #steps + 1
  for i, s in ipairs(steps) do
    if self:StepApplies(s) and self:StepKind(s) == "primary" and not self:StepComplete(s) then
      j = i
      break
    end
  end
  while j > 1 do
    local prev = steps[j - 1]
    if self:StepApplies(prev) and self:StepKind(prev) == "primary" then break end
    j = j - 1
  end
  return j
end

function Engine:StepApplies(step)
  local class, race, faction = C.PlayerInfo()
  return Parser.StepApplies(step, class, race, faction)
end

-- Human-readable label for a goal (localized).
local isFrench = GetLocale() == "frFR"

function ns.GoalText(goal)
  local fr = isFrench and goal.fr or nil
  local function questName()
    return C.GetQuestTitle(goal.quest) or fr or goal.title or L.QUEST_FMT:format(goal.quest)
  end
  local text = fr or goal.text
  local t = goal.type
  if t == "accept" then return L.GOAL_ACCEPT:format(questName())
  elseif t == "turnin" then return L.GOAL_TURNIN:format(questName())
  elseif t == "do" then return L.GOAL_DO:format(questName())
  elseif t == "kill" then return L.GOAL_KILL:format(text)
  elseif t == "collect" then return L.GOAL_COLLECT:format(text)
  elseif t == "talk" then return L.GOAL_TALK:format(text)
  elseif t == "home" then return L.GOAL_HOME:format(text)
  elseif t == "fpath" then return L.GOAL_FPATH:format(text)
  elseif t == "fly" then return L.GOAL_FLY:format(text)
  elseif t == "hearth" then return text ~= "" and L.GOAL_HEARTH_TO:format(text) or L.GOAL_HEARTH
  elseif t == "train" then return L.GOAL_TRAIN
  elseif t == "use" then return L.GOAL_USE:format(text)
  elseif t == "buy" then return L.GOAL_BUY:format(text)
  elseif t == "level" then return L.GOAL_LEVEL:format(goal.level)
  elseif t == "goto" then
    local zone = C.GetMapName(Engine:GoalMap(goal)) or goal.zone or ""
    return L.GOAL_GOTO:format(("%s %.1f, %.1f"):format(zone, goal.x * 100, goal.y * 100))
  end
  return text or ""
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------

function Engine:CurrentStep()
  return self.guide and self.guide.steps[self.stepIndex]
end

function Engine:SetWaypointFromGoal(goal)
  if not goal or goal.type ~= "goto" then
    self.waypoint = nil
  else
    local step = self:CurrentStep()
    local label, after = nil, false
    for _, g in ipairs(step and step.goals or {}) do
      if g == goal then
        after = true
      elseif after and g.type == "goto" then
        break
      elseif after and g.type ~= "note" then
        label = ns.GoalText(g)
        break
      end
    end
    self.waypoint = { mapID = self:GoalMap(goal), x = goal.x, y = goal.y, goal = goal, title = label }
  end
  ns.Fire("WAYPOINT", self.waypoint)
end

function Engine:GoToStep(index, manual)
  local g = self.guide
  if not g then return end
  index = math.max(1, math.min(index, #g.steps + 1)) -- #steps + 1 means "finished"
  self.stepIndex = index
  ns.cdb.step = index
  local step = self:CurrentStep()
  if step then
    for _, goal in ipairs(step.goals) do arrived[goal] = nil end
  end
  self.manualWaypoint = false
  self:SetWaypointFromGoal(step and self:ActiveGoto(step))
  ns.Fire("STEP_CHANGED", step, index)
  if not manual then self:Refresh() end
end

-- Next step that applies to this character and is not already complete.
function Engine:FindNext(from)
  local steps = self.guide.steps
  for i = from, #steps do
    local s = steps[i]
    if self:StepApplies(s) and not self:StepComplete(s) then return i end
  end
  return #steps + 1
end

function Engine:Next()
  if not self.guide then return end
  hold = false
  -- Pressing Next always moves at least one step, even on an incomplete step.
  local i = self.stepIndex + 1
  local steps = self.guide.steps
  while steps[i] and not self:StepApplies(steps[i]) do i = i + 1 end
  self:GoToStep(i, true)
end

function Engine:Prev()
  if not self.guide then return end
  hold = true
  local i = self.stepIndex - 1
  local steps = self.guide.steps
  while i > 1 and not self:StepApplies(steps[i]) do i = i - 1 end
  self:GoToStep(i, true)
end

function Engine:Jump(index)
  hold = true
  self:GoToStep(index, true)
end

function Engine:LoadGuide(title, step)
  local guide = ns.guides[title]
  if not guide then
    ns.Print(L.UNKNOWN_GUIDE, tostring(title))
    return false
  end
  self.guide = guide
  ns.cdb.guide = title
  hold = false
  ns.Fire("GUIDE_LOADED", guide)
  self:GoToStep(step or self:ResumeIndex(), true)
  self:Refresh()
  return true
end

-- Re-evaluate the current step; advance automatically when it is complete.
function Engine:Refresh()
  if not self.guide then return end
  local step = self:CurrentStep()
  if step and not hold then
    if not self:StepApplies(step) or self:StepComplete(step) then
      local nextIndex = self:FindNext(self.stepIndex)
      if nextIndex ~= self.stepIndex then
        if ns.db.sound ~= false and _G.PlaySound and _G.SOUNDKIT then
          pcall(_G.PlaySound, _G.SOUNDKIT.IG_QUEST_LIST_SELECT or 857)
        end
        self:GoToStep(nextIndex, true)
      end
    end
  end
  -- Move the arrow to the next NPC of a multi-NPC step.
  local cur = self:CurrentStep()
  if cur and not self.manualWaypoint then
    local g = self:ActiveGoto(cur)
    if g and not (self.waypoint and self.waypoint.goal == g) then self:SetWaypointFromGoal(g) end
  end
  ns.Fire("REFRESH")
end

-- Coalesce bursts of quest events into one refresh.
local refreshQueued = false
function Engine:QueueRefresh()
  if refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.2, function()
    refreshQueued = false
    Engine:Refresh()
  end)
end

---------------------------------------------------------------------------
-- Distance to waypoint (yards) and bearing relative to player facing.
---------------------------------------------------------------------------

function Engine:WaypointVector()
  local wp = self.waypoint
  if not wp or not wp.mapID then return nil end
  local pc, pn, pw = C.GetPlayerWorld()
  local tc, tn, tw = C.MapToWorld(wp.mapID, wp.x, wp.y)
  if not pc or not tc then return nil end
  if pc ~= tc then return nil, "continent" end
  local dn, dw = tn - pn, tw - pw
  local dist = math.sqrt(dn * dn + dw * dw)
  -- Bearing measured counter-clockwise from north, like GetPlayerFacing().
  local bearing = math.atan2(dw, dn)
  local facing = GetPlayerFacing and GetPlayerFacing()
  local rel = facing and (bearing - facing) or nil
  return dist, rel
end

local function checkArrival()
  local wp = Engine.waypoint
  if not (wp and wp.goal) or arrived[wp.goal] then return end
  local dist = Engine:WaypointVector()
  local radius = wp.goal.radius or ns.db.arrivalRadius or 12
  if dist and dist <= radius then
    arrived[wp.goal] = true
    Engine:Refresh()
  end
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

for _, ev in ipairs({
  "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_REMOVED", "UNIT_QUEST_LOG_CHANGED",
  "QUEST_WATCH_UPDATE", "PLAYER_LEVEL_UP", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA",
}) do
  ns.RegisterEvent(ev, function() Engine:QueueRefresh() end)
end

ns.RegisterEvent("QUEST_TURNED_IN", function(_, questID)
  if questID then turnedIn[questID] = true end
  Engine:QueueRefresh()
end)

-- Mark every goal of the given type in the current step as done.
local function markAction(goalType, predicate)
  local step = Engine:CurrentStep()
  if not step then return end
  local changed = false
  for _, goal in ipairs(step.goals) do
    if goal.type == goalType and not actions[goal] and (not predicate or predicate(goal)) then
      actions[goal] = true
      changed = true
    end
  end
  if changed then Engine:QueueRefresh() end
end
Engine.MarkAction = markAction

-- Talking to NPCs: any dialog window opened with an NPC counts.
local function onInteract()
  local id = C.GetInteractNpcID()
  if id and not talked[id] then
    talked[id] = true
    Engine:QueueRefresh()
  end
end
for _, ev in ipairs({
  "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
  "MERCHANT_SHOW", "BANKFRAME_OPENED",
}) do
  ns.RegisterEvent(ev, onInteract)
end

ns.RegisterEvent("TRAINER_SHOW", function()
  onInteract()
  markAction("train")
end)

ns.RegisterEvent("TAXIMAP_OPENED", function()
  onInteract()
  ns.cdb.taxi = ns.cdb.taxi or {}
  for _, name in ipairs(C.GetKnownTaxiNodes()) do ns.cdb.taxi[name:lower()] = true end
  markAction("fpath")
end)

ns.RegisterEvent("HEARTHSTONE_BOUND", function() markAction("home") end)

local HEARTHSTONE_SPELLS = { [8690] = true }
ns.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
  if unit == "player" and HEARTHSTONE_SPELLS[spellID] then markAction("hearth") end
end)

-- Taking a flight: checked on the arrival ticker (cheap) and on control loss.
local function checkTaxi()
  if UnitOnTaxi and UnitOnTaxi("player") then markAction("fly") end
end
ns.RegisterEvent("PLAYER_CONTROL_LOST", function() C_Timer.After(1, checkTaxi) end)

ns.On("INIT", function()
  for _, msg in ipairs(pendingErrors) do ns.Print("|cffff4040%s|r", msg) end
  wipe(pendingErrors)

  local saved = ns.cdb.guide
  if saved and ns.guides[saved] then
    Engine:LoadGuide(saved, ns.cdb.step)
  else
    -- First login with the addon: pick the guide for this race and level.
    local _, race, faction, level = C.PlayerInfo()
    for _, title in ipairs(ns.guideOrder) do
      local g = ns.guides[title]
      if (not g.faction or g.faction == faction) and Parser.GuideForRace(g, race)
        and (g.minLevel or 0) <= level and level < (g.maxLevel or 999) then
        Engine:LoadGuide(title)
        break
      end
    end
  end
  C_Timer.NewTicker(0.5, function()
    checkArrival()
    checkTaxi()
  end)
end)
