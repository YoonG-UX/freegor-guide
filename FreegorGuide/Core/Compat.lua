local _, ns = ...

-- Thin wrappers over the game API. The exact client behind "## Interface: 16001"
-- may expose either the modern C_QuestLog/C_Map namespaces or the older globals,
-- so every helper probes for both and degrades gracefully.

local C = {}
ns.Compat = C

local C_QuestLog = _G.C_QuestLog
local C_Map = _G.C_Map

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------

function C.IsQuestCompleted(questID)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
  end
  if _G.IsQuestFlaggedCompleted then
    return _G.IsQuestFlaggedCompleted(questID) and true or false
  end
  return false
end

-- Returns the quest log index of questID, or nil.
local function logIndex(questID)
  if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    local i = C_QuestLog.GetLogIndexForQuestID(questID)
    if i and i > 0 then return i end
    return nil
  end
  if _G.GetQuestLogIndexByID then
    local i = _G.GetQuestLogIndexByID(questID)
    if i and i > 0 then return i end
    return nil
  end
  if _G.GetNumQuestLogEntries and _G.GetQuestLogTitle then
    for i = 1, (_G.GetNumQuestLogEntries()) do
      local id = select(8, _G.GetQuestLogTitle(i))
      if id == questID then return i end
    end
  end
  return nil
end

function C.IsOnQuest(questID)
  if C_QuestLog and C_QuestLog.IsOnQuest then
    return C_QuestLog.IsOnQuest(questID) and true or false
  end
  return logIndex(questID) ~= nil
end

-- List of { text, finished, numFulfilled, numRequired } for a quest in the log.
function C.GetObjectives(questID)
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    local objs = C_QuestLog.GetQuestObjectives(questID)
    if objs then return objs end
  end
  local idx = logIndex(questID)
  local out = {}
  if idx and _G.GetNumQuestLeaderBoards and _G.GetQuestLogLeaderBoard then
    for o = 1, (_G.GetNumQuestLeaderBoards(idx) or 0) do
      local text, _, finished = _G.GetQuestLogLeaderBoard(o, idx)
      local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
      out[o] = {
        text = text, finished = finished and true or false,
        numFulfilled = tonumber(have) or 0, numRequired = tonumber(need) or 0,
      }
    end
  end
  return out
end

-- True when every objective is done and the quest only needs to be turned in.
function C.IsQuestReady(questID)
  if C_QuestLog and C_QuestLog.IsComplete then
    if C_QuestLog.IsComplete(questID) then return true end
  else
    local idx = logIndex(questID)
    if idx and _G.GetQuestLogTitle then
      local isComplete = select(7, _G.GetQuestLogTitle(idx))
      if isComplete == 1 or isComplete == true then return true end
    end
  end
  local objs = C.GetObjectives(questID)
  if #objs == 0 then return false end
  for _, o in ipairs(objs) do
    if not o.finished then return false end
  end
  return true
end

function C.GetQuestTitle(questID)
  if C_QuestLog and C_QuestLog.GetTitleForQuestID then
    local t = C_QuestLog.GetTitleForQuestID(questID)
    if t and t ~= "" then return t end
  end
  local idx = logIndex(questID)
  if idx and _G.GetQuestLogTitle then
    local t = _G.GetQuestLogTitle(idx)
    if type(t) == "string" then return t end
  end
  return nil
end

---------------------------------------------------------------------------
-- Maps and positions
---------------------------------------------------------------------------

function C.GetPlayerMap()
  if C_Map and C_Map.GetBestMapForUnit then
    return C_Map.GetBestMapForUnit("player")
  end
  return nil
end

function C.GetPlayerMapPos(mapID)
  if not (C_Map and C_Map.GetPlayerMapPosition and mapID) then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if not x or (x == 0 and y == 0) then return nil end
  return x, y
end

function C.GetMapName(mapID)
  local info = C_Map and C_Map.GetMapInfo and mapID and C_Map.GetMapInfo(mapID)
  return info and info.name or nil
end

-- Map coordinates (0-1) -> continent ID and world yards (north, west).
local vecCache = {}
function C.MapToWorld(mapID, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and _G.CreateVector2D) then return nil end
  local v = vecCache.v or _G.CreateVector2D(0, 0)
  vecCache.v = v
  v:SetXY(x, y)
  local continent, world = C_Map.GetWorldPosFromMapPos(mapID, v)
  if not continent or not world then return nil end
  local north, west = world:GetXY()
  return continent, north, west
end

-- Player world position (continent, north, west).
function C.GetPlayerWorld()
  local mapID = C.GetPlayerMap()
  if not mapID then return nil end
  local x, y = C.GetPlayerMapPos(mapID)
  if not x then return nil end
  return C.MapToWorld(mapID, x, y)
end

