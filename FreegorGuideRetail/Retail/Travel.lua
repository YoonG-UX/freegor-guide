local _, ns = ...
local L = ns.L
local R = ns.Retail
local C = ns.Compat

-- Travel between continents with the game's own portal network
-- (Retail/Data/Travel.lua). The shortest route mixes walking on a continent
-- (straight-line distance) and portals; nodes and portals the character cannot
-- use (other faction, level, quests, achievements) are left out. Each portal of
-- the route becomes a guide step: go to the portal, take it.

local PORTAL_COST = 60 -- a portal "costs" this many yards of walking

local function condOK(cid)
  local c = cid and R.TravelConds and R.TravelConds[cid]
  if not c then return true end
  local faction = UnitFactionGroup("player")
  if c.f == "A" and faction ~= "Alliance" then return false end
  if c.f == "H" and faction ~= "Horde" then return false end
  if c.lvl and UnitLevel("player") < c.lvl then return false end
  for _, q in ipairs(c.q or {}) do if not C.IsQuestCompleted(q) then return false end end
  for _, q in ipairs(c.cq or {}) do if not C.IsOnQuest(q) then return false end end
  for _, a in ipairs(c.ach or {}) do
    if not (GetAchievementInfo and select(4, GetAchievementInfo(a))) then return false end
  end
  return true
end
R.TravelCondOK = condOK

local function dist(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

-- Route from the player to a world position. Returns a list of edges
-- { from = nodeID, to = nodeID }, an empty list when no portal is needed, or
-- nil when no route is known.
function R.FindRoute(destCont, destX, destY)
  local nodes, edges = R.TravelNodes or {}, R.TravelEdges or {}
  local pc, px, py = C.GetPlayerWorld()
  if not pc or not destCont then return nil end
  if pc == destCont then return {} end

  local usable, out = {}, {}
  for id, n in pairs(nodes) do usable[id] = condOK(n[5]) end
  for _, e in ipairs(edges) do
    if usable[e[1]] and usable[e[2]] and condOK(e[3]) then
      out[e[1]] = out[e[1]] or {}
      table.insert(out[e[1]], e[2])
    end
  end

  -- Dijkstra over: "start", every usable node, "goal".
  local d, prev, prevEdge, done = { start = 0 }, {}, {}, {}
  local function pos(v)
    if v == "start" then return pc, px, py end
    local n = nodes[v]
    return n[1], n[2], n[3]
  end
  local function relax(u, v, cost, viaPortal)
    local nd = d[u] + cost
    if d[v] == nil or nd < d[v] then
      d[v], prev[v], prevEdge[v] = nd, u, viaPortal
    end
  end
  while true do
    local u, best
    for v, dv in pairs(d) do
      if not done[v] and (best == nil or dv < best) then u, best = v, dv end
    end
    if not u then return nil end
    if u == "goal" then break end
    done[u] = true
    local cont, x, y = pos(u)
    -- walk to the destination, or to portals and building doors on this continent
    if cont == destCont then relax(u, "goal", dist(x, y, destX, destY), false) end
    for id, n in pairs(nodes) do
      if usable[id] and n[1] == cont and n[4] ~= 2 and not done[id] and out[id] then
        relax(u, id, dist(x, y, n[2], n[3]), false)
      end
    end
    -- take a portal
    if u ~= "start" then
      for _, to in ipairs(out[u] or {}) do relax(u, to, PORTAL_COST, true) end
    end
  end

  local route, v = {}, "goal"
  while prev[v] do
    if prevEdge[v] then table.insert(route, 1, { from = prev[v], to = v }) end
    v = prev[v]
  end
  return route
end

local isFrench = GetLocale() == "frFR"
local function nodeName(id)
  local n = R.TravelNodes[id]
  return ((isFrench and n[7]) or n[6] or ""):gsub("[|\n]", " ")
end

-- World position -> zone map and coordinates (for the arrow).
local function toMap(cont, x, y)
  if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  local ok, mapID, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(x, y))
  if not ok or not mapID or not pos then return nil end
  local mx, my = pos:GetXY()
  return mapID, mx, my
end

-- Guide steps to reach a zone map position from where the player stands.
function R.TravelSteps(destMap, destX, destY)
  local cont, wx, wy = C.MapToWorld(destMap, destX, destY)
  local route = R.FindRoute(cont, wx, wy)
  if not route then return {} end
  local steps = {}
  for i, hop in ipairs(route) do
    local a, b = R.TravelNodes[hop.from], R.TravelNodes[hop.to]
    local lines = { "step", (" key travel:%d:%d"):format(hop.from, hop.to) }
    local mapID, mx, my = toMap(a[1], a[2], a[3])
    if mapID then lines[#lines + 1] = (" goto %d %.1f,%.1f |r 8"):format(mapID, mx * 100, my * 100) end
    lines[#lines + 1] = " note " .. L.TRAVEL_TAKE:format(nodeName(hop.from))
    if b[1] ~= a[1] then
      lines[#lines + 1] = (" reach %d %s"):format(b[1], nodeName(hop.to))
    end
    if i == #route then lines[#lines + 1] = " note " .. L.TRAVEL_LAST end
    steps[#steps + 1] = table.concat(lines, "\n")
  end
  return steps
end

-- reach <continentID> [name]: done once the player is on that continent (after the portal)
ns.Parser.RegisterGoal("reach", function(args)
  local id, name = args:match("^(%d+)%s*(.*)$")
  if not id then return nil, "expected: reach <continentID> [name]" end
  return { type = "reach", continent = tonumber(id), text = name ~= "" and name or nil }
end)
ns.GoalTypes.reach = {
  status = function(goal)
    local cont = C.GetPlayerWorld()
    return cont == goal.continent and "done" or "todo"
  end,
  text = function(goal, text) return L.GOAL_REACH:format(text or "?") end,
  icon = function() return "Interface\\Icons\\Spell_Arcane_PortalStormwind" end,
}
