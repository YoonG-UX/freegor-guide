-- Offline tests for FreegorGuideRetail: loads the Retail add-on with a stubbed
-- Retail API (Mount Journal, professions, Encounter Journal, achievements).
-- Run from the repository root:  lua5.1 tests/run_retail.lua

local ADDON_DIR = "FreegorGuideRetail/"
local failures, passed = 0, 0
local function check(cond, msg)
  if cond then passed = passed + 1 else failures = failures + 1; print("FAIL: " .. msg) end
end

---------------------------------------------------------------------------
-- Generic stubs (frames, timers, chat)
---------------------------------------------------------------------------

local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end }

local function newVec(x, y)
  return { x = x, y = y, GetXY = function(v) return v.x, v.y end, SetXY = function(v, a, b) v.x, v.y = a, b end }
end
CreateVector2D = newVec

local mockMeta
local function mock() return setmetatable({ _shown = false }, mockMeta) end
local methods = {
  Show = function(o) o._shown = true end, Hide = function(o) o._shown = false end,
  SetShown = function(o, s) o._shown = s and true or false end, IsShown = function(o) return o._shown end,
  SetText = function(o, t) o._text = t end, GetText = function(o) return o._text end,
  IsTruncated = function() return false end,
  GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
  CreateTexture = function() return mock() end, CreateFontString = function() return mock() end,
  SetScript = function(o, name, fn) o["_" .. name] = fn end,
}
mockMeta = { __index = function(_, k) return methods[k] or function() end end }
local eventFrame
function CreateFrame()
  local f = mock()
  if not eventFrame then eventFrame = f end
  return f
end
UIParent, GameTooltip, Minimap = mock(), mock(), mock()
Minimap.GetWidth = function() return 140 end
Minimap.GetCenter = function() return 0, 0 end
function GetCursorPosition() return 0, 0 end
UISpecialFrames, SlashCmdList, SOUNDKIT = {}, {}, {}
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function geterrorhandler() return function(e) error(e) end end
function GetLocale() return "frFR" end
function PlaySound() end
function GetMoney() return 0 end
function GetTime() return 0 end
function IsShiftKeyDown() return false end
function strsplit(sep, str)
  local out = {}
  for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
  return unpack(out)
end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) C_Timer.tick = fn end }
local function flush() while #timers > 0 do table.remove(timers, 1)() end end

function UnitClass() return "Guerrier", "WARRIOR" end
function UnitRace() return "Humain", "Human" end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 80 end
function GetPlayerFacing() return 0 end
local npcGUID = nil
summoned, linked = nil, nil
function ChatEdit_InsertLink(l) linked = l end
local secret = false
function UnitGUID() return npcGUID end
function issecretvalue() return secret end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, IsOnQuest = function() return false end,
  GetQuestObjectives = function() return {} end, IsComplete = function() return false end }

-- Maps: one zone with a dungeon entrance
C_Map = {
  GetMapInfo = function(id) if id == 2248 then return { name = "Île de Dorn", mapType = 3 } end end,
  GetBestMapForUnit = function() return 2248 end,
  GetPlayerMapPosition = function() return newVec(0.5, 0.5) end,
  GetWorldPosFromMapPos = function(id, v) return 0, newVec((1 - v.y) * 2000, (1 - v.x) * 3000) end,
}
C_EncounterJournal = {
  GetDungeonEntrancesForMap = function(id)
    if id == 2248 then return { { journalInstanceID = 100, position = newVec(0.40, 0.55), name = "Vieux donjon" } } end
    return {}
  end,
}
local tier = 1
function EJ_GetNumTiers() return 2 end
function EJ_GetCurrentTier() return tier end
function EJ_SelectTier(t) tier = t end
function EJ_GetInstanceByIndex(i, raid)
  if tier == 1 and not raid and i == 1 then return 100, "Vieux donjon" end
  if tier == 2 and raid and i == 1 then return 200, "Raid récent" end
end
function EJ_GetInstanceInfo(id) return ({ [100] = "Vieux donjon", [200] = "Raid récent" })[id] end

-- Saved instances
local saved = {}
function GetNumSavedInstances() return #saved end
function GetSavedInstanceInfo(i)
  local s = saved[i]
  return s.name, 1, 3600, 1, true, false, 0, false, 5, "Normal", #s.bosses
