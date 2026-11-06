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

-- Returns status, progressText.
-- status: "done", "todo", or "info" (not checkable: never blocks or completes a step).
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
  elseif t == "goto" then
    return arrived[goal] and "done" or "info"
  end
  return "info"
end

-- A step completes when all its checkable goals are done. A step whose only
-- checkable goal is a goto completes on arrival. A step with nothing checkable
-- (notes, talk) needs the player to press "Next".
local function hasCheckable(step)
  for _, goal in ipairs(step.goals) do
    local t = goal.type
    if t ~= "goto" and t ~= "talk" and t ~= "note" and not ((t == "kill" or t == "collect") and not goal.quest) then
      return true
    end
  end
  return false
end

local function firstGoto(step)
  for _, goal in ipairs(step.goals) do
    if goal.type == "goto" then return goal end
  end
end

function Engine:StepComplete(step)
  if hasCheckable(step) then
    for _, goal in ipairs(step.goals) do
      if goal.type ~= "goto" and self:GoalStatus(goal) == "todo" then return false end
    end
    return true
  end
  local g = firstGoto(step)
  if g then return arrived[g] == true end
  return false
end

function Engine:IsManualStep(step)
  return not hasCheckable(step) and not firstGoto(step)
end

function Engine:StepApplies(step)
  local class, race, faction = C.PlayerInfo()
  return Parser.StepApplies(step, class, race, faction)
end

-- Human-readable label for a goal (localized).
function ns.GoalText(goal)
  local function questName()
    return C.GetQuestTitle(goal.quest) or goal.title or L.QUEST_FMT:format(goal.quest)
  end
  local t = goal.type
  if t == "accept" then return L.GOAL_ACCEPT:format(questName())
  elseif t == "turnin" then return L.GOAL_TURNIN:format(questName())
  elseif t == "do" then return L.GOAL_DO:format(questName())
  elseif t == "kill" then return L.GOAL_KILL:format(goal.text)
  elseif t == "collect" then return L.GOAL_COLLECT:format(goal.text)
  elseif t == "talk" then return L.GOAL_TALK:format(goal.text)
  elseif t == "level" then return L.GOAL_LEVEL:format(goal.level)
  elseif t == "goto" then
    local zone = C.GetMapName(Engine:GoalMap(goal)) or goal.zone or ""
    return L.GOAL_GOTO:format(("%s %.1f, %.1f"):format(zone, goal.x * 100, goal.y * 100))
  end
  return goal.text or ""
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
    local label
    for _, g in ipairs(step and step.goals or {}) do
      if g.type == "talk" or g.type == "accept" or g.type == "turnin" or g.type == "kill" or g.type == "collect" then
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
  self:SetWaypointFromGoal(step and firstGoto(step))
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
  self:GoToStep(step or 1, true)
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

ns.On("INIT", function()
  for _, msg in ipairs(pendingErrors) do ns.Print("|cffff4040%s|r", msg) end
  wipe(pendingErrors)

  local saved = ns.cdb.guide
  if saved and ns.guides[saved] then
    Engine:LoadGuide(saved, ns.cdb.step)
  end
  C_Timer.NewTicker(0.5, checkArrival)
end)
