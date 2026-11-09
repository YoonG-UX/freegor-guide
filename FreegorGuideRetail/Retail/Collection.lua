local _, ns = ...
local L = ns.L
local R = ns.Retail

-- Mount collection window: every mount of the journal with its 3D model, how
-- to get it (boss and reset, achievement progress, vendor...), and buttons to
-- guide to it, track it, summon it or link it.

local WIDTH, HEIGHT, LIST_W = 780, 520, 300
local ROWS, ROW_H = 19, 20

-- Source labels: the client's own (localized) ones when available.
local SOURCE_FALLBACK = {
  [1] = "Drop", [2] = "Quest", [3] = "Vendor", [4] = "Profession", [5] = "Pet Battle", [6] = "Achievement",
  [7] = "World Event", [8] = "Promotion", [9] = "Trading Card Game", [10] = "In-Game Shop",
  [11] = "Discovery", [12] = "Trading Post",
}
local function sourceLabel(n)
  return _G["BATTLE_PET_SOURCE_" .. tostring(n)] or SOURCE_FALLBACK[n] or ("#" .. tostring(n))
end
R.SourceLabel = sourceLabel

local backdrop = BackdropTemplateMixin and "BackdropTemplate" or nil
local W = CreateFrame("Frame", "FreegorMountCollection", UIParent, backdrop)
R.Collection = W
W:SetSize(WIDTH, HEIGHT)
W:SetPoint("CENTER")
W:SetFrameStrata("DIALOG")
W:EnableMouse(true)
W:SetMovable(true)
W:RegisterForDrag("LeftButton")
W:SetClampedToScreen(true)
W:SetScript("OnDragStart", W.StartMoving)
W:SetScript("OnDragStop", W.StopMovingOrSizing)
if W.SetBackdrop then
  W:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
end
W:Hide()
tinsert(UISpecialFrames, "FreegorMountCollection")

local title = W:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 14, -12)
title:SetText(L.COL_TITLE)
local stats = W:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
stats:SetPoint("LEFT", title, "RIGHT", 14, 0)
local close = CreateFrame("Button", nil, W, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 0, 0)

-- Progress bar under the title
local bar = CreateFrame("StatusBar", nil, W)
bar:SetPoint("TOPLEFT", 14, -36)
bar:SetSize(WIDTH - 28, 8)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.2, 0.7, 1)
bar:SetMinMaxValues(0, 1)
local barBg = bar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints()
barBg:SetColorTexture(0, 0, 0, 0.5)

-- Filters ----------------------------------------------------------------------

local state = { show = "missing", source = nil, search = "", offset = 0, selected = nil }

local search = CreateFrame("EditBox", nil, W, "InputBoxTemplate")
search:SetSize(LIST_W - 20, 20)
search:SetPoint("TOPLEFT", 22, -54)
search:SetAutoFocus(false)
search:SetScript("OnTextChanged", function(self)
  state.search = (self:GetText() or ""):lower()
  state.offset = 0
  W:Render()
end)
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchHint:SetPoint("LEFT", 4, 0)
searchHint:SetText(L.COL_SEARCH)

local function smallButton(text, w, onClick)
  local b = CreateFrame("Button", nil, W, "UIPanelButtonTemplate")
  b:SetSize(w, 20)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local showButtons = {}
for i, mode in ipairs({ { "all", L.COL_ALL }, { "missing", L.COL_MISSING }, { "owned", L.COL_OWNED } }) do
  local b = smallButton(mode[2], 92, function()
    state.show, state.offset = mode[1], 0
    W:Render()
  end)
  b:SetPoint("TOPLEFT", 14 + (i - 1) * 96, -80)
  b.mode = mode[1]
  showButtons[i] = b
end

local SOURCES = { 1, 2, 3, 4, 6, 7, 11, 12, 5, 8, 9, 10 }
local sourceButton = smallButton(L.COL_ANY_SOURCE, LIST_W - 12, function(self, button)
  -- cycle through the sources (right click goes back)
  local idx = 0
  for i, s in ipairs(SOURCES) do if s == state.source then idx = i end end
  idx = idx + (button == "RightButton" and -1 or 1)
  if idx > #SOURCES then idx = 0 elseif idx < 0 then idx = #SOURCES end
  state.source, state.offset = SOURCES[idx], 0
  W:Render()
end)
sourceButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
sourceButton:SetPoint("TOPLEFT", 14, -104)

-- List ---------------------------------------------------------------------------