-- Resolve a zone reference: a numeric uiMapID, or a (localized) zone name.
local nameIndex
local function buildNameIndex()
  nameIndex = {}
  if not (C_Map and C_Map.GetMapInfo) then return end
  for id = 1, 3000 do
    local info = C_Map.GetMapInfo(id)
    if info and info.name and info.name ~= "" then
      local key = info.name:lower()
      -- Prefer zones (mapType 3) over other map types sharing the name.
      if not nameIndex[key] or info.mapType == 3 then nameIndex[key] = id end
    end
  end
end

function C.ResolveMap(ref)
  if ref == nil then return nil end
  local n = tonumber(ref)
  if n then
    if C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(n) then return n end
    return nil
  end
  if not nameIndex then buildNameIndex() end
  return nameIndex[tostring(ref):lower()]
end

---------------------------------------------------------------------------
-- Interactions
---------------------------------------------------------------------------

-- Creature ID of the NPC the player is interacting with (gossip, quest, vendor...).
function C.GetInteractNpcID()
  local ok, guid = pcall(UnitGUID, "npc")
  if not ok or type(guid) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
  return nil
end

function C.GetBindLocation()
  return _G.GetBindLocation and _G.GetBindLocation() or nil
end

-- Names of flight points known to the character, read while the taxi map is open.
function C.GetKnownTaxiNodes()
  local names = {}
  local TM = _G.C_TaxiMap
  if TM and TM.GetAllTaxiNodes and _G.GetTaxiMapID then
    local ok, nodes = pcall(TM.GetAllTaxiNodes, _G.GetTaxiMapID())
    if ok and type(nodes) == "table" then
      for _, n in ipairs(nodes) do
        -- state 2 = unreachable (not discovered)
        if n.name and n.state ~= 2 then names[#names + 1] = n.name end
      end
      if #names > 0 then return names end
    end
  end
  if _G.NumTaxiNodes and _G.TaxiNodeName and _G.TaxiNodeGetType then
    for i = 1, _G.NumTaxiNodes() do
      local t = _G.TaxiNodeGetType(i)
      if t == "CURRENT" or t == "REACHABLE" then names[#names + 1] = _G.TaxiNodeName(i) end
    end
  end
  return names
end

-- Name of the flight point the player is standing at, while the taxi map is open.
function C.GetCurrentTaxiNode()
  local TM = _G.C_TaxiMap
  if TM and TM.GetAllTaxiNodes and _G.GetTaxiMapID then
    local ok, nodes = pcall(TM.GetAllTaxiNodes, _G.GetTaxiMapID())
    if ok and type(nodes) == "table" then
      for _, n in ipairs(nodes) do
        if n.state == 0 then return n.name end -- 0 = current
      end
    end
  end
  if _G.NumTaxiNodes and _G.TaxiNodeGetType then
    for i = 1, _G.NumTaxiNodes() do
      if _G.TaxiNodeGetType(i) == "CURRENT" then return _G.TaxiNodeName(i) end
    end
  end
  return nil
end

function C.GetItemCount(itemID)
  local f = (_G.C_Item and _G.C_Item.GetItemCount) or _G.GetItemCount
  if not f then return 0 end
  local ok, n = pcall(f, itemID)
  return ok and tonumber(n) or 0
end

function C.GetItemName(itemID)
  if _G.C_Item and _G.C_Item.GetItemNameByID then
    local n = _G.C_Item.GetItemNameByID(itemID)
    if n then return n end
  end
  if _G.GetItemInfo then
    local n = _G.GetItemInfo(itemID)
    if n then return n end
  end
  return nil
end

-- Reputation standing (1 hated .. 8 exalted) and faction name.
function C.GetFactionStanding(factionID)
  local R = _G.C_Reputation
  if R and R.GetFactionDataByID then
    local ok, d = pcall(R.GetFactionDataByID, factionID)
    if ok and type(d) == "table" then return d.reaction, d.name end
  end
  if _G.GetFactionInfoByID then
    local name, _, standing = _G.GetFactionInfoByID(factionID)
    return standing, name
  end
  return nil
end

-- true / false when the client knows the achievement, nil when it has no achievements.
function C.IsAchievementDone(achievementID)
  if not _G.GetAchievementInfo then return nil end
  local ok, id, name, _, completed = pcall(_G.GetAchievementInfo, achievementID)
  if not ok or not id then return nil end
  return completed and true or false, name
end

function C.HasAchievements()
  return _G.GetAchievementInfo ~= nil and _G.GetCategoryList ~= nil
    and #(_G.GetCategoryList() or {}) > 0
end

---------------------------------------------------------------------------
-- Player info
---------------------------------------------------------------------------

function C.PlayerInfo()
  local _, class = UnitClass("player")
  local _, race = UnitRace("player")
  local faction = UnitFactionGroup("player")
  return class, race, faction, UnitLevel("player")
end
