local ADDON, ns = ...

-- Public API: other addons (community guide packs) call Freegor:RegisterGuide(text).
local Freegor = {}
_G.Freegor = Freegor
ns.Freegor = Freegor

ns.guides = {}      -- title -> guide (parsed lazily)
ns.guideOrder = {}  -- titles in registration order

local DB_DEFAULTS = {
  shown = true,
  arrowShown = true,
  arrivalRadius = 12, -- yards
  useTomTom = true,
  autoQuest = false,
  minimapButton = true,
  minimapAngle = 210,
  viewerPos = nil,
  arrowPos = nil,
}

local CHAR_DEFAULTS = {
  guide = nil,  -- title of the active guide
  step = 1,
  taxi = {},   -- known flight points (lowercase names)
}

local function applyDefaults(dst, defaults)
  for k, v in pairs(defaults) do
    if dst[k] == nil then dst[k] = v end
  end
  return dst
end

function ns.Print(fmt, ...)
  local msg = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ccffFreegor|r: " .. msg)
end

-- Minimal internal message bus so the UI modules stay decoupled from the engine.
local listeners = {}
function ns.On(msg, fn)
  listeners[msg] = listeners[msg] or {}
  table.insert(listeners[msg], fn)
end
function ns.Fire(msg, ...)
  for _, fn in ipairs(listeners[msg] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
  end
end

-- Game event dispatch
local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame
local handlers = {}
function ns.RegisterEvent(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    -- Some events don't exist on every client flavor; never let that break loading.
    pcall(eventFrame.RegisterEvent, eventFrame, event)
  end
  table.insert(handlers[event], fn)
end
eventFrame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event]) do fn(event, ...) end
end)

ns.RegisterEvent("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  FreegorDB = applyDefaults(FreegorDB or {}, DB_DEFAULTS)
  FreegorCharDB = applyDefaults(FreegorCharDB or {}, CHAR_DEFAULTS)
  ns.db = FreegorDB
  ns.cdb = FreegorCharDB
end)

ns.RegisterEvent("PLAYER_LOGIN", function()
  ns.Fire("INIT")
end)
