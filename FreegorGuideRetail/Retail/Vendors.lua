local _, ns = ...
local R = ns.Retail
local C = ns.Compat

-- Mount vendor positions, learned while playing: when a merchant window opens
-- and the vendor sells a mount, its position is saved (account-wide) and used
-- by the arrow, the mount guides and the collection window. The game does not
-- give vendor positions any other way.

function R.VendorFor(mountID)
  local db = ns.db and ns.db.mountVendors
  return db and db[mountID] or nil
end

local function safe(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end

local function itemIDAt(i)
  if GetMerchantItemID then
    local ok, id = pcall(GetMerchantItemID, i)
    if ok and id then return id end
  end
  local link = GetMerchantItemLink and GetMerchantItemLink(i)
  return link and tonumber(link:match("item:(%d+)"))
end

function R.RecordVendor()
  if not (GetMerchantNumItems and C_MountJournal and C_MountJournal.GetMountFromItem) then return 0 end
  local mapID = C.GetPlayerMap()
  local x, y = C.GetPlayerMapPos(mapID)
  if not (mapID and x) then return 0 end -- no position (instance, flying city...)
  local npc = C.GetInteractNpcID()
  local name = safe(UnitName and UnitName("npc"))
  local found = 0
  for i = 1, (GetMerchantNumItems() or 0) do
    local item = itemIDAt(i)
    local mountID = item and C_MountJournal.GetMountFromItem(item)
    if mountID and mountID > 0 then
      ns.db.mountVendors = ns.db.mountVendors or {}
      ns.db.mountVendors[mountID] = { map = mapID, x = x, y = y, npc = npc, name = name }
      found = found + 1
    end
  end
  if found > 0 then ns.Engine:QueueRefresh() end
  return found
end

ns.RegisterEvent("MERCHANT_SHOW", function() R.RecordVendor() end)
ns.RegisterEvent("MERCHANT_UPDATE", function() R.RecordVendor() end)
