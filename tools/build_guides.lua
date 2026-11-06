-- Builds FreegorGuide/Guides/*.lua from the route files in tools/routes/.
--
-- A route lists *what to do* in which order (quest IDs, travel, actions).
-- This script fills in the facts from a local checkout of the public
-- QuestieDB data (quest givers, NPC positions, mob/item locations, French
-- names) and checks the route: unknown IDs, quests turned in before being
-- accepted, missing prerequisite quests, quests started below their level.
--
-- Usage (from the repository root, with Lua 5.1):
--   QUESTIEDB=/path/to/QuestieDB lua5.1 tools/build_guides.lua
--
-- QuestieDB: https://github.com/Questie/QuestieDB (only data/Forever/*.lua and
-- l10n/Forever/*/frFR.lua are read). See tools/README.md.

local DB = os.getenv("QUESTIEDB") or error("set QUESTIEDB to a QuestieDB checkout")
DB = DB:gsub("/?$", "/")

---------------------------------------------------------------------------
-- Data loading (the data files are Lua table literals; load them with no globals)
---------------------------------------------------------------------------

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local t = f:read("*a")
  f:close()
  return t
end

local function evalTable(src, chunkname)
  local fn = assert(loadstring(src, chunkname))
  setfenv(fn, {})
  return fn()
end

local function loadData(path, marker)
  local txt = readFile(DB .. path)
  local _, e = txt:find(marker, 1, true)
  assert(e, marker .. " not found in " .. path)
  local stop = txt:find("]]", e + 1, true)
  return evalTable(txt:sub(e + 1, stop - 1), path)
end

local quests = loadData("data/Forever/foreverQuestDB.lua", "QuestieDB.questData = [[")
local npcs = loadData("data/Forever/foreverNpcDB.lua", "QuestieDB.npcData = [[")
local objects = loadData("data/Forever/foreverObjectDB.lua", "QuestieDB.objectData = [[")
local items = loadData("data/Forever/foreverItemDB.lua", "QuestieDB.itemData = [[")
local frQuests = loadData("l10n/Forever/lookupQuests/frFR.lua", "loadstring([[")
local frNpcs = loadData("l10n/Forever/lookupNpcs/frFR.lua", "loadstring([[")
local frItems = loadData("l10n/Forever/lookupItems/frFR.lua", "loadstring([[")
local frObjects = loadData("l10n/Forever/lookupObjects/frFR.lua", "loadstring([[")

-- Field indexes (see QuestieDB questKeys / npcKeys / objectKeys / itemKeys)
local Q_NAME, Q_START, Q_END, Q_REQLVL, Q_LVL, Q_RACES, Q_CLASSES = 1, 2, 3, 4, 5, 6, 7
local Q_TRIGGER, Q_OBJ, Q_PREGROUP, Q_PRESINGLE = 9, 10, 12, 13
local N_NAME, N_SPAWNS = 1, 7
local O_NAME, O_SPAWNS = 1, 4
local I_NAME, I_NPCDROPS, I_OBJDROPS = 1, 2, 3

