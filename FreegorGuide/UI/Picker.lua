local _, ns = ...
local L = ns.L
local Engine = ns.Engine
local C = ns.Compat

-- Guide picker: lists registered guides for the player's faction.
-- Mouse wheel scrolls when there are more guides than rows.

local ROWS, ROW_H = 12, 20
local backdrop = BackdropTemplateMixin and "BackdropTemplate" or nil
local P = CreateFrame("Frame", "FreegorPicker", UIParent, backdrop)
ns.Picker = P
P:SetSize(300, 40 + ROWS * ROW_H)
P:SetFrameStrata("DIALOG")
P:EnableMouse(true)
P:EnableMouseWheel(true)
P:SetClampedToScreen(true)
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

local header = P:CreateFontString(nil, "OVERLAY", "GameFontNormal")
header:SetPoint("TOPLEFT", 10, -10)
header:SetText(L.CHOOSE_GUIDE)

local close = CreateFrame("Button", nil, P, "UIPanelCloseButton")
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", 0, 0)

local offset = 0
local visible = {}

local rows = {}
for i = 1, ROWS do
  local b = CreateFrame("Button", nil, P)
  b:SetHeight(ROW_H)
  b:SetPoint("TOPLEFT", 10, -30 - (i - 1) * ROW_H)
  b:SetPoint("RIGHT", -10, 0)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", 4, 0)
  b.text:SetJustifyH("LEFT")
  b.levels = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  b.levels:SetPoint("RIGHT", -4, 0)
  b:SetScript("OnClick", function(self)
    if self.guide and Engine:LoadGuide(self.guide.title) then
      ns.Print(L.LOADED_FMT, self.guide.title)
      P:Hide()
      ns.SetShown(true)
    end
  end)
  rows[i] = b
end

function P:Render()
  local _, race, faction, level = C.PlayerInfo()
  wipe(visible)
  for _, g in ipairs(ns.Freegor:GetGuides()) do
    local factionOK = not g.faction or g.faction == "" or g.faction == faction or g.faction == "Neutral"
    if factionOK and ns.Parser.GuideForRace(g, race) then
      visible[#visible + 1] = g
    end
  end
  -- Guides suited to the player's level first, then by minimum level.
  table.sort(visible, function(a, b)
    local fa = (a.minLevel or 0) <= level and level <= (a.maxLevel or 999)
    local fb = (b.minLevel or 0) <= level and level <= (b.maxLevel or 999)
    if fa ~= fb then return fa end
    return (a.minLevel or 0) < (b.minLevel or 0)
  end)
  offset = math.max(0, math.min(offset, #visible - ROWS))
  for i, b in ipairs(rows) do
    local g = visible[i + offset]
    b.guide = g
    if g then
      local active = Engine.guide == g
      b.text:SetText((active and "|cff33ccff> |r" or "") .. g.title)
      b.levels:SetText(g.minLevel and L.LEVELS_FMT:format(g.minLevel, g.maxLevel) or "")
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
  self:ClearAllPoints()
  if ns.Viewer:IsShown() then
    self:SetPoint("TOPRIGHT", ns.Viewer, "TOPLEFT", -6, 0)
  else
    self:SetPoint("CENTER")
  end
  offset = 0
  self:Render()
  self:Show()
end
