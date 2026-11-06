-- Offline tests: loads the addon with a stubbed WoW API and simulates play.
-- Run from the repository root:  lua5.1 tests/run.lua

local ADDON_DIR = "FreegorGuide/"
local failures, passed = 0, 0

local function check(cond, msg)
  if cond then passed = passed + 1 else failures = failures + 1; print("FAIL: " .. msg) end
end

---------------------------------------------------------------------------
-- WoW API stubs
---------------------------------------------------------------------------

local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }

local function newVec(x, y)
  return { x = x, y = y,
    GetXY = function(v) return v.x, v.y end,
    SetXY = function(v, a, b) v.x, v.y = a, b end }
end
CreateVector2D = newVec

local mockMeta
local function mock()
  local o = { _shown = false, _text = nil }
  return setmetatable(o, mockMeta)
end
local methods = {
  Show = function(o) o._shown = true end,
  Hide = function(o) o._shown = false end,
  SetShown = function(o, s) o._shown = s and true or false end,
  IsShown = function(o) return o._shown end,
  SetText = function(o, t) o._text = t end,
  GetText = function(o) return o._text end,
  IsTruncated = function() return false end,
  GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
  CreateTexture = function() return mock() end,
  CreateFontString = function() return mock() end,
  SetScript = function(o, name, fn) o["_" .. name] = fn end,
  RegisterEvent = function(o, ev) o._events = o._events or {}; o._events[ev] = true end,
}
mockMeta = { __index = function(_, k) return methods[k] or function() end end }

local eventFrame
function CreateFrame()
  local f = mock()
  if not eventFrame then eventFrame = f end -- Init.lua creates the event frame first
  return f
end
UIParent, GameTooltip = mock(), mock()
UISpecialFrames, SlashCmdList = {}, {}
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function geterrorhandler() return function(e) error(e) end end
function GetLocale() return "frFR" end
function PlaySound() end
SOUNDKIT = {}

