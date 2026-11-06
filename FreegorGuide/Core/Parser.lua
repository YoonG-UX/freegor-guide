local _, ns = ...

-- Turns guide text into a table. The format is documented in docs/FORMAT.md.
--
--   guide Northshire (1-6)
--   faction Alliance
--   levels 1-6
--   zone 1429, Elwynn Forest
--   step
--     goto 48.2,42.0
--     talk Deputy Willem
--     accept 783 A Threat Within
--   step
--     kill 10 Kobold Vermin |q 7/1
--
-- This file has no game-API dependency so it can be tested outside the client.

local Parser = {}
ns.Parser = Parser

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function splitList(s)
  local out = {}
  for item in s:gmatch("[^,]+") do
    item = trim(item)
    if item ~= "" then out[#out + 1] = item end
  end
  return out
end

-- Split "text |q 7/1 |r 15" into "text" and { q = "7/1", r = "15" }.
local function splitOptions(rest)
  local opts = {}
  local main = rest:match("^([^|]*)") or ""
  for key, val in rest:gmatch("|%s*(%a+)%s*([^|]*)") do
    opts[key:lower()] = trim(val)
  end
  return trim(main), opts
end

local function parseQuestRef(s)
  local q, o = s:match("^(%d+)%s*/%s*(%d+)$")
  if q then return tonumber(q), tonumber(o) end
  q = s:match("^(%d+)$")
  if q then return tonumber(q), nil end
  return nil
end

-- "48.2,42.0" or "Elwynn Forest 48.2,42.0" or "1429 48.2, 42.0"
local function parseGoto(text)
  local zone, x, y = text:match("^(.-)%s*(%d+%.?%d*)%s*,%s*(%d+%.?%d*)$")
  if not x then return nil, "expected coordinates like 48.2,42.0" end
  x, y = tonumber(x), tonumber(y)
  if x > 100 or y > 100 then return nil, "coordinates must be between 0 and 100" end
  zone = trim(zone or "")
  return { zone = zone ~= "" and zone or nil, x = x / 100, y = y / 100 }
end

local goalParsers = {}

goalParsers.accept = function(args)
  local id, title = args:match("^(%d+)%s*(.*)$")
  if not id then return nil, "expected: accept <questID> [title]" end
  return { type = "accept", quest = tonumber(id), title = title ~= "" and title or nil }
end

goalParsers.turnin = function(args)
  local id, title = args:match("^(%d+)%s*(.*)$")
  if not id then return nil, "expected: turnin <questID> [title]" end
  return { type = "turnin", quest = tonumber(id), title = title ~= "" and title or nil }
end

-- "do 7 Kobold Camp Cleanup": finish all objectives of a quest.
goalParsers["do"] = function(args)
  local id, title = args:match("^(%d+)%s*(.*)$")
  if not id then return nil, "expected: do <questID> [title]" end
  return { type = "do", quest = tonumber(id), title = title ~= "" and title or nil }
end

local function objectiveGoal(kind)
  return function(args, opts)
    local goal = { type = kind, text = args }
    if opts.q then
      local q, o = parseQuestRef(opts.q)
      if not q then return nil, "bad |q value, expected <questID> or <questID>/<objective>" end
      goal.quest, goal.objective = q, o
    end
    if args == "" then return nil, kind .. " needs a description" end
    return goal
  end
end
goalParsers.kill = objectiveGoal("kill")
goalParsers.collect = objectiveGoal("collect")

goalParsers["goto"] = function(args, opts)
  local g, err = parseGoto(args)
  if not g then return nil, err end
  g.type = "goto"
  g.radius = tonumber(opts.r)
  return g
end

goalParsers.talk = function(args, opts)
  if args == "" then return nil, "talk needs an NPC name" end
  return { type = "talk", text = args, npc = tonumber(opts.n) }
end

-- Actions detected from game events while the step is active.
local function actionGoal(kind, needsText)
  return function(args)
    if needsText and args == "" then return nil, kind .. " needs a name" end
    return { type = kind, text = args }
  end
end
goalParsers.home = actionGoal("home", true)     -- bind the hearthstone at an inn
goalParsers.fpath = actionGoal("fpath", true)   -- discover a flight path
goalParsers.fly = actionGoal("fly", true)       -- take a flight
goalParsers.hearth = actionGoal("hearth", false) -- use the hearthstone
goalParsers.train = actionGoal("train", false)  -- visit a class trainer
goalParsers.use = actionGoal("use", true)       -- information only

-- gold <amount>: have at least this much gold
goalParsers.gold = function(args)
  local n = tonumber(args)
  if not n then return nil, "expected: gold <amount>" end
  return { type = "gold", amount = n }
end

-- item <itemID> [count] [name]: have the item in the bags
goalParsers.item = function(args)
  local id, count, name = args:match("^(%d+)%s*(%d*)%s*(.*)$")
  if not id then return nil, "expected: item <itemID> [count] [name]" end
  return { type = "item", item = tonumber(id), count = tonumber(count) or 1, text = name ~= "" and name or nil }
end

-- rep <factionID> <standing> [name]: reach a reputation standing
local STANDINGS = { hated = 1, hostile = 2, unfriendly = 3, neutral = 4, friendly = 5, honored = 6, revered = 7, exalted = 8 }
Parser.STANDINGS = STANDINGS
goalParsers.rep = function(args)
  local id, standing, name = args:match("^(%d+)%s+(%a+)%s*(.*)$")
  if not id or not STANDINGS[standing:lower()] then
    return nil, "expected: rep <factionID> <neutral|friendly|honored|revered|exalted> [name]"
  end
  return { type = "rep", faction = tonumber(id), standing = STANDINGS[standing:lower()], text = name ~= "" and name or nil }
end

-- achieve <achievementID> [name]: only meaningful on clients with achievements
goalParsers.achieve = function(args)
  local id, name = args:match("^(%d+)%s*(.*)$")
  if not id then return nil, "expected: achieve <achievementID> [name]" end
  return { type = "achieve", achievement = tonumber(id), text = name ~= "" and name or nil }
end
goalParsers.buy = actionGoal("buy", true)       -- information only

goalParsers.level = function(args)
  local n = tonumber(args)
  if not n then return nil, "expected: level <number>" end
  return { type = "level", level = n }
end

goalParsers.note = function(args)
  return { type = "note", text = args }
end

local headerKeys = {
  guide = true, author = true, faction = true, levels = true,
  next = true, zone = true, description = true, race = true,
  category = true, loop = true,
}

-- Returns guide table, or nil + error message + line number.
function Parser.Parse(text)
  local guide = { steps = {}, zone = {} }
  local step
  local lineNo = 0

  for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
    lineNo = lineNo + 1
    local line = trim(raw:gsub("\r", ""))
    if line ~= "" and not line:match("^%-%-") and not line:match("^#") then
      local cmd, rest = line:match("^(%S+)%s*(.*)$")
      cmd = cmd:lower()

      if cmd == "step" then
        step = { goals = {}, line = lineNo }
        guide.steps[#guide.steps + 1] = step
      elseif not step then
        if not headerKeys[cmd] then
          return nil, "unknown header '" .. cmd .. "'", lineNo
        end
        if cmd == "guide" then
          guide.title = rest
        elseif cmd == "levels" then
          local a, b = rest:match("^(%d+)%s*%-%s*(%d+)$")
          if not a then return nil, "expected: levels <min>-<max>", lineNo end
          guide.minLevel, guide.maxLevel = tonumber(a), tonumber(b)
        elseif cmd == "zone" then
          guide.zone = splitList(rest)
        elseif cmd == "race" then
          guide.race = splitList(rest)
        elseif cmd == "category" then
          guide.category = rest:lower()
        elseif cmd == "loop" then
          guide.loop = true
        else
          guide[cmd] = rest
        end
      elseif cmd == "only" then
        step.only = splitList(rest)
      else
        local parse = goalParsers[cmd]
        if not parse then return nil, "unknown command '" .. cmd .. "'", lineNo end
        local main, opts = splitOptions(rest)
        local goal, err = parse(main, opts)
        if not goal then return nil, err, lineNo end
        goal.line = lineNo
        goal.fr = opts.fr -- French display text (|fr ...)
        step.goals[#step.goals + 1] = goal
      end
    end
  end

  guide.category = guide.category or "leveling"
  if not guide.title or guide.title == "" then
    return nil, "missing 'guide <title>' header", 1
  end
  if #guide.steps == 0 then
    return nil, "guide has no steps", lineNo
  end
  return guide
end

-- Is a guide meant for this race? (no "race" header = every race)
function Parser.GuideForRace(guide, race)
  if not guide.race then return true end
  local me = (race or ""):gsub("%s", ""):upper()
  for _, r in ipairs(guide.race) do
    if r:gsub("%s", ""):upper() == me then return true end
  end
  return false
end

-- Does this step apply to the given player? `only` tokens may name a class
-- (WARRIOR, Mage...), a race (Human, NightElf...) or a faction (Alliance, Horde).
-- A token prefixed with "!" excludes instead.
function Parser.StepApplies(step, class, race, faction)
  if not step.only then return true end
  local norm = function(s) return (s or ""):gsub("%s", ""):upper() end
  local me = { [norm(class)] = true, [norm(race)] = true, [norm(faction)] = true }
  local anyPositive, matched = false, false
  for _, tok in ipairs(step.only) do
    local neg = tok:sub(1, 1) == "!"
    local key = norm(neg and tok:sub(2) or tok)
    if neg then
      if me[key] then return false end
    else
      anyPositive = true
      if me[key] then matched = true end
    end
  end
  return matched or not anyPositive
end
