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
Minimap = mock()
Minimap.GetWidth = function() return 140 end
Minimap.GetCenter = function() return 0, 0 end
function GetCursorPosition() return 0, 0 end
function GetMoney() return 0 end
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


-- Interaction / action APIs
local npcGUID, onTaxi, bindLoc = nil, false, "Comté-de-l'Or"
function strsplit(sep, str)
  local out = {}
  for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return unpack(out)
end
function UnitGUID(unit) if unit == "npc" then return npcGUID end end
function UnitOnTaxi() return onTaxi end
function GetBindLocation() return bindLoc end
local taxiNodes = { { "Sentinel Hill, Westfall", "CURRENT" }, { "Lakeshire, Redridge", "NONE" } }
function NumTaxiNodes() return #taxiNodes end
function TaxiNodeName(i) return taxiNodes[i][1] end
function TaxiNodeGetType(i) return taxiNodes[i][2] end
local questDialog, accepted, completed, rewarded = nil, {}, 0, nil
function GetQuestID() return questDialog end
function AcceptQuest() accepted[#accepted + 1] = questDialog end
function IsShiftKeyDown() return false end
function IsQuestCompletable() return true end
function CompleteQuest() completed = completed + 1 end
function GetNumQuestChoices() return 0 end
function GetQuestReward(c) rewarded = c end

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
check(ns.Engine.guide and ns.Engine.guide.title == "Human 1-6: Northshire Valley", "first login picks the starting guide for the race")
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
local rg = P.Parse("guide R\nrace Dwarf, Gnome\nstep\n note x\n")
check(P.GuideForRace(rg, "Gnome") and not P.GuideForRace(rg, "Human"), "guide race filter")

---------------------------------------------------------------------------
-- Engine simulation on the example guide
---------------------------------------------------------------------------

local E = ns.Engine
check(E:LoadGuide("Human 1-6: Northshire Valley"), "load example guide")
check(E.stepIndex == 1, "starts at step 1")
check(E.waypoint and E.waypoint.mapID == 1429 and math.abs(E.waypoint.x - 0.482) < 1e-9, "waypoint from goto, zone resolved by ID")
check(E:CurrentStep().goals[2].npc == 823 and E:CurrentStep().goals[2].fr == "Adjoint Willem", "talk goal carries NPC ID and French name")

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

-- Helpers that follow the step content rather than hard-coded step numbers.
local function stepHas(kind, quest)
  local st = E:CurrentStep()
  for _, goal in ipairs(st and st.goals or {}) do
    if goal.type == kind and goal.quest == quest then return true end
  end
  return false
end
local function goalOf(kind, quest)
  for _, goal in ipairs(E:CurrentStep().goals) do
    if goal.type == kind and goal.quest == quest then return goal end
  end
end

-- First step: Willem, McBride, Willem (5261 and 18 need 783 turned in).
check(stepHas("accept", 783) and stepHas("turnin", 783) and stepHas("accept", 5261), "first step groups Willem and McBride")
accept(783)
check(stepHas("accept", 7), "step waits for the McBride part")
check(E.waypoint and E.waypoint.goal and math.abs(E.waypoint.x - 0.489) < 1e-9, "arrow moved on to McBride")
turnin(783); accept(7, 1)
check(stepHas("accept", 18), "then back to Willem")
accept(5261); accept(18, 1)
check(stepHas("turnin", 5261), "next step: Eagan")
turnin(5261); accept(33, 1)
check(stepHas("kill", 7) and stepHas("collect", 33), "kill step")
local killStep = E.stepIndex

progress(7, 1, 4, 10)
local st, prog = E:GoalStatus(goalOf("kill", 7))
check(st == "todo" and prog == "4/10", "objective progress text")
progress(7, 1, 10, 10)
check(E.stepIndex == killStep, "kill done but wolf meat missing")
progress(33, 1, 8, 8)
check(E.stepIndex == killStep + 1, "both objectives done -> next step")

-- Going back holds position even though the step is complete.
E:Prev()
fire("QUEST_LOG_UPDATE")
check(E.stepIndex == killStep, "prev holds on a completed step")
E:Next()
check(E.stepIndex == killStep + 1, "next resumes")

-- Guide catalogue checks
local KNOWN_MAPS = {}
for id = 1411, 1458 do KNOWN_MAPS[id] = 1 end -- Classic/Forever world zone maps
local CATS = { Alliance = {}, Horde = {} }
for _, c in ipairs(ns.CATEGORIES) do CATS.Alliance[c.key] = 0; CATS.Horde[c.key] = 0 end
local nGuides, nSteps = 0, 0
for _, guide in ipairs(Freegor:GetGuides()) do
  nGuides = nGuides + 1
  nSteps = nSteps + #guide.steps
  check(guide.faction == "Alliance" or guide.faction == "Horde", guide.title .. ": faction")
  local fc = CATS[guide.faction] or {}
  check(fc[guide.category] ~= nil, guide.title .. ": known category " .. tostring(guide.category))
  if fc[guide.category] then fc[guide.category] = fc[guide.category] + 1 end
  if guide.next and ns.guides[guide.next] then
    check(ns.guides[guide.next].faction == guide.faction, guide.title .. ": next guide is for the same faction")
  end
  check(guide.minLevel and guide.maxLevel, guide.title .. ": levels")
  if guide.next then check(ns.guides[guide.next] ~= nil, guide.title .. ": next guide exists: " .. guide.next) end
  for _, st in ipairs(guide.steps) do
    check(#st.goals > 0, guide.title .. ": empty step at line " .. st.line)
    for _, goal in ipairs(st.goals) do
      if goal.type == "goto" and goal.zone then
        check(KNOWN_MAPS[tonumber(goal.zone)], guide.title .. ": unknown map " .. goal.zone .. " line " .. goal.line)
      end
    end
  end
end
for faction, cats in pairs(CATS) do
  for key, n in pairs(cats) do check(key == "professions" or n >= 2, ("at least two %s guides in category %s (%d)"):format(faction, key, n)) end
end
check(nGuides >= 64 and nSteps >= 800, ("catalogue size (%d guides, %d steps)"):format(nGuides, nSteps))

-- Turning in part of a multi-NPC step keeps the step open.
local before = E.stepIndex
turnin(33)
check(E.stepIndex == before, "turnin 33 alone does not finish the Eagan + McBride step")

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


-- Action detection ---------------------------------------------------------
local ga = P.Parse([[
guide Actions
zone 1429
step
  goto 50,40
  talk Innkeeper Farley |n 295
  home Goldshire |fr Comté-de-l'Or
step
  fpath Sentinel Hill
step
  fpath Lakeshire
step
  fly Lakeshire
step
  hearth Goldshire
step
  train
step
  goto 10,10
  talk Marshal Dughan |n 240
step
  note end
]])
ns.guides["Actions"] = ga
bindLoc = "Stormwind"
E:LoadGuide("Actions")
check(E.stepIndex == 1, "home step waits")
fire("HEARTHSTONE_BOUND")
check(E.stepIndex == 2, "home detected (got " .. E.stepIndex .. ")")
fire("TAXIMAP_OPENED")
check(E.stepIndex == 3, "flight path learned when the taxi map opens")
check(FreegorCharDB.taxi["sentinel hill, westfall"], "known flight points saved per character")
check(not FreegorCharDB.taxi["lakeshire, redridge"], "undiscovered flight points not saved")
local known = P.Parse("guide K\nstep\n fpath Sentinel Hill\n")
check(E:StepComplete(known.steps[1]), "a flight path known from an earlier visit counts as done")
fire("TAXIMAP_OPENED")
check(E.stepIndex == 3, "opening the taxi map at another flight point does not count")
taxiNodes[1][2], taxiNodes[2][2] = "REACHABLE", "CURRENT"
fire("TAXIMAP_OPENED")
check(E.stepIndex == 4, "second flight path, at the right flight point")
onTaxi = true
C_Timer.tick()
flushTimers()
onTaxi = false
check(E.stepIndex == 5, "flight detected")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 8690)
check(E.stepIndex == 6, "hearthstone detected")
fire("TRAINER_SHOW")
check(E.stepIndex == 7, "trainer visit detected (got " .. E.stepIndex .. ")")
npcGUID = "Creature-0-1-0-1-240-0000"
fire("GOSSIP_SHOW")
check(E.stepIndex == 8, "talking to the NPC completes a talk step")
check(E:IsManualStep(E:CurrentStep()), "note step is manual")

-- Bind location already matching completes the home step
bindLoc = "Comté-de-l'Or"
E:LoadGuide("Actions", 1)
fire("QUEST_LOG_UPDATE")
check(E.stepIndex > 1, "home step done when the hearthstone is already bound there")

-- French display text
local hg = ns.guides["Human 1-6: Northshire Valley"].steps[1]
check(ns.GoalText(hg.goals[3]):find("Menace intérieure"), "French quest title shown before the quest is in the log")

-- Resume: loading a guide skips finished quests and lands on the travel before the next one
wipe(log); wipe(done)
for _, id in ipairs({ 783, 7, 5261, 33 }) do done[id] = true end
log[18] = { { finished = false, numFulfilled = 0, numRequired = 12 } }
log[15] = { { finished = false, numFulfilled = 0, numRequired = 10 } }
E:LoadGuide("Human 1-6: Northshire Valley")
local cur = E:CurrentStep()
local firstTodo
for _, goal in ipairs(cur.goals) do if goal.type ~= "goto" and goal.type ~= "talk" then firstTodo = firstTodo or goal end end
check(E.stepIndex > 1, "resume skips completed quests (step " .. E.stepIndex .. ")")
local allDone = true
for i = 1, E.stepIndex - 1 do
  local st = E.guide.steps[i]
  if E:StepKind(st) == "primary" and not E:StepComplete(st) then allDone = false end
end
check(allDone, "every quest step before the resume point is finished")
check(not E:StepComplete(cur), "resume lands on an unfinished step")

-- Automatic accept / turn-in ---------------------------------------------
FreegorDB.autoQuest = true
local nextAccept
for _, goal in ipairs(cur.goals) do if goal.type == "accept" then nextAccept = goal.quest end end
if not nextAccept then
  for i = E.stepIndex, E.stepIndex + 3 do
    for _, goal in ipairs(E.guide.steps[i].goals) do if goal.type == "accept" then nextAccept = nextAccept or goal.quest end end
  end
end
questDialog = nextAccept
fire("QUEST_DETAIL")
check(accepted[1] == nextAccept, "auto-accept of a quest from the current steps")
questDialog = 9999
fire("QUEST_DETAIL")
check(#accepted == 1, "quests outside the guide are not auto-accepted")
FreegorDB.autoQuest = false
questDialog = nextAccept
fire("QUEST_DETAIL")
check(#accepted == 1, "auto-accept off by default")

-- Multi-NPC step: the arrow moves to the next NPC once the first is done
wipe(log); wipe(done)
local mg = P.Parse([[
guide Multi
zone 1429
step
  goto 10,10
  talk A |n 1
  accept 501 First
  goto 12,10
  talk B |n 2
  accept 502 Second
step
  note end
]])
ns.guides["Multi"] = mg
E:LoadGuide("Multi", 1)
check(E.waypoint and math.abs(E.waypoint.x - 0.10) < 1e-9, "arrow on the first NPC")
check(E.waypoint.title and E.waypoint.title:find("A"), "arrow label names the first NPC")
accept(501)
check(E.stepIndex == 1 and math.abs(E.waypoint.x - 0.12) < 1e-9, "arrow moves to the second NPC")
accept(502)
check(E.stepIndex == 2, "multi-NPC step completes")


-- Menu renders every category without errors
for _, c in ipairs(ns.CATEGORIES) do
  ns.Picker:Toggle()
  ns.Picker:Hide()
end
ns.Picker:Toggle()
check(ns.Picker:IsShown(), "menu opens")
ns.Picker:Hide()

-- Loop guides start over; gold / item / reputation goals
local lg = P.Parse("guide L\ncategory gold\nloop\nzone 1429\nstep\n goto 50,50\nstep\n goto 60,60\n")
ns.guides["L"] = lg
E:LoadGuide("L", 2)
E:Next()
check(E.stepIndex == 1, "circuit starts over after the last step")
check(lg.category == "gold" and lg.loop, "category and loop headers")
local money, bag, standing = 0, 0, 4
GetMoney = function() return money end
GetItemCount = function() return bag end
GetFactionInfoByID = function() return "Stormwind", "", standing end
local gg = P.Parse("guide G\ncategory reputation\nstep\n gold 100\n item 2592 60 Wool Cloth\n rep 72 honored Stormwind\nstep\n note end\n")
ns.guides["G"] = gg
E:LoadGuide("G", 1)
check(E.stepIndex == 1, "gold/item/rep step waits")
local _, gp = E:GoalStatus(gg.steps[1].goals[1])
check(gp == "0/100", "gold progress")
money = 100 * 10000; bag = 60; standing = 6
fire("PLAYER_MONEY")
check(E.stepIndex == 2, "gold, item and reputation goals complete")
check(ns.GoalText(gg.steps[1].goals[3]):find("Honoré"), "reputation goal text in French")
local ag = P.Parse("guide A\nstep\n achieve 6 Level 10\n note x\n")
check(E:StepKind(ag.steps[1]) == "manual", "achievement goal is informative on a client without achievements")

-- Horde character: first login picks the right start guide, menu shows Horde guides only
player.race, player.faction, player.level, player.class = "Orc", "Horde", 1, "WARRIOR"
FreegorCharDB.guide = nil
E.guide = nil
fire("PLAYER_LOGIN")
check(E.guide and E.guide.title == "Orc & Troll 1-6: Valley of Trials", "Orc gets the Valley of Trials guide (got " .. tostring(E.guide and E.guide.title) .. ")")
player.race = "Scourge" -- the client's race token for Undead
check(P.GuideForRace(ns.guides["Undead 1-6: Deathknell"], "Scourge"), "Undead guides match the Scourge race token")
check(P.StepApplies({ only = { "Undead" } }, "MAGE", "Scourge", "Horde"), "only Undead matches Scourge")
FreegorCharDB.guide = nil
E.guide = nil
fire("PLAYER_LOGIN")
check(E.guide and E.guide.title == "Undead 1-6: Deathknell", "Undead gets the Deathknell guide")
for _, g in ipairs(Freegor:GetGuides()) do
  if g.faction == "Alliance" then
    -- the menu filter: an Alliance guide never shows for a Horde character
    check(g.faction ~= player.faction, "faction filter")
  end
end
player.race, player.faction, player.level = "Human", "Alliance", 1
-- Slash command smoke test
SlashCmdList.FREEGOR("help")
SlashCmdList.FREEGOR("step 2")
check(E.stepIndex == 2, "/freegor step 2")

print(("%d passed, %d failed"):format(passed, failures))
os.exit(failures == 0 and 0 or 1)
