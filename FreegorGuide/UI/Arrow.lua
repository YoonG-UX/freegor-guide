local _, ns = ...
local L = ns.L
local C = ns.Compat
local Engine = ns.Engine

-- Waypoint arrow: points toward the current step's destination.
-- If TomTom is installed, the waypoint is also sent to TomTom.

local Arrow = CreateFrame("Frame", "FreegorArrow", UIParent)
ns.Arrow = Arrow
Arrow:SetSize(64, 64)
Arrow:SetPoint("TOP", UIParent, "TOP", 0, -120)
Arrow:SetMovable(true)
Arrow:EnableMouse(true)
Arrow:RegisterForDrag("LeftButton")
Arrow:SetClampedToScreen(true)
Arrow:Hide()

local tex = Arrow:CreateTexture(nil, "ARTWORK")
tex:SetTexture("Interface\\Minimap\\MinimapArrow")
tex:SetAllPoints()

local label = Arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOP", Arrow, "BOTTOM", 0, 2)
label:SetWidth(220)

local dist = Arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dist:SetPoint("TOP", label, "BOTTOM", 0, -2)

Arrow:SetScript("OnDragStart", Arrow.StartMoving)
Arrow:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, rel, x, y = self:GetPoint()
  ns.db.arrowPos = { point, rel, x, y }
end)

-- Red when the target is behind, green when straight ahead.
local function colorFor(rel)
  local a = math.abs(((rel + math.pi) % (2 * math.pi)) - math.pi) / math.pi -- 0 ahead .. 1 behind
  if a < 0.5 then return a * 2, 1, 0 end
  return 1, 2 - a * 2, 0
end

local elapsed = 0
Arrow:SetScript("OnUpdate", function(self, e)
  elapsed = elapsed + e
  if elapsed < 0.05 then return end
  elapsed = 0
  local d, rel = Engine:WaypointVector()
  if d then
    if rel then
      tex:SetRotation(rel)
      tex:SetVertexColor(colorFor(rel))
    end
    tex:Show()
    dist:SetText(L.YARDS_FMT:format(d))
  else
    -- Destination on another continent or position unavailable (instances).
    tex:Hide()
    local wp = Engine.waypoint
    dist:SetText(wp and L.OTHER_ZONE:format(C.GetMapName(wp.mapID) or "?") or "")
  end
end)

function Arrow:UpdateVisibility()
  if Engine.waypoint and ns.db.arrowShown and ns.db.shown then self:Show() else self:Hide() end
end

-- TomTom bridge
local tomtomUID
local function updateTomTom(wp)
  local TomTom = _G.TomTom
  if not (TomTom and TomTom.AddWaypoint) then return end
  if tomtomUID and TomTom.RemoveWaypoint then
    pcall(TomTom.RemoveWaypoint, TomTom, tomtomUID)
    tomtomUID = nil
  end
  if wp and ns.db.useTomTom then
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, wp.mapID, wp.x, wp.y, {
      title = wp.title or "Freegor", persistent = false, minimap = true, world = true,
    })
    if ok then tomtomUID = uid end
  end
end

ns.On("WAYPOINT", function(wp)
  label:SetText(wp and wp.title or "")
  updateTomTom(wp)
  Arrow:UpdateVisibility()
end)

ns.On("INIT", function()
  local p = ns.db.arrowPos
  if p then
    Arrow:ClearAllPoints()
    Arrow:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
  Arrow:UpdateVisibility()
end)
