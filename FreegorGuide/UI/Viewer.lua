local _, ns = ...
local L = ns.L
local Engine = ns.Engine

-- Main guide window: current step, its goals with live progress, navigation.

local WIDTH, LINE_H, MAX_LINES = 330, 20, 16

local backdrop = BackdropTemplateMixin and "BackdropTemplate" or nil
local V = CreateFrame("Frame", "FreegorViewer", UIParent, backdrop)
ns.Viewer = V
V:SetSize(WIDTH, 120)
V:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
V:SetMovable(true)
V:EnableMouse(true)
V:RegisterForDrag("LeftButton")
V:SetClampedToScreen(true)
V:SetFrameStrata("MEDIUM")
if V.SetBackdrop then
  V:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  V:SetBackdropColor(0.05, 0.05, 0.08, 0.85)
  V:SetBackdropBorderColor(0.2, 0.6, 0.9, 0.9)
end
V:Hide()

V:SetScript("OnDragStart", V.StartMoving)
V:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, rel, x, y = self:GetPoint()
  ns.db.viewerPos = { point, rel, x, y }
end)

-- Header ------------------------------------------------------------------

local function iconButton(parent, texture, tooltip, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(20, 20)
  b:SetNormalTexture(texture)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(tooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local close = CreateFrame("Button", nil, V, "UIPanelCloseButton")
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", 0, 0)
close:SetScript("OnClick", function() ns.SetShown(false) end)

local nextBtn = iconButton(V, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", L.NEXT, function() Engine:Next() end)
nextBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
local prevBtn = iconButton(V, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", L.PREV, function() Engine:Prev() end)
prevBtn:SetPoint("RIGHT", nextBtn, "LEFT", -2, 0)
local bookBtn = iconButton(V, "Interface\\Icons\\INV_Misc_Book_09", L.CHOOSE_GUIDE, function() ns.Picker:Toggle() end)
bookBtn:SetPoint("RIGHT", prevBtn, "LEFT", -4, 0)

local title = V:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 10, -8)
title:SetPoint("RIGHT", bookBtn, "LEFT", -6, 0)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local stepText = V:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
stepText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)

-- Goal lines ----------------------------------------------------------------

local ICONS = {
  done    = "Interface\\RaidFrame\\ReadyCheck-Ready",
  accept  = "Interface\\GossipFrame\\AvailableQuestIcon",
  turnin  = "Interface\\GossipFrame\\ActiveQuestIcon",
  ["do"]  = "Interface\\GossipFrame\\ActiveQuestIcon",
  kill    = "Interface\\Icons\\Ability_DualWield",
  collect = "Interface\\Icons\\INV_Misc_Bag_08",
  ["goto"] = "Interface\\Icons\\INV_Misc_Map_01",
  talk    = "Interface\\GossipFrame\\GossipGossipIcon",
  level   = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
  note    = "Interface\\Icons\\INV_Misc_Note_01",
  home    = "Interface\\Icons\\INV_Misc_Rune_01",
  hearth  = "Interface\\Icons\\INV_Misc_Rune_01",
  fpath   = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
  fly     = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
  train   = "Interface\\Icons\\INV_Misc_Book_11",
  use     = "Interface\\Icons\\INV_Misc_Bag_08",
  buy     = "Interface\\Icons\\INV_Misc_Coin_01",
}

local lines = {}
for i = 1, MAX_LINES do
  local b = CreateFrame("Button", nil, V)
  b:SetHeight(LINE_H)
  b:SetPoint("TOPLEFT", 10, -36 - (i - 1) * LINE_H)
  b:SetPoint("RIGHT", V, "RIGHT", -10, 0)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(16, 16)
  b.icon:SetPoint("LEFT")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.text:SetPoint("RIGHT", -40, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  b.prog = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.prog:SetPoint("RIGHT")
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b:SetScript("OnClick", function(self)
    if self.goal and self.goal.type == "goto" then
      Engine.manualWaypoint = true
      Engine:SetWaypointFromGoal(self.goal)
    end
  end)
  b:SetScript("OnEnter", function(self)
    if not self.text:IsTruncated() then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(self.text:GetText(), 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b:Hide()
  lines[i] = b
end

local hint = V:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetJustifyH("LEFT")
hint:SetPoint("LEFT", 10, 0)
hint:SetPoint("RIGHT", -10, 0)

local nextGuideBtn = CreateFrame("Button", nil, V, "UIPanelButtonTemplate")
nextGuideBtn:SetSize(180, 22)
nextGuideBtn:SetText(L.LOAD_NEXT)
nextGuideBtn:Hide()
nextGuideBtn:SetScript("OnClick", function()
  local g = Engine.guide
  if g and g.next then Engine:LoadGuide(g.next) end
end)

-- Rendering -----------------------------------------------------------------

local function layoutFooter(used)
  local y = -36 - used * LINE_H - 4
  hint:ClearAllPoints()
  hint:SetPoint("TOPLEFT", 10, y)
  hint:SetPoint("RIGHT", -10, 0)
  local h = -y + (hint:GetText() and hint:GetText() ~= "" and 16 or 0)
  if nextGuideBtn:IsShown() then
    nextGuideBtn:ClearAllPoints()
    nextGuideBtn:SetPoint("TOP", V, "TOPLEFT", WIDTH / 2, -h - 2)
    h = h + 28
  end
  V:SetHeight(h + 8)
end

function V:Render()
  for _, b in ipairs(lines) do b:Hide() end
  nextGuideBtn:Hide()
  hint:SetText("")

  local g = Engine.guide
  if not g then
    title:SetText(L.ADDON_NAME)
    stepText:SetText("")
    hint:SetText(L.NO_GUIDE)
    return layoutFooter(0)
  end

  title:SetText(g.title)
  local total = #g.steps
  local step = Engine:CurrentStep()

  if not step then
    stepText:SetText(L.STEP_FMT:format(total, total))
    hint:SetText(L.GUIDE_DONE .. (g.next and ("  " .. L.NEXT_GUIDE:format(g.next)) or ""))
    if g.next and ns.guides[g.next] then nextGuideBtn:Show() end
    return layoutFooter(0)
  end

  stepText:SetText(L.STEP_FMT:format(Engine.stepIndex, total))
  local used = 0
  for _, goal in ipairs(step.goals) do
    if used >= MAX_LINES then break end
    used = used + 1
    local b = lines[used]
    local status, prog = Engine:GoalStatus(goal)
    b.goal = goal
    b.text:SetText(ns.GoalText(goal))
    b.prog:SetText(prog or "")
    if status == "done" then
      b.icon:SetTexture(ICONS.done)
      b.text:SetTextColor(0.5, 0.5, 0.5)
    else
      b.icon:SetTexture(ICONS[goal.type] or ICONS.note)
      if goal.type == "note" then b.text:SetTextColor(0.9, 0.85, 0.6) else b.text:SetTextColor(1, 1, 1) end
    end
    b:Show()
  end
  if Engine:IsManualStep(step) then hint:SetText(L.MANUAL_HINT) end
  layoutFooter(used)
end

ns.On("REFRESH", function() if V:IsShown() then V:Render() end end)
ns.On("STEP_CHANGED", function() if V:IsShown() then V:Render() end end)
ns.On("GUIDE_LOADED", function() if V:IsShown() then V:Render() end end)
V:SetScript("OnShow", function(self) self:Render() end)

function ns.SetShown(shown)
  ns.db.shown = shown
  V:SetShown(shown)
  if shown then ns.Arrow:UpdateVisibility() else ns.Arrow:Hide() end
end

ns.On("INIT", function()
  local p = ns.db.viewerPos
  if p then
    V:ClearAllPoints()
    V:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
  V:SetShown(ns.db.shown)
  if not ns.db.shown then ns.Arrow:Hide() end
end)