local rows = {}
for i = 1, ROWS do
  local b = CreateFrame("Button", nil, W)
  b:SetSize(LIST_W - 12, ROW_H)
  b:SetPoint("TOPLEFT", 14, -130 - (i - 1) * ROW_H)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.sel = b:CreateTexture(nil, "BACKGROUND")
  b.sel:SetAllPoints()
  b.sel:SetColorTexture(0.2, 0.6, 0.9, 0.3)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(18, 18)
  b.icon:SetPoint("LEFT", 2, 0)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.text:SetPoint("RIGHT", -18, 0)
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  b.track = b:CreateTexture(nil, "OVERLAY")
  b.track:SetSize(14, 14)
  b.track:SetPoint("RIGHT", -2, 0)
  b.track:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  b:SetScript("OnClick", function(self)
    state.selected = self.mountID
    W:Render()
  end)
  rows[i] = b
end
local count = W:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
count:SetPoint("TOPLEFT", 16, -130 - ROWS * ROW_H - 4)

W:EnableMouseWheel(true)
W:SetScript("OnMouseWheel", function(self, delta)
  state.offset = state.offset - delta * 3
  self:Render()
end)

-- Details ------------------------------------------------------------------------

local detail = CreateFrame("Frame", nil, W)
detail:SetPoint("TOPLEFT", LIST_W + 16, -54)
detail:SetPoint("BOTTOMRIGHT", -14, 14)

local dIcon = detail:CreateTexture(nil, "ARTWORK")
dIcon:SetSize(40, 40)
dIcon:SetPoint("TOPLEFT")
local dName = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 8, -2)
dName:SetPoint("RIGHT")
dName:SetJustifyH("LEFT")
local dStatus = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dStatus:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -4)

local model = CreateFrame("PlayerModel", nil, detail)
model:SetPoint("TOPLEFT", dIcon, "BOTTOMLEFT", 0, -6)
model:SetSize(WIDTH - LIST_W - 30, 200)
model:EnableMouse(true)
model.facing = 0
model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
model:SetScript("OnUpdate", function(self)
  if self.dragX then
    local x = GetCursorPosition()
    self.facing = self.facing + (x - self.dragX) * 0.02
    self.dragX = x
    self:SetFacing(self.facing)
  end
end)
local modelBg = model:CreateTexture(nil, "BACKGROUND")
modelBg:SetAllPoints()
modelBg:SetColorTexture(0, 0, 0, 0.35)

local dDesc = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
dDesc:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 0, -6)
dDesc:SetPoint("RIGHT")
dDesc:SetJustifyH("LEFT")
dDesc:SetTextColor(0.8, 0.8, 0.8)

local dHowTitle = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dHowTitle:SetPoint("TOPLEFT", dDesc, "BOTTOMLEFT", 0, -8)
dHowTitle:SetText(L.COL_HOW)
local dHow = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dHow:SetPoint("TOPLEFT", dHowTitle, "BOTTOMLEFT", 0, -4)
dHow:SetPoint("RIGHT")
dHow:SetJustifyH("LEFT")
dHow:SetSpacing(2)

local guideBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
guideBtn:SetSize(120, 22)
guideBtn:SetPoint("BOTTOMLEFT")
guideBtn:SetText(L.COL_GUIDE)
guideBtn:SetScript("OnClick", function()
  if state.selected then R.GuideToMount(state.selected) end
end)
local trackBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
trackBtn:SetSize(120, 22)
trackBtn:SetPoint("LEFT", guideBtn, "RIGHT", 6, 0)
trackBtn:SetScript("OnClick", function()
  if state.selected then
    R.SetTracked(state.selected, not R.IsTracked(state.selected))
    W:Render()
  end
end)
local summonBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
summonBtn:SetSize(100, 22)
summonBtn:SetPoint("LEFT", trackBtn, "RIGHT", 6, 0)
summonBtn:SetText(L.COL_SUMMON)
summonBtn:SetScript("OnClick", function()
  if state.selected and C_MountJournal.SummonByID then C_MountJournal.SummonByID(state.selected) end
end)
local linkBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
linkBtn:SetSize(70, 22)
linkBtn:SetPoint("LEFT", summonBtn, "RIGHT", 6, 0)
linkBtn:SetText(L.COL_LINK)
linkBtn:SetScript("OnClick", function()
  local e = state.selected and R.MountEntry(state.selected)
  local link = e and C_MountJournal.GetMountLink and C_MountJournal.GetMountLink(e.spellID)
  if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
end)

-- Rendering ------------------------------------------------------------------------

