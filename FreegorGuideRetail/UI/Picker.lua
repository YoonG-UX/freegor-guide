local _, ns = ...
local L = ns.L
local Engine = ns.Engine
local C = ns.Compat

-- Guide menu: categories on the left (what to track), guides of the selected
-- category on the right. Mouse wheel scrolls the guide list.

local CATEGORIES = {
  { key = "leveling",     icon = "Interface\\Icons\\INV_Misc_Book_09" },
  { key = "professions",  icon = "Interface\\Icons\\Trade_BlackSmithing" },
  { key = "mounts",       icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
  { key = "gold",         icon = "Interface\\Icons\\INV_Misc_Coin_02" },
  { key = "reputation",   icon = "Interface\\Icons\\INV_Fabric_Wool_01" },
  { key = "achievements", icon = "Interface\\Icons\\INV_Misc_Map_01" },
}
ns.CATEGORIES = CATEGORIES

local WIDTH, HEIGHT, CAT_W = 480, 360, 150
local ROWS, ROW_H = 14, 21

local backdrop = BackdropTemplateMixin and "BackdropTemplate" or nil
local P = CreateFrame("Frame", "FreegorPicker", UIParent, backdrop)
ns.Picker = P
P:SetSize(WIDTH, HEIGHT)
P:SetFrameStrata("DIALOG")
P:EnableMouse(true)
P:EnableMouseWheel(true)
P:SetMovable(true)
P:RegisterForDrag("LeftButton")
P:SetClampedToScreen(true)
P:SetScript("OnDragStart", P.StartMoving)
P:SetScript("OnDragStop", P.StopMovingOrSizing)
if P.SetBackdrop then
  P:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
end
P:Hide()
tinsert(UISpecialFrames, "FreegorPicker") -- close with Escape

local header = P:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
header:SetPoint("TOPLEFT", 12, -10)
header:SetText(L.MENU_TITLE)

local close = CreateFrame("Button", nil, P, "UIPanelCloseButton")
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", 0, 0)

local current = P:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
current:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
current:SetPoint("RIGHT", -12, 0)
current:SetJustifyH("LEFT")

-- Category buttons --------------------------------------------------------

local selected = "leveling"
local offset = 0
local catButtons = {}

for i, cat in ipairs(CATEGORIES) do
  local b = CreateFrame("Button", nil, P)
  b:SetSize(CAT_W - 12, 30)
  b:SetPoint("TOPLEFT", 10, -48 - (i - 1) * 34)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(24, 24)
  b.icon:SetPoint("LEFT", 2, 0)
  b.icon:SetTexture(cat.icon)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.text:SetPoint("RIGHT", -2, 0)
  b.text:SetJustifyH("LEFT")
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints()
  b.sel:SetColorTexture(0.2, 0.6, 0.9, 0.25)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.key = cat.key
  b:SetScript("OnClick", function(self)
    selected = self.key
    offset = 0
    P:Render()
  end)
  catButtons[i] = b
end

local catHint = P:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
catHint:SetPoint("BOTTOMLEFT", 12, 12)
catHint:SetWidth(CAT_W - 16)
catHint:SetJustifyH("LEFT")

-- Guide rows ----------------------------------------------------------------

local divider = P:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 1, 1, 0.15)
divider:SetSize(1, HEIGHT - 60)
divider:SetPoint("TOPLEFT", CAT_W, -46)

local empty = P:CreateFontString(nil, "OVERLAY", "GameFontDisable")
empty:SetPoint("TOPLEFT", CAT_W + 12, -56)
empty:SetPoint("RIGHT", -12, 0)
empty:SetJustifyH("LEFT")