local timers = {}
C_Timer = {
  After = function(_, fn) timers[#timers + 1] = fn end,
  NewTicker = function(_, fn) C_Timer.tick = fn end,
}
local function flushTimers()
  while #timers > 0 do table.remove(timers, 1)() end
end

-- Player state
local player = { class = "WARRIOR", race = "Human", faction = "Alliance", level = 1,
                 map = 1429, x = 0.5, y = 0.5, facing = 0 }
function UnitClass() return "Guerrier", player.class end
function UnitRace() return "Humain", player.race end
function UnitFactionGroup() return player.faction end
function UnitLevel() return player.level end
function GetPlayerFacing() return player.facing end

-- Quest state: log[id] = { objectives }, done[id] = true
local log, done = {}, {}
C_QuestLog = {
  IsQuestFlaggedCompleted = function(id) return done[id] or false end,
  IsOnQuest = function(id) return log[id] ~= nil end,
  GetQuestObjectives = function(id) return log[id] end,
  IsComplete = function(id)
    local objs = log[id]
    if not objs then return false end
    for _, o in ipairs(objs) do if not o.finished then return false end end
    return true
  end,
  GetTitleForQuestID = function() return nil end,
}

-- One zone, 3000 x 2000 yards.
C_Map = {
  GetMapInfo = function(id) if id == 1429 then return { name = "Forêt d'Elwynn", mapType = 3 } end end,
  GetBestMapForUnit = function() return player.map end,
  GetPlayerMapPosition = function() return newVec(player.x, player.y) end,
  GetWorldPosFromMapPos = function(id, v)
    if id ~= 1429 then return nil end
    return 0, newVec((1 - v.y) * 2000, (1 - v.x) * 3000)
  end,
}

local function fire(event, ...)
  eventFrame._OnEvent(eventFrame, event, ...)
  flushTimers()
end

---------------------------------------------------------------------------
-- Load the addon in TOC order
---------------------------------------------------------------------------

local ns = {}
local tocFiles = 0
for line in io.lines(ADDON_DIR .. "FreegorGuide.toc") do
  if line ~= "" and not line:match("^##") then
    local path = ADDON_DIR .. line:gsub("\\", "/")
    local chunk, err = loadfile(path)
    check(chunk ~= nil, "TOC entry loads: " .. path .. " " .. tostring(err))
    if chunk then chunk("FreegorGuide", ns); tocFiles = tocFiles + 1 end
  end
end
check(tocFiles >= 10, "all TOC files loaded")

fire("ADDON_LOADED", "FreegorGuide")
fire("PLAYER_LOGIN")

for _, m in ipairs(printed) do
  check(not m:find("ff4040"), "guide parse error printed: " .. m)
end
check(#Freegor:GetGuides() >= 1, "example guide registered")
check(ns.L.NEXT == "Étape suivante", "French locale active")

---------------------------------------------------------------------------
-- Parser
---------------------------------------------------------------------------

local P = ns.Parser
local g, err, line = P.Parse("guide T\nstep\n  bogus 1\n")
check(g == nil and line == 3 and err:find("bogus"), "unknown command reported with line")
g, err = P.Parse("step\n accept 1\n")
check(g == nil, "header required before steps: " .. tostring(err))
g = P.Parse("guide T\nzone 1429, Elwynn Forest\nstep\n goto Westfall 52.5,47.9 |r 5\n kill 3 Boars |q 9/2\n")
local s = g and g.steps[1]
check(s and s.goals[1].zone == "Westfall" and math.abs(s.goals[1].x - 0.525) < 1e-9 and s.goals[1].radius == 5, "goto with zone and radius")
check(s and s.goals[2].quest == 9 and s.goals[2].objective == 2 and s.goals[2].text == "3 Boars", "kill with |q")
check(g and g.zone[2] == "Elwynn Forest", "zone list")

check(P.StepApplies({ only = { "Warrior", "Paladin" } }, "WARRIOR", "Human", "Alliance"), "only class match")
check(not P.StepApplies({ only = { "Mage" } }, "WARRIOR", "Human", "Alliance"), "only class mismatch")
check(not P.StepApplies({ only = { "!Human" } }, "WARRIOR", "Human", "Alliance"), "only negation")
check(P.StepApplies({ only = { "Night Elf" } }, "DRUID", "NightElf", "Alliance"), "race with spaces")

---------------------------------------------------------------------------
-- Engine simulation on the example guide
---------------------------------------------------------------------------

local E = ns.Engine
check(E:LoadGuide("Northshire Valley (1-6)"), "load example guide")
check(E.stepIndex == 1, "starts at step 1")
check(E.waypoint and E.waypoint.mapID == 1429 and math.abs(E.waypoint.x - 0.482) < 1e-9, "waypoint from goto, zone resolved by ID")

local function accept(id, nObj)
  local objs = {}
  for i = 1, nObj or 0 do objs[i] = { finished = false, numFulfilled = 0, numRequired = 10 } end
  log[id] = objs
  fire("QUEST_ACCEPTED", id)
end
local function turnin(id) log[id] = nil; done[id] = true; fire("QUEST_TURNED_IN", id) end
local function progress(id, obj, n, need)
  log[id][obj] = { finished = n >= need, numFulfilled = n, numRequired = need }
  fire("QUEST_LOG_UPDATE")
end

accept(783)
check(E.stepIndex == 2, "accepting 783 advances to step 2 (got " .. E.stepIndex .. ")")
turnin(783)
check(E.stepIndex == 2, "step 2 waits for second goal")
accept(7, 1)
check(E.stepIndex == 3, "step 2 done -> 3")
accept(5261); accept(18, 1)
check(E.stepIndex == 4, "step 3 done -> 4")
turnin(5261); accept(33, 1)
check(E.stepIndex == 5, "step 4 done -> 5")

progress(7, 1, 4, 10)
local st, prog = E:GoalStatus(E:CurrentStep().goals[2])
check(st == "todo" and prog == "4/10", "objective progress text")
progress(7, 1, 10, 10)
check(E.stepIndex == 5, "kill done but wolf meat missing")
progress(33, 1, 8, 8)
check(E.stepIndex == 6, "both objectives done -> 6")

-- Going back holds position even though the step is complete.
E:Prev()
fire("QUEST_LOG_UPDATE")
check(E.stepIndex == 5, "prev holds on a completed step")
E:Next()
check(E.stepIndex == 6, "next resumes")

-- Already-completed steps are skipped when jumping forward.
turnin(33)
check(E.stepIndex == 7, "turnin 33 -> 7")

-- Arrival on a goto-only step.
local g2 = P.Parse("guide Walk\nzone 1429\nstep\n goto 50,40\n talk Someone\nstep\n note end\n")
ns.guides["Walk"] = g2
E:LoadGuide("Walk")
player.x, player.y = 0.5, 0.5
local d, rel = E:WaypointVector()
check(d and math.abs(d - 200) < 1e-6, "distance 200 yd (got " .. tostring(d) .. ")")
check(rel and math.abs(rel) < 1e-6, "target due north, facing north -> rel 0")
player.facing = math.pi / 2 -- facing west: target should be to the right (negative rotation)
d, rel = E:WaypointVector()
check(rel and math.abs(rel + math.pi / 2) < 1e-6, "facing west -> rel -pi/2")
C_Timer.tick()
check(E.stepIndex == 1, "no arrival while far")
player.y = 0.403
C_Timer.tick()
check(E.stepIndex == 2, "arrival advances goto-only step")
check(E:IsManualStep(E:CurrentStep()), "note-only step is manual")

-- Class-only steps are skipped.
local g3 = P.Parse("guide Cls\nstep\n only Mage\n level 99\nstep\n level 1\nstep\n level 99\n")
ns.guides["Cls"] = g3
E:LoadGuide("Cls")
check(E.stepIndex == 3, "skips non-matching class step and completed level step (got " .. E.stepIndex .. ")")

-- Slash command smoke test
SlashCmdList.FREEGOR("help")
SlashCmdList.FREEGOR("step 2")
check(E.stepIndex == 2, "/freegor step 2")

print(("%d passed, %d failed"):format(passed, failures))
os.exit(failures == 0 and 0 or 1)
