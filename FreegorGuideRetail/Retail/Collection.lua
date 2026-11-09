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

local state = { show = "missing", source = nil, search = "", offset = 0, selected = nil, stats = false, sort = "difficulty" }

-- Difficulty and destination of each mount, cached for the session (the mount
-- journal, achievements and vendors change rarely; refreshed on those events).
local cache = {}
local DIFF_COLORS = { "|cff40ff40", "|cffffff40", "|cffff9930", "|cffff4040", "|cff9999ff" }
local function info(id)
  local c = cache[id]
  if not c then
    local e = R.MountEntry(id)
    c = e and { diff = R.MountDifficulty(e), dest = R.MountDestination(e) } or { diff = 3 }
    cache[id] = c
  end
  return c
end
R.MountListInfo = info
local function diffText(d) return (DIFF_COLORS[d] or "") .. (L["DIFF_LABEL_" .. d] or "?") .. "|r" end
for _, ev in ipairs({ "NEW_MOUNT_ADDED", "ACHIEVEMENT_EARNED", "MERCHANT_SHOW" }) do
  ns.RegisterEvent(ev, function() wipe(cache) end)
end

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
sourceButton:SetWidth(LIST_W - 12 - 116)

local SORTS = { "difficulty", "distance", "name" }
local SORT_LABEL = { difficulty = L.COL_SORT_DIFF, distance = L.COL_SORT_DIST, name = L.COL_SORT_NAME }
local sortButton = smallButton(L.COL_SORT_DIFF, 112, function()
  local i = 1
  for k, v in ipairs(SORTS) do if v == state.sort then i = k end end
  state.sort, state.offset = SORTS[i % #SORTS + 1], 0
  W:Render()
end)
sortButton:SetPoint("LEFT", sourceButton, "RIGHT", 4, 0)

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
  b.text:SetPoint("RIGHT", -96, 0)
  b.info = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.info:SetPoint("RIGHT", -18, 0)
  b.info:SetJustifyH("RIGHT")
  b.text:SetJustifyH("LEFT")
  b.text:SetWordWrap(false)
  b.track = b:CreateTexture(nil, "OVERLAY")
  b.track:SetSize(14, 14)
  b.track:SetPoint("RIGHT", -2, 0)
  b.track:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  b:SetScript("OnClick", function(self)
    state.selected, state.stats = self.mountID, false
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

-- Statistics by source ---------------------------------------------------------------

-- { {source=, owned=, total=} }, most mounts first.
function R.MountStatsBySource(all)
  local by = {}
  for _, m in ipairs(all or R.AllMounts()) do
    local st = by[m.sourceType] or { source = m.sourceType, owned = 0, total = 0 }
    by[m.sourceType] = st
    st.total = st.total + 1
    if m.collected then st.owned = st.owned + 1 end
  end
  local list = {}
  for _, st in pairs(by) do list[#list + 1] = st end
  table.sort(list, function(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return (a.source or 0) < (b.source or 0)
  end)
  return list
end

local statsPanel = CreateFrame("Frame", nil, W)
statsPanel:SetPoint("TOPLEFT", LIST_W + 16, -54)
statsPanel:SetPoint("BOTTOMRIGHT", -14, 14)
statsPanel:Hide()
local statsTitle = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
statsTitle:SetPoint("TOPLEFT")
statsTitle:SetText(L.COL_STATS_TITLE)
local statsHint = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statsHint:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 0, -4)
statsHint:SetText(L.COL_STATS_HINT)

local STAT_ROWS, STAT_H = 13, 30
local statRows = {}
for i = 1, STAT_ROWS do
  local b = CreateFrame("Button", nil, statsPanel)
  b:SetSize(WIDTH - LIST_W - 30, STAT_H - 4)
  b:SetPoint("TOPLEFT", 0, -44 - (i - 1) * STAT_H)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.label:SetPoint("LEFT", 4, 0)
  b.label:SetWidth(150)
  b.label:SetJustifyH("LEFT")
  b.bar = CreateFrame("StatusBar", nil, b)
  b.bar:SetPoint("LEFT", 160, 0)
  b.bar:SetSize(WIDTH - LIST_W - 30 - 160 - 110, 12)
  b.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  b.bar:SetMinMaxValues(0, 1)
  local bg = b.bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.5)
  b.value = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.value:SetPoint("RIGHT", -4, 0)
  b:SetScript("OnClick", function(self)
    state.source, state.offset, state.stats = self.source, 0, false
    W:Render()
  end)
  statRows[i] = b
end

local function renderStats(all)
  for i, b in ipairs(statRows) do
    local st = all[i]
    b.source = st and st.source
    if st then
      local frac = st.total > 0 and st.owned / st.total or 0
      b.label:SetText(sourceLabel(st.source))
      b.bar:SetValue(frac)
      -- red to green with completion
      b.bar:SetStatusBarColor(1 - frac, 0.35 + 0.55 * frac, 0.2)
      b.value:SetText(L.COL_STAT_VALUE:format(st.owned, st.total, math.floor(frac * 100)))
      b:Show()
    else
      b:Hide()
    end
  end
end

local statsBtn = CreateFrame("Button", nil, W, "UIPanelButtonTemplate")
statsBtn:SetSize(110, 20)
statsBtn:SetPoint("TOPRIGHT", -30, -10)
statsBtn:SetScript("OnClick", function()
  state.stats = not state.stats
  W:Render()
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
  if state.sort ~= "name" then
    for _, m in ipairs(list) do
      local c = info(m.id)
      m.diff = m.collected and 0 or c.diff
      m.dist = R.DistanceTo(c.dest)
    end
    table.sort(list, function(a, b)
      if state.sort == "distance" then
        if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
        if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
      end
      if a.diff ~= b.diff then return a.diff < b.diff end
      return a.name < b.name
    end)
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
  if e.vendor then
    lines[#lines + 1] = L.COL_VENDOR:format(e.vendor.name or "?", ns.Compat.GetMapName(e.vendor.map) or "",
      e.vendor.x * 100, e.vendor.y * 100)
  elseif e.sourceType == 3 then
    lines[#lines + 1] = L.COL_VENDOR_UNKNOWN
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
  local status = (e.collected and L.COL_COLLECTED or L.COL_NOT_COLLECTED) .. "  -  " .. sourceLabel(e.sourceType)
  if not e.collected then status = status .. "  -  " .. L.COL_DIFFICULTY:format(diffText(R.MountDifficulty(e))) end
  dStatus:SetText(status)
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
  sortButton:SetText(SORT_LABEL[state.sort])

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
      if m.collected or state.sort == "name" then
        b.info:SetText("")
      else
        local c = info(m.id)
        local dist = m.dist and ("  " .. L.COL_DISTANCE:format(m.dist)) or ""
        b.info:SetText(diffText(c.diff) .. dist)
      end
      b:Show()
    else
      b:Hide()
    end
  end
  count:SetText(#list > 0 and L.COL_COUNT:format(state.offset + 1, math.min(state.offset + ROWS, #list), #list) or "")
  statsBtn:SetText(state.stats and L.COL_BACK or L.COL_STATS_BUTTON)
  statsPanel:SetShown(state.stats)
  if state.stats then
    detail:Hide()
    renderStats(R.MountStatsBySource())
  else
    renderDetail(state.selected and R.MountEntry(state.selected))
  end
end

W:SetScript("OnShow", function(self) self:Render() end)
for _, ev in ipairs({ "NEW_MOUNT_ADDED", "UPDATE_INSTANCE_INFO", "COMPANION_UPDATE" }) do
  ns.RegisterEvent(ev, function() if W:IsShown() then W:Render() end end)
end

function R.OpenCollectionAt(id)
  state.selected, state.stats = id, false
  if W:IsShown() then W:Render() else W:Show() end
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