-- AreaTable zone ID -> uiMapID (Classic/Forever world maps)
local AREA_TO_MAP = {
  [1] = 1426,    -- Dun Morogh
  [10] = 1431,   -- Duskwood
  [11] = 1437,   -- Wetlands
  [12] = 1429,   -- Elwynn Forest
  [38] = 1432,   -- Loch Modan
  [40] = 1436,   -- Westfall
  [44] = 1433,   -- Redridge Mountains
  [141] = 1438,  -- Teldrassil
  [148] = 1439,  -- Darkshore
  [267] = 1424,  -- Hillsbrad Foothills
  [331] = 1440,  -- Ashenvale
  [406] = 1442,  -- Stonetalon Mountains
  [1519] = 1453, -- Stormwind City
  [1537] = 1455, -- Ironforge
  [1657] = 1457, -- Darnassus
  [4] = 1419,    -- Blasted Lands
  [15] = 1445,   -- Dustwallow Marsh
  [16] = 1447,   -- Azshara
  [17] = 1413,   -- The Barrens
  [28] = 1422,   -- Western Plaguelands
  [33] = 1434,   -- Stranglethorn Vale
  [45] = 1417,   -- Arathi Highlands
  [46] = 1428,   -- Burning Steppes
  [47] = 1425,   -- The Hinterlands
  [51] = 1427,   -- Searing Gorge
  [139] = 1423,  -- Eastern Plaguelands
  [357] = 1444,  -- Feralas
  [361] = 1448,  -- Felwood
  [405] = 1443,  -- Desolace
  [440] = 1446,  -- Tanaris
  [490] = 1449,  -- Un'Goro Crater
  [493] = 1450,  -- Moonglade
  [618] = 1452,  -- Winterspring
  [1377] = 1451, -- Silithus
  [14] = 1411,   -- Durotar
  [215] = 1412,  -- Mulgore
  [85] = 1420,   -- Tirisfal Glades
  [130] = 1421,  -- Silverpine Forest
  [36] = 1416,   -- Alterac Mountains
  [400] = 1441,  -- Thousand Needles
  [1637] = 1454, -- Orgrimmar
  [1638] = 1456, -- Thunder Bluff
  [1497] = 1458, -- Undercity
  [3] = 1418,    -- Badlands
  [8] = 1435,    -- Swamp of Sorrows
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local errors, warnings, notes = {}, {}, {}
local circuit
local function lastPosOf(step)
  local pos
  for _, g in ipairs(step.goals) do
    local m, x, y = g:match("^goto (%d+) ([%d%.]+),([%d%.]+)")
    if m then pos = { tonumber(m), tonumber(x), tonumber(y) } end
  end
  return pos
end
local optimizeVisits
local ctx = { file = "?", line = 0 }
local function err(msg) errors[#errors + 1] = ("%s:%d: %s"):format(ctx.file, ctx.line, msg) end
local function warn(msg) warnings[#warnings + 1] = ("%s:%d: %s"):format(ctx.file, ctx.line, msg) end

local function hasBit(mask, bit) return math.floor(mask / bit) % 2 == 1 end
local FACTION_RACES = { Alliance = { 1, 4, 8, 64 }, Horde = { 2, 16, 32, 128 } }
local function availableTo(q, faction)
  local r = q[Q_RACES]
  if not r or r == 0 then return true end
  for _, b in ipairs(FACTION_RACES[faction] or FACTION_RACES.Alliance) do if hasBit(r, b) then return true end end
  return false
end

local function frQuestTitle(id)
  local e = frQuests[id]
  return e and e[1] or nil
end
local function frNpcName(id)
  local e = frNpcs[id]
  return e and e[1] or nil
end

-- The text of a guide option must not contain "|".
local function clean(s) return s and (s:gsub("|", "/"):gsub("%s+", " ")) or nil end

local function fmtCoord(x, y) return ("%.1f,%.1f"):format(x, y) end

-- Pick the spawn area: the preferred area if present, else the one with most points.
local function chooseArea(spawns, preferred)
  if not spawns then return nil end
  if preferred and spawns[preferred] and #spawns[preferred] > 0 then return preferred end
  local best, n = nil, 0
  for area, pts in pairs(spawns) do
    if AREA_TO_MAP[area] and #pts > n then best, n = area, #pts end
  end
  return best
end

-- Densest point of a point cloud: the point with most neighbours within r,
-- averaged with those neighbours.
-- With `ref` (where the player is at that point of the route), the dense
-- spot nearest to the player wins over the densest one far away.
local function hotspot(points, r, ref)
  r = r or 5
  local counts, maxN = {}, 0
  for i, p in ipairs(points) do
    local n = 0
    for _, o in ipairs(points) do
      local dx, dy = p[1] - o[1], p[2] - o[2]
      if dx * dx + dy * dy <= r * r then n = n + 1 end
    end
    counts[i] = n
    if n > maxN then maxN = n end
  end
  local best, bestKey
  for i, p in ipairs(points) do
    local key
    if ref then
      if counts[i] >= math.max(3, maxN * 0.4) or counts[i] == maxN then
        local dx, dy = p[1] - ref[1], p[2] - ref[2]
        key = dx * dx + dy * dy
      end
    else
      key = -counts[i]
    end
    if key and (not bestKey or key < bestKey) then best, bestKey = p, key end
  end
  if not best then return nil end
  local sx, sy, c = 0, 0, 0
  for _, o in ipairs(points) do
    local dx, dy = best[1] - o[1], best[2] - o[2]
    if dx * dx + dy * dy <= r * r then sx, sy, c = sx + o[1], sy + o[2], c + 1 end
  end
  return sx / c, sy / c
end

-- First spawn of an NPC: area, x, y
-- Circuit through spawn points: k-means into `n` waypoints (weighted toward
-- dense areas), then the shortest loop found by nearest neighbour + 2-opt.
circuit = function(points, n, start)
  if #points == 0 then return {} end
  n = math.min(n, #points)
  -- farthest-point initialisation, deterministic
  local centers = { { points[1][1], points[1][2] } }
  while #centers < n do
    local best, bestD = nil, -1
    for _, p in ipairs(points) do
      local d = math.huge
      for _, c in ipairs(centers) do
        local dx, dy = p[1] - c[1], p[2] - c[2]
        d = math.min(d, dx * dx + dy * dy)
      end
      if d > bestD then best, bestD = p, d end
    end
    centers[#centers + 1] = { best[1], best[2] }
  end
  for _ = 1, 30 do
    local sums = {}
    for i = 1, n do sums[i] = { 0, 0, 0 } end
    for _, p in ipairs(points) do
      local bi, bd = 1, math.huge
      for i, c in ipairs(centers) do
        local dx, dy = p[1] - c[1], p[2] - c[2]
        local d = dx * dx + dy * dy
        if d < bd then bi, bd = i, d end
      end
      sums[bi][1], sums[bi][2], sums[bi][3] = sums[bi][1] + p[1], sums[bi][2] + p[2], sums[bi][3] + 1
    end
    for i = 1, n do
      if sums[i][3] > 0 then centers[i] = { sums[i][1] / sums[i][3], sums[i][2] / sums[i][3] } end
    end
  end
  local function d(a, b) local dx, dy = a[1] - b[1], a[2] - b[2]; return math.sqrt(dx * dx + dy * dy) end
  -- start from the waypoint nearest to the player's position
  local first = 1
  if start then
    for i, c in ipairs(centers) do if d(c, start) < d(centers[first], start) then first = i end end
  end
  local tour, used = { centers[first] }, { [first] = true }
  while #tour < n do
    local last, bi, bd = tour[#tour], nil, math.huge
    for i, c in ipairs(centers) do
      if not used[i] and d(last, c) < bd then bi, bd = i, d(last, c) end
    end
    used[bi] = true
    tour[#tour + 1] = centers[bi]
  end
  local improved = true
  while improved do
    improved = false
    for i = 2, n - 1 do
      for j = i + 1, n do
        local a, b, c2, e = tour[i - 1], tour[i], tour[j], tour[j % n + 1]
        if d(a, c2) + d(b, e) < d(a, b) + d(c2, e) - 1e-9 then
          local k, l = i, j
          while k < l do tour[k], tour[l] = tour[l], tour[k]; k, l = k + 1, l - 1 end
          improved = true
        end
      end
    end
  end
  return tour
end

local function npcLocation(id, preferredArea)
  local n = npcs[id]
  if not n then return nil end
  local area = chooseArea(n[N_SPAWNS], preferredArea)
  if not area then return nil end
  local pts = n[N_SPAWNS][area]
  if #pts == 1 then return area, pts[1][1], pts[1][2] end
  local x, y = hotspot(pts, 3)
  return area, x, y
end


---------------------------------------------------------------------------
-- Visit optimisation
--
-- Consecutive NPC visits (accept / turn in / innkeeper / flight master) are
-- reordered so that everything possible is done with one NPC before moving
-- on, always walking to the nearest NPC that has something available, and
-- never taking a quest before its prerequisite is turned in. NPCs standing
-- close to each other are then shown in a single step.
---------------------------------------------------------------------------

local MERGE_DISTANCE = 3.0  -- map units (percent of the zone map)
local MAX_STEP_LINES = 14

local function gotoPos(line)
  local m, x, y = line:match("^goto (%d+) ([%d%.]+),([%d%.]+)")
  if m then return { tonumber(m), tonumber(x), tonumber(y) } end
end

local function lastPos(step)
  local pos
  for _, g in ipairs(step.goals) do pos = gotoPos(g) or pos end
  return pos
end

local function dist(p, q)
  if not p or not q then return 1e9 end
  if p[1] ~= q[1] then return 1e6 end
  local dx, dy = p[2] - q[2], p[3] - q[3]
  return math.sqrt(dx * dx + dy * dy)
end

-- Visits that may move: plain NPC visits. Taking a flight or using the
-- hearthstone ends the hub, so those visits stay where they are.
local function floating(s)
  if s.only or not s.items or not s.head or not s.head[1] or not gotoPos(s.head[1]) then return false end
  for _, e in ipairs(s.extra or {}) do
    local c = e.line:match("^(%a+)")
    if c == "fly" or c == "hearth" or c == "goto" then return false end
  end
  return true
end

local function questPrereqs(id)
  local q = quests[id]
  local out = {}
  for _, p in ipairs(q and q[Q_PRESINGLE] or {}) do out[p] = true end
  for _, p in ipairs(q and q[Q_PREGROUP] or {}) do out[p] = true end
  return out
end

local function reorderRun(run, startPos)
  -- units: quest lines and extra lines, each tied to an NPC
  local units, npcHead, npcPos = {}, {}, {}
  local turninUnit, acceptUnit = {}, {}
  for _, s in ipairs(run) do
    npcHead[s.npc] = npcHead[s.npc] or s.head
    npcPos[s.npc] = npcPos[s.npc] or gotoPos(s.head[1])
    local own = {}
    for _, it in ipairs(s.items) do
      local u = { npc = s.npc, line = it.line, verb = it.verb, id = it.id, deps = {} }
      units[#units + 1] = u
      own[#own + 1] = u
      if it.verb == "turnin" then turninUnit[it.id] = u else acceptUnit[it.id] = u end
    end
    for _, e in ipairs(s.extra or {}) do
      -- an extra line (home, fpath, buy...) waits for the quest lines written before it
      local u = { npc = s.npc, line = e.line, deps = {} }
      for k = 1, e.after do u.deps[#u.deps + 1] = own[k] end
      units[#units + 1] = u
    end
  end
  for _, u in ipairs(units) do
    if u.verb == "accept" then
      for pre in pairs(questPrereqs(u.id)) do
        if turninUnit[pre] then u.deps[#u.deps + 1] = turninUnit[pre] end
      end
    elseif u.verb == "turnin" and acceptUnit[u.id] then
      u.deps[#u.deps + 1] = acceptUnit[u.id]
    end
  end

  local done, left = {}, #units
  local function ready(u)
    if done[u] then return false end
    for _, d in ipairs(u.deps) do if not done[d] then return false end end
    return true
  end

  local visits, cur, curPos = {}, nil, startPos
  while left > 0 do
    local progressed = false
    if cur then
      for _, u in ipairs(units) do
        if u.npc == cur.npc and ready(u) then
          cur.lines[#cur.lines + 1] = u.line
          done[u], left, progressed = true, left - 1, true
        end
      end
    end
    if not progressed then
      -- nearest NPC with something available (first in route order on ties)
      local best, bestD
      for _, u in ipairs(units) do
        if ready(u) then
          local d = dist(curPos, npcPos[u.npc])
          if not bestD or d < bestD - 1e-6 then best, bestD = u, d end
        end
      end
      if not best then error("visit optimisation: circular dependencies") end
      cur = { npc = best.npc, lines = {} }
      visits[#visits + 1] = cur
      curPos = npcPos[best.npc]
    end
  end

  -- one step per visit, then merge visits of NPCs standing close together
  local out = {}
  for _, v in ipairs(visits) do
    local s = { kind = "npc", npc = v.npc, goals = {}, items = {} }
    for _, g in ipairs(npcHead[v.npc]) do s.goals[#s.goals + 1] = g end
    for _, l in ipairs(v.lines) do s.goals[#s.goals + 1] = l end
    local prev = out[#out]
    if prev and dist(lastPos(prev), npcPos[v.npc]) <= MERGE_DISTANCE
      and #prev.goals + #s.goals <= MAX_STEP_LINES then
      for _, g in ipairs(s.goals) do prev.goals[#prev.goals + 1] = g end
    else
      out[#out + 1] = s
    end
  end
  return out
end

-- Reports NPCs visited twice in a row of NPC steps (A, B, A): with the
-- optimisation above this only remains when a prerequisite forces it.
local function reportRevisits(steps, path)
  local seen = {}
  for i, s in ipairs(steps) do
    if s.kind == "npc" or s.kind == "talk" then
      for _, g in ipairs(s.goals) do
        local id = tonumber(g:match("^talk .- |n (%d+)") or "")
        if id then
          if seen[id] and seen[id] >= i - 2 and seen[id] < i then
            notes[#notes + 1] = ("%s: NPC %d visited again at step %d (prerequisite)"):format(path, id, i)
          end
          seen[id] = i
        end
      end
    else
      seen = {}
    end
  end
end

-- Reports quests whose objectives are close to where the quest is picked up,
-- but which the route only does after walking away and coming back.
local NEAR, AWAY = 8, 12
local function reportDetours(steps, path)
  for i, s in ipairs(steps) do
    local pos
    for _, g in ipairs(s.goals) do
      pos = gotoPos(g) or pos
      local qid = tonumber(g:match("^accept (%d+)") or "")
      if qid and pos then
        for j = i + 1, #steps do
          local hit = false
          for _, l in ipairs(steps[j].goals) do
            if l:find("|q " .. qid .. "[/ ]") or l:find("|q " .. qid .. "$") or l:match("^do " .. qid .. " ") then hit = true end
          end
          if hit then
            local target = steps[j].goals[1] and gotoPos(steps[j].goals[1])
            if target and dist(pos, target) <= NEAR then
              for k = i + 1, j - 1 do
                if dist(pos, lastPos(steps[k])) > AWAY then
                  warnings[#warnings + 1] = ("%s: quest %d objectives are %.1f from its quest giver (step %d) but done at step %d after a detour")
                    :format(path, qid, dist(pos, target), i, j)
                  break
                end
              end
            end
            break
          end
        end
      end
    end
  end
end

optimizeVisits = function(steps, path)
  local out, i, pos = {}, 1, nil
  while i <= #steps do
    if floating(steps[i]) then
      local run, j = {}, i
      while steps[j] and floating(steps[j]) do run[#run + 1] = steps[j]; j = j + 1 end
      for _, s in ipairs(reorderRun(run, pos)) do out[#out + 1] = s end
      i = j
    else
      out[#out + 1] = steps[i]
      i = i + 1
    end
    pos = lastPos(out[#out]) or pos
  end
  reportRevisits(out, path)
  reportDetours(out, path)
  return out
end

---------------------------------------------------------------------------
-- Route parsing and guide emission
---------------------------------------------------------------------------

local function buildRoute(path, state)
  ctx.file = path
  local out = {}      -- emitted lines
  local header = {}
  local steps = {}    -- { only=, goals = { lines }, npc = id or nil, kind = }
  local area, map     -- current defaults
  local pendingOnly
  local level = state.level
  local routeFaction = "Alliance"

  local function newStep(kind, npc)
    local s = { goals = {}, kind = kind, npc = npc, only = pendingOnly }
    pendingOnly = nil
    steps[#steps + 1] = s
    return s
  end
  local function curStep() return steps[#steps] end

  local function gotoLine(a, x, y)
    local m = AREA_TO_MAP[a]
    if not m then err("no uiMapID for area " .. tostring(a)); return "goto ?" end
    return ("goto %d %s"):format(m, fmtCoord(x, y))
  end

  local function questOrErr(id)
    local q = quests[id]
    if not q then err("unknown quest " .. id) return nil end
    if not availableTo(q, routeFaction) then err(("quest %d %s is not available to the %s"):format(id, q[Q_NAME], routeFaction)) end
    return q
  end

  local function talkLine(npcId)
    local fr = frNpcName(npcId)
    return ("talk %s |n %d%s"):format(clean(npcs[npcId][N_NAME]), npcId, fr and (" |fr " .. clean(fr)) or "")
  end

  local function questLine(verb, id, q)
    local fr = frQuestTitle(id)
    return ("%s %d %s%s"):format(verb, id, clean(q[Q_NAME]), fr and (" |fr " .. clean(fr)) or "")
  end

  -- accept/turnin at an NPC (or an object / item)
  local function questGiver(verb, id, giverOverride)
    local q = questOrErr(id)
    if not q then return end
    local list = verb == "accept" and q[Q_START] or q[Q_END]
    local npcId = giverOverride or (list and list[1] and list[1][1])
    if npcId then
      local s = curStep()
      if not (s and s.kind == "npc" and s.npc == npcId and not pendingOnly) then
        s = newStep("npc", npcId)
        local a, x, y = npcLocation(npcId, area)
        if a then s.goals[#s.goals + 1] = gotoLine(a, x, y) else warn("no spawn for NPC " .. npcId) end
        s.goals[#s.goals + 1] = talkLine(npcId)
        s.head = { s.goals[1], s.goals[2] }
        s.items = {}
      end
      local ql = questLine(verb, id, q)
      s.goals[#s.goals + 1] = ql
      table.insert(s.items, { verb = verb, id = id, line = ql })
    else
      local s = newStep("other")
      local objId = list and list[2] and list[2][1]
      local itemId = verb == "accept" and q[Q_START] and q[Q_START][3] and q[Q_START][3][1]
      if objId and objects[objId] then
        local a = chooseArea(objects[objId][O_SPAWNS], area)
        if a then
          local p = objects[objId][O_SPAWNS][a][1]
          s.goals[#s.goals + 1] = gotoLine(a, p[1], p[2])
        end
        local fr = frObjects[objId]
        s.goals[#s.goals + 1] = ("note Click on %s%s"):format(clean(objects[objId][O_NAME]),
          fr and (" |fr Cliquez sur : " .. clean(fr)) or "")
      elseif itemId and items[itemId] then
        local fr = frItems[itemId]
        s.goals[#s.goals + 1] = ("use %s%s"):format(clean(items[itemId][I_NAME]), fr and (" |fr " .. clean(fr)) or "")
      else
        warn(("quest %d has no %s NPC"):format(id, verb))
      end
      s.goals[#s.goals + 1] = questLine(verb, id, q)
    end

    -- bookkeeping / checks
    if verb == "accept" then
      if state.accepted[id] or state.done[id] then warn(("quest %d accepted twice"):format(id)) end
      state.accepted[id] = true
      if q[Q_REQLVL] and level and q[Q_REQLVL] > level + 1 then
        warn(("quest %d %s requires level %d (route level %d)"):format(id, q[Q_NAME], q[Q_REQLVL], level))
      end
      local single = q[Q_PRESINGLE]
      if single and #single > 0 then
        local ok = false
        for _, p in ipairs(single) do if state.done[p] then ok = true end end
        if not ok then warn(("quest %d needs one of %s turned in first"):format(id, table.concat(single, ","))) end
      end
      for _, p in ipairs(q[Q_PREGROUP] or {}) do
        if not state.done[p] then warn(("quest %d needs %d turned in first"):format(id, p)) end
      end
    else
      if not state.accepted[id] then err(("quest %d turned in but never accepted"):format(id)) end
      state.done[id] = true
    end
  end

  -- objective step
  local function doQuest(id, override, merge)
    local q = questOrErr(id)
    if not q then return end
    if not state.accepted[id] then err(("quest %d done before being accepted"):format(id)) end
    local s = (merge and curStep()) or newStep("do")
    local obj = q[Q_OBJ] or {}
    local creatures, objs, its, credits = obj[1] or {}, obj[2] or {}, obj[3] or {}, obj[5] or {}
    local nTypes = (#creatures > 0 and 1 or 0) + (#objs > 0 and 1 or 0) + (#its > 0 and 1 or 0) + (#credits > 0 and 1 or 0)
    local total = #creatures + #objs + #its + #credits
    -- Spawn points of every objective source, grouped by area; the route's
    -- area wins when it has any, else the area with the most points.
    local byArea = {}
    local function addSpawns(spawns)
      for a, pts in pairs(spawns or {}) do
        if AREA_TO_MAP[a] then
          byArea[a] = byArea[a] or {}
          for _, p in ipairs(pts) do table.insert(byArea[a], p) end
        end
      end
    end
    local function idx(i) return (total == 1 or nTypes == 1) and ("/" .. i) or "" end
    local lines = {}

    for i, c in ipairs(creatures) do
      local n = npcs[c[1]]
      if n then
        addSpawns(n[N_SPAWNS])
        local fr = frNpcName(c[1])
        lines[#lines + 1] = ("kill %s |q %d%s%s"):format(clean(c[2] or n[N_NAME]), id, idx(i), fr and not c[2] and (" |fr " .. clean(fr)) or "")
      end
    end
    for i, c in ipairs(credits) do
      local n = npcs[c[2]]
      if n then addSpawns(n[N_SPAWNS]) end
      for _, alt in ipairs(c[1] or {}) do if npcs[alt] then addSpawns(npcs[alt][N_SPAWNS]) end end
      local fr = frNpcName(c[2])
      lines[#lines + 1] = ("kill %s |q %d%s%s"):format(clean(c[3] or (n and n[N_NAME]) or "?"), id, idx(i), fr and not c[3] and (" |fr " .. clean(fr)) or "")
    end
    for i, it in ipairs(its) do
      local item = items[it[1]]
      if item then
        for _, src in ipairs(item[I_NPCDROPS] or {}) do if npcs[src] then addSpawns(npcs[src][N_SPAWNS]) end end
        for _, src in ipairs(item[I_OBJDROPS] or {}) do if objects[src] then addSpawns(objects[src][O_SPAWNS]) end end
        local fr = frItems[it[1]]
        lines[#lines + 1] = ("collect %s |q %d%s%s"):format(clean(it[2] or item[I_NAME]), id, idx(i), fr and not it[2] and (" |fr " .. clean(fr)) or "")
      end
    end
    for _, o in ipairs(objs) do
      local ob = objects[o[1]]
      if ob then addSpawns(ob[O_SPAWNS]) end
    end
    if #objs > 0 or #lines == 0 then
      lines[#lines + 1] = questLine("do", id, q)
    end
    local trig = q[Q_TRIGGER]
    if trig and trig[2] and next(byArea) == nil then
      addSpawns(trig[2])
    end

    local pointArea = chooseArea(byArea, area)
    local points = pointArea and byArea[pointArea] or {}
    local ref
    do
      local prevStep = steps[#steps - ((merge or s ~= steps[#steps]) and 0 or 1)]
      local pp = prevStep and prevStep ~= s and lastPosOf(prevStep)
      if pp and pointArea and pp[1] == AREA_TO_MAP[pointArea] then ref = { pp[2], pp[3] } end
    end

    if override then
      local x, y, a = override.x, override.y, override.area or area
      table.insert(s.goals, 1, gotoLine(a, x, y))
    elseif not merge then
      local x, y = hotspot(points, nil, ref)
      if x and area and pointArea ~= area then
        warn(("quest %d %s: objectives found outside the route area (%s)"):format(id, q[Q_NAME], tostring(pointArea)))
      end
      if x then
        table.insert(s.goals, 1, gotoLine(pointArea, x, y))
      else
        warn(("no location found for quest %d %s"):format(id, q[Q_NAME]))
      end
    end
    for _, l in ipairs(lines) do s.goals[#s.goals + 1] = l end
  end

  local lineNo = 0
  for raw in io.lines(path) do
    lineNo = lineNo + 1
    ctx.line = lineNo
    local line = raw:gsub("%s+$", ""):gsub("^%s+", "")
    if line ~= "" and not line:match("^%-%-") and not line:match("^#") then
      local cmd, rest = line:match("^(%S+)%s*(.*)$")
      if cmd == "guide" or cmd == "faction" or cmd == "levels" or cmd == "next" or cmd == "author"
        or cmd == "description" or cmd == "race" or cmd == "category" or cmd == "loop" then
        header[#header + 1] = line
        if cmd == "faction" then routeFaction = rest end
        if cmd == "levels" then
          level = tonumber(rest:match("^(%d+)"))
        end
      elseif cmd == "area" then
        area = tonumber(rest)
        if not AREA_TO_MAP[area] then err("unknown area " .. rest) end
        map = AREA_TO_MAP[area]
      elseif cmd == "accept" or cmd == "turnin" then
        local id, giver = rest:match("^(%d+)%s*(%d*)")
        questGiver(cmd, tonumber(id), tonumber(giver))
      elseif cmd == "do" or cmd == "+do" then
        local id, x, y = rest:match("^(%d+)%s*@?%s*([%d%.]*),?([%d%.]*)")
        local override = (x ~= "" and y ~= "") and { x = tonumber(x), y = tonumber(y) } or nil
        doQuest(tonumber(id), override, cmd == "+do")
      elseif cmd == "only" then
        pendingOnly = rest
      elseif cmd == "gather" or cmd == "farm" then
        -- gather <area> <waypoints> <objectID,...> <note text> [|fr ...]
        -- farm   <area> <waypoints> <npcID,...>    <note text> [|fr ...]
        local a, n, ids, note = rest:match("^(%d+)%s+(%d+)%s+([%d,]+)%s*(.*)$")
        if not a then err("expected: " .. cmd .. " <area> <waypoints> <ids> <note>")
        else
          a, n = tonumber(a), tonumber(n)
          local pts = {}
          for id in ids:gmatch("%d+") do
            local src = cmd == "gather" and objects[tonumber(id)] or npcs[tonumber(id)]
            local sp = src and src[cmd == "gather" and O_SPAWNS or N_SPAWNS]
            if not src then err("unknown " .. (cmd == "gather" and "object " or "NPC ") .. id)
            elseif not (sp and sp[a]) then err(id .. " has no spawn in area " .. a)
            else for _, p in ipairs(sp[a]) do pts[#pts + 1] = p end end
          end
          local prev = curStep() and lastPosOf(curStep())
          for _, c in ipairs(circuit(pts, n, prev and { prev[2], prev[3] })) do
            local st = newStep("other")
            st.goals[#st.goals + 1] = gotoLine(a, c[1], c[2]) .. " |r 30"
            if note ~= "" then st.goals[#st.goals + 1] = "note " .. note end
          end
        end
      elseif cmd == "lvl" then
        -- expected level at this point of the route (no step emitted)
        level = tonumber(rest)
      elseif cmd == "level" then
        local s = newStep("level")
        level = tonumber(rest)
        s.goals[#s.goals + 1] = "level " .. rest
      elseif cmd == "step" then
        newStep("other")
      elseif cmd == "goto" then
        -- goto x,y            (current area)
        -- goto <area> x,y
        local a, x, y = rest:match("^(%d+)%s+([%d%.]+),([%d%.]+)$")
        if not a then x, y = rest:match("^([%d%.]+),([%d%.]+)$"); a = area end
        local s = curStep()
        if not s or s.kind ~= "other" or #s.goals > 0 then s = newStep("other") end
        s.goals[#s.goals + 1] = gotoLine(tonumber(a), tonumber(x), tonumber(y))
      elseif cmd == "+" then
        -- raw goal line appended to the current step
        local s = curStep() or newStep("other")
        s.goals[#s.goals + 1] = rest
        if s.items then
          s.extra = s.extra or {}
          table.insert(s.extra, { line = rest, after = #s.items })
        end
      elseif cmd == "talk" then
        local id = tonumber(rest:match("^(%d+)"))
        if not id or not npcs[id] then err("unknown NPC " .. rest)
        else
          local s = newStep("talk", id)
          local a, x, y = npcLocation(id, area)
          if a then s.goals[#s.goals + 1] = gotoLine(a, x, y) end
          s.goals[#s.goals + 1] = talkLine(id)
          s.head = {}
          for _, g in ipairs(s.goals) do s.head[#s.head + 1] = g end
          s.items = {}
        end
      elseif cmd == "home" or cmd == "fpath" or cmd == "fly" or cmd == "hearth" or cmd == "train" or cmd == "note"
        or cmd == "use" or cmd == "buy" or cmd == "gold" or cmd == "item" or cmd == "rep" or cmd == "achieve" then
        -- action lines: placed in the current step if it is an "other" step that
        -- only holds a goto, else in a new step
        -- action lines join the current NPC/travel step (e.g. "home" right after
        -- talking to the innkeeper), otherwise they start a new step
        local s = curStep()
        if not (s and (s.kind == "other" or s.kind == "npc" or s.kind == "talk")) or pendingOnly then
          s = newStep("other")
        end
        s.goals[#s.goals + 1] = line
        if s.items then
          s.extra = s.extra or {}
          table.insert(s.extra, { line = line, after = #s.items })
        end
      else
        err("unknown route command " .. cmd)
      end
    end
  end

  steps = optimizeVisits(steps, path)

  -- emit
  out[#out + 1] = "-- Generated by tools/build_guides.lua from " .. path .. ". Do not edit by hand."
  out[#out + 1] = "Freegor:RegisterGuide([["
  for _, h in ipairs(header) do out[#out + 1] = h end
  if map then out[#out + 1] = "zone " .. map end
  for _, s in ipairs(steps) do
    if #s.goals > 0 then
      out[#out + 1] = "step"
      if s.only then out[#out + 1] = "  only " .. s.only end
      for _, g in ipairs(s.goals) do out[#out + 1] = "  " .. g end
    end
  end
  out[#out + 1] = "]])"
  state.level = level
  return table.concat(out, "\n") .. "\n"
end

---------------------------------------------------------------------------
-- Main: routes are built in the order listed in tools/routes/ORDER
---------------------------------------------------------------------------

local ROUTES = "tools/routes/"
local OUT = "FreegorGuide/Guides/"
local tocFiles = {}
local state = { accepted = {}, done = {}, level = 1 }
local chains = {} -- name -> state (each starting area has its own quest state)

for line in io.lines(ROUTES .. "ORDER") do
  local spec, name = line:match("^(%S+)%s+(%S+)$")
  if spec and not spec:match("^#") then
    -- "main<human,dwarf,nelf": the chain starts with the quests done by those chains
    local chain, parents = spec:match("^([^<]+)<?(.*)$")
    if not chains[chain] then
      chains[chain] = { accepted = {}, done = {}, level = 1 }
      for parent in parents:gmatch("[^,]+") do
        local st = chains[parent] or error("unknown chain " .. parent .. " in ORDER")
        st.isParent = true
        for k in pairs(st.done) do chains[chain].done[k] = true end
        for k in pairs(st.accepted) do chains[chain].accepted[k] = true end
      end
    end
    local text = buildRoute(ROUTES .. name .. ".route", chains[chain])
    local f = assert(io.open(OUT .. name .. ".lua", "wb"))
    f:write(text)
    f:close()
    tocFiles[#tocFiles + 1] = "Guides\\" .. name .. ".lua"
  end
end

-- Quests taken but never turned in by any guide of the chain
local reported = {}
for name, st in pairs(chains) do
  local openList = {}
  if st.isParent then st = { accepted = {}, done = {} } end -- checked through the chains that continue it
  for id in pairs(st.accepted) do
    if not st.done[id] and not reported[id] then
      reported[id] = true
      openList[#openList + 1] = ("%d %s"):format(id, quests[id] and quests[id][Q_NAME] or "?")
    end
  end
  table.sort(openList)
  for _, q in ipairs(openList) do notes[#notes + 1] = ("chain %s: quest %s is never turned in"):format(name, q) end
end
for _, n in ipairs(notes) do io.stderr:write("note: " .. n .. "\n") end
for _, w in ipairs(warnings) do io.stderr:write("warning: " .. w .. "\n") end
for _, e in ipairs(errors) do io.stderr:write("ERROR: " .. e .. "\n") end
print(("%d guides, %d warnings, %d errors"):format(#tocFiles, #warnings, #errors))
print("TOC entries:")
for _, t in ipairs(tocFiles) do print(t) end
os.exit(#errors == 0 and 0 or 1)