local function filtered()
  local all = R.AllMounts()
  local list, owned = {}, 0
  for _, m in ipairs(all) do
    if m.collected then owned = owned + 1 end
    local okShow = state.show == "all" or (state.show == "owned") == (m.collected and true or false)
    local okSource = not state.source or m.sourceType == state.source
    local okSearch = state.search == "" or m.name:lower():find(state.search, 1, true)
    if okShow and okSource and okSearch then list[#list + 1] = m end
  end
  return list, owned, #all
end

local function howText(e)
  local lines = {}
  if e.raw ~= "" then lines[#lines + 1] = e.raw end
  if e.instance and e.boss then
    lines[#lines + 1] = L.COL_BOSS:format(e.boss, e.instance.name) .. "  " .. (e.killed and L.COL_KILLED or L.COL_AVAILABLE)
  end
  if e.entrance then
    local zone = ns.Compat.GetMapName(e.entrance.map) or ""
    lines[#lines + 1] = L.COL_ENTRANCE:format(zone, e.entrance.x * 100, e.entrance.y * 100)
  end
  if e.achievement then
    local _, name = GetAchievementInfo(e.achievement)
    lines[#lines + 1] = L.COL_ACH:format(name or "?", math.floor((e.achDone and 1 or e.achFrac or 0) * 100))
    if not e.achDone and e.achLeft and #e.achLeft > 0 then
      lines[#lines + 1] = L.ACH_LEFT:format(table.concat(e.achLeft, ", "))
    end
  end
  return table.concat(lines, "|n")
end

local function renderDetail(e)
  detail:SetShown(e ~= nil)
  if not e then return end
  dIcon:SetTexture(e.icon)
  dName:SetText(e.name)
  dStatus:SetText((e.collected and L.COL_COLLECTED or L.COL_NOT_COLLECTED) .. "  -  " .. sourceLabel(e.sourceType))
  local display = e.display
  if not display and C_MountJournal.GetMountAllCreatureDisplayInfoByID then
    local all = C_MountJournal.GetMountAllCreatureDisplayInfoByID(e.id)
    display = all and all[1] and all[1].creatureDisplayID
  end
  if display then
    model:SetDisplayInfo(display)
    model:SetFacing(model.facing)
    model:Show()
  else
    model:Hide()
  end
  dDesc:SetText(e.description or "")
  dHow:SetText(howText(e))
  guideBtn:SetEnabled(not e.collected)
  trackBtn:SetText(R.IsTracked(e.id) and L.COL_UNTRACK or L.COL_TRACK)
  trackBtn:SetEnabled(not e.collected)
  summonBtn:SetEnabled(e.collected and true or false)
end

function W:Render()
  if not self:IsShown() then return end
  R.ScanLockouts()
  local list, owned, total = filtered()
  stats:SetText(L.COL_STATS:format(owned, total, total > 0 and math.floor(owned * 100 / total) or 0))
  bar:SetValue(total > 0 and owned / total or 0)
  searchHint:SetShown(state.search == "")
  for _, b in ipairs(showButtons) do b:SetEnabled(b.mode ~= state.show) end
  sourceButton:SetText(state.source and sourceLabel(state.source) or L.COL_ANY_SOURCE)

  state.offset = math.max(0, math.min(state.offset, #list - ROWS))
  if not state.selected and list[1] then state.selected = list[1].id end
  for i, b in ipairs(rows) do
    local m = list[i + state.offset]
    b.mountID = m and m.id
    if m then
      b.icon:SetTexture(m.icon)
      b.icon:SetDesaturated(not m.collected)
      b.text:SetText(m.name)
      if m.collected then b.text:SetTextColor(0.6, 1, 0.6) else b.text:SetTextColor(1, 1, 1) end
      b.sel:SetShown(m.id == state.selected)
      b.track:SetShown(R.IsTracked(m.id))
      b:Show()
    else
      b:Hide()
    end
  end
  count:SetText(#list > 0 and L.COL_COUNT:format(state.offset + 1, math.min(state.offset + ROWS, #list), #list) or "")
  renderDetail(state.selected and R.MountEntry(state.selected))
end

W:SetScript("OnShow", function(self) self:Render() end)
for _, ev in ipairs({ "NEW_MOUNT_ADDED", "UPDATE_INSTANCE_INFO", "COMPANION_UPDATE" }) do
  ns.RegisterEvent(ev, function() if W:IsShown() then W:Render() end end)
end

function R.ToggleCollection()
  if W:IsShown() then W:Hide() else W:Show() end
end

-- Entry points: /fg mounts, and a button in the guide menu's Mounts category.
ns.SlashHandlers = ns.SlashHandlers or {}
ns.SlashHandlers.mounts = R.ToggleCollection
table.insert(L.HELP, 3, L.HELP_MOUNTS)
ns.CategoryActions = ns.CategoryActions or {}
ns.CategoryActions.mounts = { label = L.COL_OPEN, run = function()
  ns.Picker:Hide()
  R.ToggleCollection()
end }