end
function GetSavedInstanceEncounterInfo(i, e)
  local b = saved[i].bosses[e]
  return b.name, 0, b.killed
end
function RequestRaidInfo() end

-- Mount Journal
local mounts = {
  [1] = { name = "Drake du vieux donjon", source = 1, collected = false,
          text = "|cFFFFD200Butin :|r Seigneur Ancien|n|cFFFFD200Zone :|r Vieux donjon" },
  [2] = { name = "Bélier de vendeur", source = 3, collected = false,
          text = "|cFFFFD200Vendeur :|r Marchand|n|cFFFFD200Coût :|r 500|TInterface\\MoneyFrame\\UI-GoldIcon:0|t" },
  [3] = { name = "Proto-drake de haut fait", source = 6, collected = false, text = "Haut fait : Gloire" },
  [4] = { name = "Monture déjà obtenue", source = 1, collected = true, text = "Butin : X" },
  [5] = { name = "Monture de la Horde", source = 3, collected = false, factionSpecific = true, faction = 0, text = "Vendeur" },
  [6] = { name = "Serpent des nuages", source = 2, collected = false, text = "Quête : Le serpent" },
}
C_MountJournal = {
  GetMountIDs = function() local t = {} for id in pairs(mounts) do t[#t + 1] = id end table.sort(t) return t end,
  GetMountInfoByID = function(id)
    local m = mounts[id]
    return m.name, 1000 + id, 1, false, true, m.source, false, m.factionSpecific or false, m.faction, false, m.collected, id
  end,
  GetMountInfoExtraByID = function(id) return 1, "desc", mounts[id].text end,
  GetMountFromItem = function(item) if item == 9000 then return 3 end end,
  GetMountLink = function(spell) return "[mount:" .. spell .. "]" end,
  SummonByID = function(id) summoned = id end,
}

-- Achievements
local criteria = { { "Battre A", true }, { "Battre B", true }, { "Battre C", false }, { "Battre D", false } }
function GetCategoryList() return { 1 } end
function GetCategoryNumAchievements() return 2 end
function GetAchievementInfo(a, b)
  local id = b and ({ 500, 501 })[b] or a
  if id == 500 then
    return 500, "Gloire", 10, false, nil, nil, nil, "desc", 0, 1, "Récompense : Proto-drake de haut fait", false, false, nil, false
  elseif id == 501 then
    return 501, "Explorateur", 10, false, nil, nil, nil, "desc", 0, 1, "", false, false, nil, false
  end
end
function GetAchievementNumCriteria(id) return id == 500 and #criteria or 1 end
function GetAchievementCriteriaInfo(id, i)
  if id == 500 then return criteria[i][1], 0, criteria[i][2], 0, 1 end
  return "Explorer", 0, false, 3, 10
end
C_AchievementInfo = { GetRewardItemID = function(id) if id == 500 then return 9000 end end }

-- Items
local bag = { [3000] = 10, [3001] = 0 }
C_Item = {
  GetItemCount = function(id) return bag[id] or 0 end,
  GetItemNameByID = function(id) return ({ [3000] = "Herbe", [3001] = "Fiole" })[id] end,
}
C_CurrencyInfo = { GetCurrencyInfo = function() return { name = "Écus", quantity = 0 } end }

-- Professions
local child = { professionID = 2871, professionName = "Alchimie de Khaz Algar", skillLevel = 10, maxSkillLevel = 100 }
local recipeInfo = {
  [11] = { name = "Potion simple", learned = true, relativeDifficulty = 0, numSkillUps = 1, canSkillUp = true },
  [12] = { name = "Élixir coûteux", learned = true, relativeDifficulty = 0, numSkillUps = 1, canSkillUp = true },
  [13] = { name = "Flacon vert", learned = true, relativeDifficulty = 2, numSkillUps = 1, canSkillUp = true },
  [14] = { name = "Recette à apprendre", learned = false, relativeDifficulty = 0, numSkillUps = 1, canSkillUp = true },
  [15] = { name = "Nouvelle découverte", learned = true, relativeDifficulty = 3, numSkillUps = 1, canSkillUp = false, firstCraft = true },
}
local schematics = {
  [11] = { { item = 3000, qty = 2 } },
  [12] = { { item = 3000, qty = 5 }, { item = 3001, qty = 3 } },
  [13] = { { item = 3000, qty = 1 } },
  [15] = { { item = 3000, qty = 1 } },
}
local ready = false
local opened = nil
C_TradeSkillUI = {
  IsTradeSkillReady = function() return ready end,
  GetChildProfessionInfo = function() return child end,
  GetBaseProfessionInfo = function() return { professionID = 171, professionName = "Alchimie" } end,
  GetAllRecipeIDs = function() return { 11, 12, 13, 14, 15 } end,
  GetRecipeInfo = function(id) return recipeInfo[id] end,
  IsRecipeInSkillLine = function() return true end,
  GetCraftableCount = function(id) return id == 11 and 5 or 0 end,
  GetRecipeSchematic = function(id)
    local slots = {}
    for _, r in ipairs(schematics[id] or {}) do
      slots[#slots + 1] = { reagents = { { itemID = r.item } }, quantityRequired = r.qty, reagentType = 1, required = true }
    end
    return { reagentSlotSchematics = slots }
  end,
  OpenRecipe = function(id) opened = id end,
}
function GetProfessions() return 1, nil, nil, nil, nil end
function GetProfessionInfo(i) return "Alchimie", 0, 10, 100, 0, 0, 171 end

local function fire(event, ...)
  eventFrame._OnEvent(eventFrame, event, ...)
  flush()
end

---------------------------------------------------------------------------
-- Load the add-on in TOC order
---------------------------------------------------------------------------

local ns = {}
for line in io.lines(ADDON_DIR .. "FreegorGuideRetail.toc") do
  if line ~= "" and not line:match("^#") then
    local path = ADDON_DIR .. line:gsub("\\", "/")
    local chunk, err = loadfile(path)
    check(chunk ~= nil, "TOC entry loads: " .. path .. " " .. tostring(err))
    if chunk then chunk("FreegorGuideRetail", ns) end
  end
end
fire("ADDON_LOADED", "FreegorGuideRetail")
fire("PLAYER_LOGIN")
for _, m in ipairs(printed) do check(not m:find("ff4040"), "error printed: " .. m) end

local E, L = ns.Engine, ns.L
local function titles(cat)
  local t = {}
  for _, g in ipairs(Freegor:GetGuides()) do if g.category == cat then t[#t + 1] = g.title end end
  return t
end
check(#titles("professions") == 1, "one profession guide per profession")
check(#titles("mounts") == 5, "five mount guides (with the tracked list)")
check(#titles("achievements") == 1, "achievement guide")
check(#titles("leveling") == 0, "no leveling guide on Retail")
ns.Picker:Toggle()
check(ns.Picker:IsShown(), "menu opens")
ns.Picker:Hide()

local function stepGoals(kind)
  local out = {}
  for _, g in ipairs(E:CurrentStep().goals) do if g.type == kind then out[#out + 1] = g end end
  return out
end

---------------------------------------------------------------------------
-- Profession guide
---------------------------------------------------------------------------

local prof = L.PROF_TITLE:format("Alchimie")
E:LoadGuide(prof)
check(#stepGoals("profopen") == 1, "asks to open the profession window first")
ready = true
fire("TRADE_SKILL_SHOW")
check(E.guide.title == prof and #stepGoals("recipe") == 1, "recipe step after the window is read")
local rg = stepGoals("recipe")[1]
check(rg.recipe == 11, "cheapest orange recipe first (got " .. tostring(rg and rg.recipe) .. ")")
local reag = stepGoals("reagent")
check(#reag == 1 and reag[1].item == 3000, "reagent list of the recipe")
local st, prog = E:GoalStatus(reag[1])
check(prog and prog:match("^%d+/%d+$"), "reagent shows have/need")
local sk = stepGoals("skill")[1]
check(sk and sk.skillLine == 2871 and sk.level > 10 and sk.level <= 100, "skill target for the expansion tab")
check(ns.GoalText(rg):find("Potion simple"), "recipe line names the recipe")
ns.GoalTypes.recipe.onClick(rg)
check(opened == 11, "clicking the recipe opens it")
-- green recipe 13 (1 reagent, ~4 reagents per point) beats orange 12 (8 reagents per point)
check(E.guide.steps[2] and E.guide.steps[2].key == "craft:13", "second choice: best skill per reagent")
local hasFirst = false
for _, s in ipairs(E.guide.steps) do if s.key == "first" then hasFirst = true end end
check(hasFirst, "first-craft recipes listed")

-- crafting raises the skill: the plan follows
child.skillLevel = sk.level
fire("TRADE_SKILL_LIST_UPDATE")
check(stepGoals("skill")[1].level > sk.level, "plan updates after skill-ups")

-- recipe 11 turns grey: the next best recipe becomes first
recipeInfo[11].relativeDifficulty = 3
fire("TRADE_SKILL_LIST_UPDATE")
check(stepGoals("recipe")[1].recipe == 13, "grey recipes are dropped")

-- skip a step, then unskip
E:Next()
check(stepGoals("recipe")[1] and stepGoals("recipe")[1].recipe == 12, "skipping hides the recipe")
SlashCmdList.FREEGOR("unskip")
flush()
check(stepGoals("recipe")[1] and stepGoals("recipe")[1].recipe == 13, "unskip shows it again")

-- maxed
child.skillLevel = 100
fire("TRADE_SKILL_LIST_UPDATE")
check(E.guide.steps[1].key == "maxed", "maxed expansion tab")


-- Full path from recipe thresholds -----------------------------------------------
local R = ns.Retail
check(R.DataBuild and R.Recipes[1230858] and R.Recipes[1230858][2] == 25, "real threshold data loaded (Midnight Alchemy)")
recipeInfo[11].relativeDifficulty = 0
child.skillLevel = 10
R.Recipes[11] = { 2871, 30, 60, 1 } -- 2 reagents
R.Recipes[12] = { 2871, 50, 90, 1 } -- 8 reagents
R.Recipes[13] = { 2871, 5, 40, 1 }  -- 1 reagent
R.Recipes[14] = { 2871, 80, 100, 1 } -- not learned
fire("TRADE_SKILL_LIST_UPDATE")
local steps = E.guide.steps
check(steps[1].key and steps[1].key:match("^path:"), "path mode when thresholds are known")
local last, ok, covered = 10, true, 10
for _, st in ipairs(steps) do
  for _, g in ipairs(st.goals) do
    if g.type == "skill" then
      if g.level <= last then ok = false end
      last, covered = g.level, g.level
    end
  end
end
check(ok, "path steps go up in skill")
check(covered == 90, "path reaches the last skill known recipes allow (got " .. covered .. ")")
check(steps[#steps].key == "learn" or steps[#steps].key == "first", "learn step when known recipes stop early")
local learnText = ""
for _, st in ipairs(steps) do if st.key == "learn" then for _, g in ipairs(st.goals) do learnText = learnText .. (g.text or "") end end end
check(learnText:find("Recette à apprendre"), "suggests the unknown recipe that still gives skill")
-- chance rule: orange below yellow, linear to grey
check(R.ChanceAt({ 0, 30, 60, 1 }, 10) == 1 and R.ChanceAt({ 0, 30, 60, 1 }, 45) == 0.5 and R.ChanceAt({ 0, 30, 60, 1 }, 60) == 0, "skill-up chance rule")
-- the first step's crafts and reagents
local rc, rgs = nil, {}
for _, g in ipairs(steps[1].goals) do
  if g.type == "recipe" then rc = g end
  if g.type == "reagent" then rgs[#rgs + 1] = g end
end
check(rc and rc.count and rc.count >= 1 and #rgs >= 1 and rgs[1].count == rc.count * schematics[rc.recipe][1].qty, "reagents sized for the whole step")
for id = 11, 14 do R.Recipes[id] = nil end
---------------------------------------------------------------------------
-- Mount guides
---------------------------------------------------------------------------

E:LoadGuide(L.MOUNT_DROP_TITLE)
local farm = stepGoals("farm")[1]
check(farm and farm.mount == 1 and farm.instance == 100 and farm.boss == "Seigneur Ancien", "drop mount: boss and instance from the source text")
check(E.waypoint and E.waypoint.mapID == 2248 and math.abs(E.waypoint.x - 0.40) < 1e-6, "arrow to the dungeon entrance")
check(#E.guide.steps == 1, "collected mounts are not listed")
saved[1] = { name = "Vieux donjon", bosses = { { name = "Seigneur Ancien", killed = true } } }
fire("UPDATE_INSTANCE_INFO")
check(E.guide.steps[1].key == "none", "boss killed this reset: mount hidden until next reset")
saved[1] = nil
fire("UPDATE_INSTANCE_INFO")

E:LoadGuide(L.MOUNT_VEN_TITLE)
check(#E.guide.steps == 1 and stepGoals("mount")[1].mount == 2, "vendor mounts, other faction hidden")
local note
for _, g in ipairs(E:CurrentStep().goals) do if g.type == "note" then note = g.text end end
check(note and not note:find("|") and note:find("Marchand"), "source text cleaned of colour codes and icons")
mounts[2].collected = true
fire("NEW_MOUNT_ADDED")
check(E.guide.steps[1].key == "none", "learning the mount removes it")

E:LoadGuide(L.MOUNT_ACH_TITLE)
local ach = stepGoals("achieve")[1]
check(ach and ach.achievement == 500, "achievement mount linked through the reward item")
local _, ap = E:GoalStatus(ach)
check(ap == "2/4", "achievement criteria progress (got " .. tostring(ap) .. ")")

E:LoadGuide(L.MOUNT_OTHER_TITLE)
check(stepGoals("mount")[1] and stepGoals("mount")[1].mount == 6, "quest mounts")

E:LoadGuide(L.ACH_NEAR_TITLE)
check(E.guide.steps[1].key == "ach:500", "most advanced achievement first")


---------------------------------------------------------------------------
-- Mount collection window
---------------------------------------------------------------------------

local Rt = ns.Retail
SlashCmdList.FREEGOR("mounts")
local W = Rt.Collection
check(W:IsShown(), "/fg mounts opens the collection")
W:Render()
local all = Rt.AllMounts()
check(#all == 5, "collection lists every mount of this faction (got " .. #all .. ")")
local entry = Rt.MountEntry(1)
check(entry.instance and entry.instance.id == 100 and entry.boss == "Seigneur Ancien" and entry.killed == false, "mount sheet: boss, instance, reset status")
check(entry.entrance and entry.entrance.map == 2248, "mount sheet: dungeon entrance")
local achEntry = Rt.MountEntry(3)
check(achEntry.achievement == 500 and achEntry.achFrac == 0.5 and #achEntry.achLeft == 2, "mount sheet: achievement progress and criteria left")
check(Rt.SourceLabel(1) == "Drop", "source label fallback")

Rt.SetTracked(3, true)
check(Rt.IsTracked(3), "track a mount")
Rt.GuideToMount(1)
check(E.guide and E.guide.title == L.MOUNT_TRACKED_TITLE, "guide button loads the tracked list")
check(E:CurrentStep().key == "mount:1", "the chosen mount comes first")
local hasFarm = false
for _, g in ipairs(E:CurrentStep().goals) do if g.type == "farm" then hasFarm = true end end
check(hasFarm and E.waypoint and E.waypoint.mapID == 2248, "tracked drop mount: farm goal and arrow to the entrance")
check(#E.guide.steps == 2, "both tracked mounts listed")
Rt.SetTracked(3, false)
Rt.SetTracked(1, false)
flush()
check(E.guide.steps[1].key == nil, "empty tracked list shows a hint")
check(ns.CategoryActions.mounts and ns.CategoryActions.mounts.label == L.COL_OPEN, "menu action for the collection")
W:Hide()

---------------------------------------------------------------------------
-- Midnight secret values
---------------------------------------------------------------------------

npcGUID, secret = "Creature-0-1-0-1-240-0000", true
check(ns.Compat.GetInteractNpcID() == nil, "secret unit GUID ignored")
secret = false
check(ns.Compat.GetInteractNpcID() == 240, "normal unit GUID read")

-- Shared files must match FreegorGuide (tools/sync_retail.sh)
for line in io.lines(ADDON_DIR .. "FreegorGuideRetail.toc") do
  local f = line:match("^(Core\\.-)$") or line:match("^(UI\\.-)$") or line:match("^(Locales\\.-)$")
  if f then
    f = f:gsub("\\", "/")
    local a = io.open("FreegorGuide/" .. f):read("*a")
    local b = io.open(ADDON_DIR .. f):read("*a")
    check(a == b, f .. " is in sync with FreegorGuide (run tools/sync_retail.sh)")
  end
end

print(("%d passed, %d failed"):format(passed, failures))
os.exit(failures == 0 and 0 or 1)