local rows = {}
for i = 1, ROWS do
  local b = CreateFrame("Button", nil, P)
  b:SetHeight(ROW_H)
  b:SetPoint("TOPLEFT", CAT_W + 8, -48 - (i - 1) * ROW_H)
  b:SetPoint("RIGHT", -10, 0)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", 4, 0)
  b.text:SetPoint("RIGHT", -90, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  b.info = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.info:SetPoint("RIGHT", -4, 0)
  b:SetScript("OnClick", function(self)
    if self.guide and Engine:LoadGuide(self.guide.title) then
      ns.Print(L.LOADED_FMT, self.guide.title)
      P:Hide()
      ns.SetShown(true)
    end
  end)
  b:SetScript("OnEnter", function(self)
    local g = self.guide
    if not g then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(g.title, 1, 1, 1)
    if g.minLevel then GameTooltip:AddLine(L.LEVELS_FMT:format(g.minLevel, g.maxLevel), 0.8, 0.8, 0.8) end
    if g.description then GameTooltip:AddLine(g.description, 1, 0.82, 0, true) end
    GameTooltip:AddLine(L.STEPS_FMT:format(#g.steps), 0.6, 0.6, 0.6)
    if g.loop then GameTooltip:AddLine(L.LOOP_HINT, 0.6, 0.8, 1, true) end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rows[i] = b
end

local visible = {}

local function guidesFor(category, race, faction)
  local out = {}
  for _, g in ipairs(ns.Freegor:GetGuides()) do
    local factionOK = not g.faction or g.faction == "" or g.faction == faction or g.faction == "Neutral"
    if g.category == category and factionOK and ns.Parser.GuideForRace(g, race) then
      out[#out + 1] = g
    end
  end
  return out
end

function P:Render()
  local _, race, faction, level = C.PlayerInfo()
  current:SetText(Engine.guide and L.CURRENT_FMT:format(Engine.guide.title) or "")

  -- Only categories that have guides for this character are listed.
  local shown = 0
  local selectedVisible = false
  for i, cat in ipairs(CATEGORIES) do
    local b = catButtons[i]
    local n = #guidesFor(cat.key, race, faction)
    if n > 0 then
      shown = shown + 1
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 10, -48 - (shown - 1) * 34)
      b.text:SetText(("%s |cff888888(%d)|r"):format(L["CAT_" .. cat.key], n))
      b:Show()
      if cat.key == selected then selectedVisible = true end
    else
      b:Hide()
    end
  end
  if not selectedVisible then
    for i, cat in ipairs(CATEGORIES) do
      if catButtons[i]:IsShown() then selected = cat.key break end
    end
  end
  for i, cat in ipairs(CATEGORIES) do catButtons[i].sel:SetShown(cat.key == selected) end
  catHint:SetText(selected == "achievements" and not C.HasAchievements() and L.NO_ACHIEVEMENTS or "")

  visible = guidesFor(selected, race, faction)
  if selected == "leveling" then
    -- Guides suited to the player's level first, then by minimum level.
    table.sort(visible, function(a, b)
      local fa = (a.minLevel or 0) <= level and level <= (a.maxLevel or 999)
      local fb = (b.minLevel or 0) <= level and level <= (b.maxLevel or 999)
      if fa ~= fb then return fa end
      return (a.minLevel or 0) < (b.minLevel or 0)
    end)
  end
  empty:SetText(#visible == 0 and L.NO_GUIDES_IN_CAT or "")

  offset = math.max(0, math.min(offset, #visible - ROWS))
  local savedSteps = ns.cdb and ns.cdb.steps or {}
  for i, b in ipairs(rows) do
    local g = visible[i + offset]
    b.guide = g
    if g then
      local active = Engine.guide == g
      b.text:SetText((active and "|cff33ccff> |r" or "") .. g.title)
      local s = savedSteps[g.title]
      if s and s > 1 then
        b.info:SetText(L.PROGRESS_FMT:format(math.min(s, #g.steps), #g.steps))
      elseif g.minLevel then
        local color = level < g.minLevel and "|cffff8040" or ""
        b.info:SetText(color .. L.LEVELS_FMT:format(g.minLevel, g.maxLevel))
      else
        b.info:SetText("")
      end
      b:Show()
    else
      b:Hide()
    end
  end
end

P:SetScript("OnMouseWheel", function(self, delta)
  offset = offset - delta
  self:Render()
end)

function P:Toggle()
  if self:IsShown() then return self:Hide() end
  if Engine.guide and Engine.guide.category then selected = Engine.guide.category end
  self:ClearAllPoints()
  self:SetPoint("CENTER")
  offset = 0
  self:Render()
  self:Show()
end

---------------------------------------------------------------------------
-- Minimap button: left click opens the menu, right click shows/hides the guide.
---------------------------------------------------------------------------

local mm = CreateFrame("Button", "FreegorMinimapButton", Minimap)
ns.MinimapButton = mm
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mmIcon = mm:CreateTexture(nil, "BACKGROUND")
mmIcon:SetSize(20, 20)
mmIcon:SetPoint("CENTER", 0, 1)
mmIcon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(53, 53)
mmBorder:SetPoint("TOPLEFT")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function placeMinimapButton()
  local angle = math.rad(ns.db and ns.db.minimapAngle or 210)
  local r = (Minimap:GetWidth() / 2) + 10
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

mm:SetScript("OnClick", function(_, button)
  if button == "RightButton" then
    ns.SetShown(not ns.Viewer:IsShown())
  else
    P:Toggle()
  end
end)
mm:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    placeMinimapButton()
  end)
end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mm:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(L.ADDON_NAME)
  GameTooltip:AddLine(L.MINIMAP_HINT, 0.8, 0.8, 0.8, true)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

ns.On("INIT", function()
  placeMinimapButton()
  mm:SetShown(ns.db.minimapButton ~= false)
end)
