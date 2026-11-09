local _, ns = ...
local L = ns.L
local Engine = ns.Engine

SLASH_FREEGOR1 = "/freegor"
SLASH_FREEGOR2 = "/fg"

SlashCmdList.FREEGOR = function(msg)
  local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()

  local extra = ns.SlashHandlers and ns.SlashHandlers[cmd]
  if extra then return extra(arg) end
  if cmd == "" then
    ns.SetShown(not ns.Viewer:IsShown())
  elseif cmd == "list" or cmd == "menu" then
    ns.Picker:Toggle()
  elseif cmd == "next" then
    Engine:Next()
  elseif cmd == "prev" then
    Engine:Prev()
  elseif cmd == "step" and tonumber(arg) then
    Engine:Jump(tonumber(arg))
  elseif cmd == "load" and arg ~= "" then
    Engine:LoadGuide(arg)
  elseif cmd == "unskip" then
    ns.cdb.dynSkip = {}
    if Engine.guide and Engine.guide.dynamic then Engine:LoadGuide(Engine.guide.title) end
  elseif cmd == "minimap" then
    ns.db.minimapButton = ns.db.minimapButton == false
    ns.MinimapButton:SetShown(ns.db.minimapButton)
  elseif cmd == "auto" then
    ns.ToggleAutoQuest()
  elseif cmd == "arrow" then
    ns.db.arrowShown = not ns.db.arrowShown
    ns.Arrow:UpdateVisibility()
  elseif cmd == "reset" then
    ns.db.viewerPos, ns.db.arrowPos = nil, nil
    ns.Viewer:ClearAllPoints()
    ns.Viewer:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
    ns.Arrow:ClearAllPoints()
    ns.Arrow:SetPoint("TOP", UIParent, "TOP", 0, -120)
  else
    for _, line in ipairs(L.HELP) do ns.Print(line) end
  end
end
