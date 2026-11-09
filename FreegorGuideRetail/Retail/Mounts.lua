local _, ns = ...
local L = ns.L
local R = ns.Retail
local Freegor = ns.Freegor
local clean = R.Clean

-- Mount guides built from the Mount Journal: the mounts this character has not
-- collected yet, grouped by how they are obtained. Drops get an arrow to the
-- dungeon or raid entrance (from the Encounter Journal) and are hidden once the
-- boss is killed for the reset; achievement mounts show the criteria left.

local SOURCE = { DROP = 1, QUEST = 2, VENDOR = 3, PROFESSION = 4, ACHIEVEMENT = 6, EVENT = 7, DISCOVERY = 11, TRADING_POST = 12 }
local MAX_STEPS = 30

local function lc(s) return (s or ""):lower() end

-- Uncollected mounts usable by this character, with their source text.
local function missingMounts(sourceTypes)
  local MJ = C_MountJournal
  if not (MJ and MJ.GetMountIDs) then return {} end
  local myFaction = UnitFactionGroup("player") == "Horde" and 0 or 1
  local out = {}
  for _, id in ipairs(MJ.GetMountIDs()) do
    local name, collected, sourceType, factionSpecific, faction, hidden = R.MountInfo(id)
    if name and not collected and not hidden and sourceTypes[sourceType]
      and not (factionSpecific and faction ~= nil and faction ~= myFaction) then
      local _, _, source = MJ.GetMountInfoExtraByID(id)
      out[#out + 1] = { id = id, name = name, sourceType = sourceType, raw = source or "", source = clean(source) }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Encounter Journal: instances (name, tier) and their entrances on the map ----

local instances -- { {id=, name=, tier=, raid=} }
local entrances -- [journalInstanceID] = { map, x, y }

local function loadInstances()
  if instances then return instances end
  instances = {}
  if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return instances end
  local current = EJ_GetCurrentTier and EJ_GetCurrentTier()
  for tier = 1, EJ_GetNumTiers() do
    EJ_SelectTier(tier)
    for _, raid in ipairs({ false, true }) do
      local i = 1
      while true do
        local id, name = EJ_GetInstanceByIndex(i, raid)
        if not id then break end
        instances[#instances + 1] = { id = id, name = name, tier = tier, raid = raid }
        i = i + 1
      end
    end
  end
  if current then EJ_SelectTier(current) end
  -- longest names first, so "Blackrock Depths" wins over "Blackrock"
  table.sort(instances, function(a, b) return #a.name > #b.name end)
  return instances
end

local function loadEntrances()
  if entrances then return entrances end
  entrances = {}
  local EJ = C_EncounterJournal
  if not (EJ and EJ.GetDungeonEntrancesForMap and C_Map and C_Map.GetMapInfo) then return entrances end
  for mapID = 1, 3000 do
    local info = C_Map.GetMapInfo(mapID)
    if info and (info.mapType == 3 or info.mapType == 2) then -- zone, then continent as fallback
      local ok, list = pcall(EJ.GetDungeonEntrancesForMap, mapID)
      for _, e in ipairs(ok and list or {}) do
        local prev = entrances[e.journalInstanceID]
        if e.position and (not prev or (prev.mapType ~= 3 and info.mapType == 3)) then
          local x, y = e.position:GetXY()
          entrances[e.journalInstanceID] = { map = mapID, x = x, y = y, mapType = info.mapType }
        end
      end
    end
  end
  return entrances
end

-- "Drop: Boss" first line -> "Boss"; instance found by name in the source text.
local function dropInfo(m)
  local firstLine = clean((m.raw:gsub("|n", "\n")):match("^[^\n]*") or "")
  local boss = firstLine:match(":%s*(.-)%s*$")
  local text = lc(m.source)
  for _, inst in ipairs(loadInstances()) do
    if inst.name and #inst.name > 3 and text:find(lc(inst.name), 1, true) then
      return inst, boss
    end
  end
  return nil, boss
end

-- Missing drop mounts of one instance: { {id, name, boss} }
function R.MissingDropMounts(journalInstanceID)
  local out = {}
  for _, m in ipairs(missingMounts({ [SOURCE.DROP] = true })) do
    local inst, boss = dropInfo(m)
    if inst and inst.id == journalInstanceID then out[#out + 1] = { id = m.id, name = m.name, boss = boss } end
  end
  return out
end

local function noneLeft() return "step\n key none\n note " .. L.MOUNT_NONE .. "\n" end

-- Drops ----------------------------------------------------------------------

local function buildDrops(guide)
  R.ScanLockouts()
  local entries = {}
  for _, m in ipairs(missingMounts({ [SOURCE.DROP] = true })) do
    local inst, boss = dropInfo(m)
    local key = "mount:" .. m.id
    if not Freegor:IsSkipped(guide.title, key) and not (inst and boss and R.IsBossKilled(inst.id, boss)) then
      entries[#entries + 1] = { m = m, inst = inst, boss = boss, key = key }
    end
  end
  -- instance drops first, oldest expansion first, then open-world drops
  table.sort(entries, function(a, b)
    if (a.inst ~= nil) ~= (b.inst ~= nil) then return a.inst ~= nil end
    if a.inst and b.inst and a.inst.tier ~= b.inst.tier then return a.inst.tier < b.inst.tier end
    return a.m.name < b.m.name
  end)
  local ent, parts = loadEntrances(), {}
  for i, e in ipairs(entries) do
    if i > MAX_STEPS then break end
    local lines = { "step", " key " .. e.key }
    local pos = e.inst and ent[e.inst.id]
    if pos then lines[#lines + 1] = (" goto %d %.1f,%.1f"):format(pos.map, pos.x * 100, pos.y * 100) end
    if e.inst and e.boss then
      lines[#lines + 1] = (" farm %d %d %s"):format(e.m.id, e.inst.id, clean(e.boss))
    else
      lines[#lines + 1] = (" mount %d %s"):format(e.m.id, clean(e.m.name))
    end
    lines[#lines + 1] = " note " .. L.MOUNT_SOURCE:format(e.m.source)
    parts[#parts + 1] = table.concat(lines, "\n")
  end
  if #parts == 0 then return noneLeft() end
  return table.concat(parts, "\n") .. "\n"
end

-- Achievements -----------------------------------------------------------------

local achForMount -- [mountID] = achievementID

function R.AchievementMountMap()
  if achForMount then return achForMount end
  achForMount = {}
  if not (GetCategoryList and GetCategoryNumAchievements and GetAchievementInfo) then return achForMount end
  local MJ = C_MountJournal
  local byName = {}
  for _, id in ipairs(MJ and MJ.GetMountIDs and MJ.GetMountIDs() or {}) do
    local name = R.MountInfo(id)
    if name then byName[#byName + 1] = { id = id, name = lc(name) } end
  end
  for _, cat in ipairs(GetCategoryList()) do
    for i = 1, (GetCategoryNumAchievements(cat, true) or 0) do
      local achID, _, _, _, _, _, _, _, _, _, rewardText = GetAchievementInfo(cat, i)
      if achID then
        local item = C_AchievementInfo and C_AchievementInfo.GetRewardItemID and C_AchievementInfo.GetRewardItemID(achID)
        local mountID = item and MJ.GetMountFromItem and MJ.GetMountFromItem(item)
        if mountID and mountID > 0 then
          achForMount[mountID] = achForMount[mountID] or achID
        elseif rewardText and rewardText ~= "" then
          local r = lc(rewardText)
          for _, m in ipairs(byName) do
            if #m.name > 4 and r:find(m.name, 1, true) then achForMount[m.id] = achForMount[m.id] or achID end
          end
        end
      end
    end
  end
  return achForMount
end

-- Fraction done (0..1) and the first criteria left.
function R.AchievementProgress(achID)
  local n = GetAchievementNumCriteria(achID) or 0
  local left = {}
  if n == 0 then return 0, left end
  local doneN, frac = 0, 0
  for i = 1, n do
    local text, _, completed, quantity, reqQuantity = GetAchievementCriteriaInfo(achID, i)
    if completed then
      doneN = doneN + 1
    elseif #left < 4 and text and text ~= "" then
      left[#left + 1] = clean(text)
    end
    if n == 1 and reqQuantity and reqQuantity > 0 then frac = (quantity or 0) / reqQuantity end
  end
  if n > 1 then frac = doneN / n end
  return frac, left
end

local function buildAchievements(guide)
  local map = R.AchievementMountMap()
  local entries = {}
  for _, m in ipairs(missingMounts({ [SOURCE.ACHIEVEMENT] = true })) do
    local achID = map[m.id]
    local key = "mount:" .. m.id
    if not Freegor:IsSkipped(guide.title, key) then
      local frac, left = 0, {}
      local done = false
      if achID then
        done = select(4, GetAchievementInfo(achID))
        frac, left = R.AchievementProgress(achID)
      end
      if not done then entries[#entries + 1] = { m = m, ach = achID, frac = frac, left = left, key = key } end
    end
  end
  table.sort(entries, function(a, b)
    if a.frac ~= b.frac then return a.frac > b.frac end
    return a.m.name < b.m.name
  end)
  local parts = {}
  for i, e in ipairs(entries) do
    if i > MAX_STEPS then break end
    local lines = { "step", " key " .. e.key }
    if e.ach then lines[#lines + 1] = " achieve " .. e.ach end
    lines[#lines + 1] = (" mount %d %s"):format(e.m.id, clean(e.m.name))
    if #e.left > 0 then lines[#lines + 1] = " note " .. L.ACH_LEFT:format(table.concat(e.left, ", ")) end
    if not e.ach then lines[#lines + 1] = " note " .. L.MOUNT_SOURCE:format(e.m.source) end
    parts[#parts + 1] = table.concat(lines, "\n")
  end
  if #parts == 0 then return noneLeft() end
  return table.concat(parts, "\n") .. "\n"
end

-- Vendors and other sources: the game's own source text ----------------------

local function buildBySource(types)
  return function(guide)
    local parts = {}
    for _, m in ipairs(missingMounts(types)) do
      local key = "mount:" .. m.id
      if #parts < 40 and not Freegor:IsSkipped(guide.title, key) then
        local v = R.VendorFor and R.VendorFor(m.id)
        local where = v and (" goto %d %.1f,%.1f\n"):format(v.map, v.x * 100, v.y * 100) or ""
        parts[#parts + 1] = ("step\n key %s\n%s mount %d %s\n note %s"):format(key, where, m.id, clean(m.name),
          L.MOUNT_SOURCE:format(m.source))
      end
    end
    if #parts == 0 then return noneLeft() end
    return table.concat(parts, "\n") .. "\n"
  end
end

-- Single mounts (collection window, tracked list) ------------------------------

-- Everything the collection window shows about one mount.
function R.MountEntry(id)
  local MJ = C_MountJournal
  local name, collected, sourceType, factionSpecific, faction, hidden, icon, spellID = R.MountInfo(id)
  if not name then return nil end
  local display, description, source = MJ.GetMountInfoExtraByID(id)
  local e = {
    id = id, name = name, collected = collected, sourceType = sourceType, icon = icon, spellID = spellID,
    factionSpecific = factionSpecific, faction = faction, hidden = hidden,
    display = display, description = clean(description), raw = source or "", source = clean(source),
  }
  if sourceType == SOURCE.DROP then
    e.instance, e.boss = dropInfo(e)
    if e.instance then e.entrance = loadEntrances()[e.instance.id] end
    if e.instance and e.boss then e.killed = R.IsBossKilled(e.instance.id, e.boss) end
  end
  e.vendor = R.VendorFor and R.VendorFor(id)
  e.achievement = R.AchievementMountMap()[id]
  if e.achievement then
    e.achDone = select(4, GetAchievementInfo(e.achievement))
    e.achFrac, e.achLeft = R.AchievementProgress(e.achievement)
  end
  return e
end

-- Every mount of the journal this character can get (both factions' own mounts filtered).
function R.AllMounts()
  local MJ = C_MountJournal
  local myFaction = UnitFactionGroup("player") == "Horde" and 0 or 1
  local out = {}
  for _, id in ipairs(MJ and MJ.GetMountIDs and MJ.GetMountIDs() or {}) do
    local name, collected, sourceType, factionSpecific, faction, hidden, icon = R.MountInfo(id)
    if name and (collected or not hidden) and not (factionSpecific and faction ~= nil and faction ~= myFaction) then
      out[#out + 1] = { id = id, name = name, collected = collected, sourceType = sourceType, icon = icon }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

-- Where to go -----------------------------------------------------------------

-- Instance named in a text (sub-achievement name or description), with its entrance.
function R.FindInstanceIn(text)
  local t = lc(clean(text))
  if t == "" then return nil end
  for _, inst in ipairs(loadInstances()) do
    if inst.name and #inst.name > 3 and t:find(lc(inst.name), 1, true) then
      return inst, loadEntrances()[inst.id]
    end
  end
end

-- Destination of a mount: instance entrance or known vendor.
function R.MountDestination(e)
  if e.entrance then return e.entrance end
  if e.vendor then return { map = e.vendor.map, x = e.vendor.x, y = e.vendor.y } end
end

-- Distance in yards from the player to a destination, nil when unknown or on another continent.
function R.DistanceTo(dest)
  if not dest then return nil end
  local C = ns.Compat
  local pc, pn, pw = C.GetPlayerWorld()
  local tc, tn, tw = C.MapToWorld(dest.map, dest.x, dest.y)
  if not pc or not tc or pc ~= tc then return nil end
  return math.sqrt((tn - pn) ^ 2 + (tw - pw) ^ 2)
end

-- Difficulty -------------------------------------------------------------------
-- 1 easy .. 4 very hard, 5 = shop / promotion. A rough guide from the source:
-- vendors are easy, old dungeons easier than recent raids, achievements by
-- progress, meta-achievements (many criteria) hardest.

local DIFF_BY_SOURCE = { [2] = 2, [3] = 1, [4] = 2, [5] = 2, [7] = 2, [8] = 5, [9] = 5, [10] = 5, [11] = 3, [12] = 2 }

function R.MountDifficulty(e)
  if e.instance then
    local newest = EJ_GetNumTiers and EJ_GetNumTiers() or e.instance.tier
    local age = newest - e.instance.tier
    if not e.instance.raid then return age >= 2 and 1 or 2 end
    if age >= 2 then return 2 elseif age == 1 then return 3 end
    return 4
  end
  if e.sourceType == SOURCE.DROP then return 3 end -- rare spawn or world drop
  if e.achievement then
    if e.achDone then return 1 end
    local n = GetAchievementNumCriteria(e.achievement) or 0
    if (e.achFrac or 0) >= 0.75 then return 1 end
    if (e.achFrac or 0) >= 0.4 then return 2 end
    return n > 8 and 4 or 3
  end
  return DIFF_BY_SOURCE[e.sourceType] or 3
end

-- Guide steps ------------------------------------------------------------------

local function gotoLine(dest)
  return (" goto %d %.1f,%.1f"):format(dest.map, dest.x * 100, dest.y * 100)
end

local function short(text, n)
  text = clean(text)
  if #text > n then text = text:sub(1, n - 3) .. "..." end
  return text
end

-- Incomplete criteria of an achievement as steps; a criterion that is a dungeon
-- or raid achievement gets an arrow to the instance entrance.
local function criteriaSteps(e, maxSteps)
  local parts = {}
  local n = GetAchievementNumCriteria(e.achievement) or 0
  for i = 1, n do
    if #parts >= maxSteps then break end
    local c = R.Criterion(e.achievement, i)
    if c and not c.completed then
      local lines = { "step", (" key crit:%d:%d"):format(e.achievement, i) }
      local where, desc = nil, nil
      if c.sub then
        local _, subName, _, _, _, _, _, subDesc = GetAchievementInfo(c.sub)
        local _, entrance = R.FindInstanceIn((subName or "") .. " " .. (subDesc or ""))
        where, desc = entrance, subDesc
      else
        local _, entrance = R.FindInstanceIn(c.text)
        where = entrance
      end
      if where then lines[#lines + 1] = gotoLine(where) end
      lines[#lines + 1] = (" crit %d %d"):format(e.achievement, i)
      if desc and desc ~= "" then lines[#lines + 1] = " note " .. short(desc, 140) end
      parts[#parts + 1] = table.concat(lines, "\n")
    end
  end
  return parts
end

-- One step for list guides (tracked list, achievement list...).
function R.MountStep(e)
  local lines = { "step", " key mount:" .. e.id }
  local dest = R.MountDestination(e)
  if e.instance and e.boss then
    if dest then lines[#lines + 1] = gotoLine(dest) end
    lines[#lines + 1] = (" farm %d %d %s"):format(e.id, e.instance.id, clean(e.boss))
  else
    if e.vendor then
      lines[#lines + 1] = gotoLine(dest)
      if e.vendor.npc then lines[#lines + 1] = (" talk %s |n %d"):format(clean(e.vendor.name or "?"), e.vendor.npc) end
    end
    if e.achievement and not e.achDone then
      lines[#lines + 1] = " achieve " .. e.achievement
      local shown = 0
      for i = 1, (GetAchievementNumCriteria(e.achievement) or 0) do
        local c = R.Criterion(e.achievement, i)
        if c and not c.completed and shown < 4 then
          lines[#lines + 1] = (" crit %d %d"):format(e.achievement, i)
          shown = shown + 1
        end
      end
    end
    lines[#lines + 1] = (" mount %d %s"):format(e.id, clean(e.name))
  end
  lines[#lines + 1] = " note " .. L.MOUNT_SOURCE:format(e.source)
  return table.concat(lines, "\n")
end

-- The whole guide for one chosen mount.
function R.MountGuideBody(e)
  if e.collected then return "step\n key owned\n mount " .. e.id .. "\n note " .. clean(L.COL_COLLECTED) .. "\n" end
  local parts = {}
  local dest = R.MountDestination(e)
  local zone = dest and ns.Compat.GetMapName(dest.map)
  if e.instance and e.boss then
    local lines = { "step", " key farm", gotoLine(dest or { map = 0, x = 0, y = 0 }) }
    if not dest then table.remove(lines) end
    lines[#lines + 1] = (" farm %d %d %s"):format(e.id, e.instance.id, clean(e.boss))
    if zone then lines[#lines + 1] = " note " .. clean(L.MOUNT_GO_INSTANCE:format(e.instance.name, zone)) end
    lines[#lines + 1] = " note " .. clean(L.MOUNT_INSIDE)
    lines[#lines + 1] = " note " .. L.MOUNT_SOURCE:format(e.source)
    parts[#parts + 1] = table.concat(lines, "\n")
  elseif e.achievement and not e.achDone then
    for _, p in ipairs(criteriaSteps(e, 15)) do parts[#parts + 1] = p end
    parts[#parts + 1] = ("step\n key reward\n achieve %d\n mount %d %s\n note %s"):format(
      e.achievement, e.id, clean(e.name), L.MOUNT_SOURCE:format(e.source))
  elseif e.vendor then
    local lines = { "step", " key vendor", gotoLine(dest) }
    if e.vendor.npc then lines[#lines + 1] = (" talk %s |n %d"):format(clean(e.vendor.name or "?"), e.vendor.npc) end
    lines[#lines + 1] = (" mount %d %s"):format(e.id, clean(e.name))
    lines[#lines + 1] = " note " .. L.MOUNT_SOURCE:format(e.source)
    parts[#parts + 1] = table.concat(lines, "\n")
  else
    local lines = { "step", " key source", (" mount %d %s"):format(e.id, clean(e.name)),
      " note " .. L.MOUNT_SOURCE:format(e.source) }
    if e.sourceType == SOURCE.VENDOR then lines[#lines + 1] = " note " .. clean(L.COL_VENDOR_UNKNOWN) end
    parts[#parts + 1] = table.concat(lines, "\n")
  end
  return table.concat(parts, "\n") .. "\n"
end

-- Tracked mounts (wish list) -----------------------------------------------------

function R.IsTracked(id) return ns.cdb and ns.cdb.trackedMounts and ns.cdb.trackedMounts[id] or false end

function R.SetTracked(id, on)
  ns.cdb.trackedMounts = ns.cdb.trackedMounts or {}
  ns.cdb.trackedMounts[id] = on and true or nil
  if ns.Engine.guide and ns.Engine.guide.title == L.MOUNT_TRACKED_TITLE then ns.Engine:QueueRebuild() end
end

local function buildTracked(guide)
  R.ScanLockouts()
  local first = R.focusMount
  local list = {}
  for id in pairs(ns.cdb.trackedMounts or {}) do
    local e = R.MountEntry(id)
    if e and not e.collected and not e.killed and not Freegor:IsSkipped(guide.title, "mount:" .. id) then
      list[#list + 1] = e
    end
  end
  table.sort(list, function(a, b)
    if (a.id == first) ~= (b.id == first) then return a.id == first end
    return a.name < b.name
  end)
  if #list == 0 then return nil, L.MOUNT_TRACKED_EMPTY end
  local parts = {}
  for _, e in ipairs(list) do parts[#parts + 1] = R.MountStep(e) end
  return table.concat(parts, "\n") .. "\n"
end

-- Guide to one mount: its own guide with its portrait and 3D model.
function R.GuideToMount(id)
  R.focusMount = id
  ns.cdb.focusMount = id
  ns.Engine:LoadGuide(L.MOUNT_FOCUS_TITLE)
  ns.SetShown(true)
end

local function buildFocus(guide)
  local id = R.focusMount or (ns.cdb and ns.cdb.focusMount)
  local e = id and R.MountEntry(id)
  if not e then
    guide.displayTitle, guide.visual = nil, nil
    return nil, L.MOUNT_FOCUS_EMPTY
  end
  R.ScanLockouts()
  guide.displayTitle = e.name
  local display = e.display
  if not display and C_MountJournal.GetMountAllCreatureDisplayInfoByID then
    local all = C_MountJournal.GetMountAllCreatureDisplayInfoByID(e.id)
    display = all and all[1] and all[1].creatureDisplayID
  end
  guide.visual = { icon = e.icon, display = display, onClick = function()
    if R.OpenCollectionAt then R.OpenCollectionAt(e.id) end
  end }
  return R.MountGuideBody(e)
end

local MOUNT_EVENTS = { "NEW_MOUNT_ADDED", "UPDATE_INSTANCE_INFO", "ACHIEVEMENT_EARNED" }

Freegor:RegisterDynamicGuide({
  title = L.MOUNT_TRACKED_TITLE, category = "mounts", description = L.MOUNT_TRACKED_DESC,
  events = MOUNT_EVENTS, build = buildTracked,
})
Freegor:RegisterDynamicGuide({
  title = L.MOUNT_FOCUS_TITLE, category = "mounts", description = L.MOUNT_FOCUS_DESC,
  events = { "NEW_MOUNT_ADDED", "UPDATE_INSTANCE_INFO", "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE" },
  build = buildFocus,
})

Freegor:RegisterDynamicGuide({
  title = L.MOUNT_DROP_TITLE, category = "mounts", description = L.MOUNT_DROP_DESC,
  events = MOUNT_EVENTS, build = buildDrops,
})
Freegor:RegisterDynamicGuide({
  title = L.MOUNT_ACH_TITLE, category = "mounts", description = L.MOUNT_ACH_DESC,
  events = MOUNT_EVENTS, build = buildAchievements,
})
Freegor:RegisterDynamicGuide({
  title = L.MOUNT_VEN_TITLE, category = "mounts", description = L.MOUNT_VEN_DESC,
  events = MOUNT_EVENTS, build = buildBySource({ [SOURCE.VENDOR] = true }),
})
Freegor:RegisterDynamicGuide({
  title = L.MOUNT_OTHER_TITLE, category = "mounts", description = L.MOUNT_OTHER_DESC,
  events = MOUNT_EVENTS,
  build = buildBySource({ [SOURCE.QUEST] = true, [SOURCE.PROFESSION] = true, [SOURCE.EVENT] = true,
    [SOURCE.DISCOVERY] = true, [SOURCE.TRADING_POST] = true }),
})

-- Achievements almost done -----------------------------------------------------

local function buildNearAchievements(guide)
  if not (GetCategoryList and GetAchievementInfo) then return nil, L.NO_ACHIEVEMENTS end
  local entries = {}
  for _, cat in ipairs(GetCategoryList()) do
    for i = 1, (GetCategoryNumAchievements(cat, true) or 0) do
      local achID, _, _, completed, _, _, _, _, flags, _, _, isGuild, _, _, isStatistic = GetAchievementInfo(cat, i)
      if achID and not completed and not isGuild and not isStatistic
        and not Freegor:IsSkipped(guide.title, "ach:" .. achID) then
        local frac, left = R.AchievementProgress(achID)
        if frac > 0 and frac < 1 then entries[#entries + 1] = { id = achID, frac = frac, left = left } end
      end
    end
  end
  table.sort(entries, function(a, b) return a.frac > b.frac end)
  local parts = {}
  for i, e in ipairs(entries) do
    if i > MAX_STEPS then break end
    local lines = { "step", " key ach:" .. e.id, " achieve " .. e.id }
    if #e.left > 0 then lines[#lines + 1] = " note " .. L.ACH_LEFT:format(table.concat(e.left, ", ")) end
    parts[#parts + 1] = table.concat(lines, "\n")
  end
  if #parts == 0 then return nil, L.DYN_EMPTY end
  return table.concat(parts, "\n") .. "\n"
end

Freegor:RegisterDynamicGuide({
  title = L.ACH_NEAR_TITLE, category = "achievements", description = L.ACH_NEAR_DESC,
  events = { "ACHIEVEMENT_EARNED" }, build = buildNearAchievements,
})
