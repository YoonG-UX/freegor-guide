local _, ns = ...
local L = ns.L
local R = ns.Retail

-- Instance alert: entering a dungeon or raid that drops a mount you are
-- missing shows a raid-warning message and a chat line, with the boss and
-- whether it is already killed this reset. /freegor alert turns it on or off.

local alertedFor

function R.InstanceAlertText(journalInstanceID)
  R.ScanLockouts()
  local lines = {}
  for _, m in ipairs(R.MissingDropMounts and R.MissingDropMounts(journalInstanceID) or {}) do
    local state = m.boss and R.IsBossKilled(journalInstanceID, m.boss) and (" - " .. L.KILLED_THIS_WEEK) or ""
    lines[#lines + 1] = L.ALERT_LINE:format(m.name, m.boss or "?", state)
  end
  return lines
end

local function check()
  if ns.db and ns.db.instanceAlert == false then return end
  local inInstance, kind = IsInInstance()
  if not inInstance or (kind ~= "party" and kind ~= "raid") then
    alertedFor = nil
    return
  end
  local mapID = ns.Compat.GetPlayerMap()
  local EJ = C_EncounterJournal
  local jid = mapID and EJ and EJ.GetInstanceForGameMap and EJ.GetInstanceForGameMap(mapID)
  if not jid or jid == alertedFor then return end
  alertedFor = jid
  local lines = R.InstanceAlertText(jid)
  if #lines == 0 then return end
  local head = L.ALERT_HEAD:format(#lines)
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, head, ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.82, b = 0 })
  end
  if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
  ns.Print(head)
  for _, l in ipairs(lines) do ns.Print("  " .. l) end
end
R.CheckInstanceAlert = check

ns.RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, check) end)
ns.RegisterEvent("ZONE_CHANGED_NEW_AREA", function() C_Timer.After(2, check) end)

ns.SlashHandlers = ns.SlashHandlers or {}
ns.SlashHandlers.alert = function()
  ns.db.instanceAlert = ns.db.instanceAlert == false
  ns.Print(ns.db.instanceAlert and L.ALERT_ON or L.ALERT_OFF)
end
table.insert(L.HELP, 4, L.HELP_ALERT)
