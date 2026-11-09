local _, ns = ...
local R = ns.Retail
local Engine = ns.Engine

-- Navigation on Retail:
-- * every waypoint of the guide is also set as the game's own map pin and
--   super-tracked, so the in-world marker and the map show it;
-- * inside an instance, the arrow points to the boss of a "farm" step, from
--   the boss positions of the Encounter Journal.

local ourPin = false

local function setNativePin(wp)
  if ns.db and ns.db.nativeWaypoint == false then return end
  if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
  if wp and wp.mapID and C_Map.CanSetUserWaypointOnMap and C_Map.CanSetUserWaypointOnMap(wp.mapID) then
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(wp.mapID, wp.x, wp.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    ourPin = true
  elseif ourPin and C_Map.ClearUserWaypoint then
    C_Map.ClearUserWaypoint()
    ourPin = false
  end
end
R.SetNativePin = setNativePin

ns.On("WAYPOINT", setNativePin)

-- Boss position inside the current instance map, matched by name.
function R.BossPosition(mapID, journalInstanceID, boss)
  local EJ = C_EncounterJournal
  if not (EJ and EJ.GetEncountersOnMap and EJ.GetInstanceForGameMap and EJ_GetEncounterInfo and boss) then return nil end
  if EJ.GetInstanceForGameMap(mapID) ~= journalInstanceID then return nil end
  local want = boss:lower()
  for _, enc in ipairs(EJ.GetEncountersOnMap(mapID) or {}) do
    local name = EJ_GetEncounterInfo(enc.encounterID)
    local n = name and name:lower()
    if n and (n == want or n:find(want, 1, true) or want:find(n, 1, true)) then
      return enc.mapX, enc.mapY, name
    end
  end
  return nil
end

local function currentFarmGoal()
  local step = Engine:CurrentStep()
  for _, g in ipairs(step and step.goals or {}) do
    if g.type == "farm" and Engine:GoalStatus(g) ~= "done" then return g end
  end
end

function R.UpdateInstanceArrow()
  local goal = currentFarmGoal()
  local wp = Engine.waypoint
  if not goal then return end
  local inInstance = IsInInstance and IsInInstance()
  local mapID = ns.Compat.GetPlayerMap()
  if inInstance and mapID then
    local x, y, name = R.BossPosition(mapID, goal.instance, goal.boss)
    if x and not (wp and wp.custom and wp.mapID == mapID and wp.x == x and wp.y == y) then
      Engine:SetCustomWaypoint(mapID, x, y, name)
    end
  elseif wp and wp.custom then
    -- back outside: arrow to the instance entrance again
    Engine:SetWaypointFromGoal(Engine:ActiveGoto(Engine:CurrentStep()))
  end
end

for _, ev in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }) do
  ns.RegisterEvent(ev, function() C_Timer.After(1, R.UpdateInstanceArrow) end)
end
ns.On("STEP_CHANGED", function() R.UpdateInstanceArrow() end)
