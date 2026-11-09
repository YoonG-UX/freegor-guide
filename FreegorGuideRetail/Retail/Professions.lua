local _, ns = ...
local L = ns.L
local R = ns.Retail
local Freegor = ns.Freegor

-- Profession guides built from the player's own recipe list.
--
-- When the profession window is open, the recipes of the expansion tab shown
-- are read (difficulty colour, skill-ups, reagents). The guide then shows the
-- best recipe to craft next, the reagents with what you already own (bags,
-- bank, reagent bank, warband bank) and the skill to reach, plus a second
-- choice and the "first craft" recipes that give bonus knowledge. It updates
-- after every craft, so it follows the game's data in every patch.

R.lastChild = R.lastChild or {} -- [base skillLine] = expansion skillLine shown last

-- Expected skill points per craft, by colour (orange, yellow, green).
local CHANCE = { [0] = 1, [1] = 0.6, [2] = 0.25 }
local BASIC_REAGENT = 1 -- Enum.CraftingReagentType.Basic

local function T() return C_TradeSkillUI end

local function clean(s)
  return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    :gsub("|H.-|h(.-)|h", "%1"):gsub("|n", " - "):gsub("[|\n\r]", " "))
end
R.Clean = clean

-- Read the profession window ------------------------------------------------

function R.ReadProfession()
  local TS = T()
  if not (TS and TS.IsTradeSkillReady and TS.IsTradeSkillReady()) then return end
  for _, f in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting", "IsRuneforging" }) do
    if TS[f] and TS[f]() then return end -- someone else's profession, or a special window
  end
  local child = TS.GetChildProfessionInfo and TS.GetChildProfessionInfo()
  local base = TS.GetBaseProfessionInfo and TS.GetBaseProfessionInfo()
  if not (child and child.professionID and child.professionID ~= 0) then return end

  local ids = (TS.GetAllRecipeIDs and TS.GetAllRecipeIDs()) or (TS.GetFilteredRecipeIDs and TS.GetFilteredRecipeIDs()) or {}
  local recipes, gathering = {}, 0
  for _, id in ipairs(ids) do
    local info = TS.GetRecipeInfo(id)
    if info and info.isGatheringRecipe then gathering = gathering + 1 end
    if info and not info.isDummyRecipe and not info.isRecraft and not info.isSalvageRecipe
      and not info.isGatheringRecipe
      and (not TS.IsRecipeInSkillLine or TS.IsRecipeInSkillLine(id, child.professionID)) then
      recipes[#recipes + 1] = {
        id = id, name = info.name, learned = info.learned, diff = info.relativeDifficulty,
        ups = math.max(info.numSkillUps or 1, 1), canSkillUp = info.canSkillUp, firstCraft = info.firstCraft,
      }
    end
  end

  local entry = {
    skillLine = child.professionID, name = child.professionName,
    level = child.skillLevel or 0, max = child.maxSkillLevel or 0,
    baseSkillLine = base and base.professionID, baseName = base and base.professionName,
    recipes = recipes, gathering = #recipes == 0 and gathering > 0,
  }
  R.profs[child.professionID] = entry
  if entry.baseSkillLine then
    R.profs[entry.baseSkillLine] = R.profs[entry.baseSkillLine] or entry
    R.lastChild[entry.baseSkillLine] = child.professionID
  end
  return entry
end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
  "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED" }) do
  ns.RegisterEvent(ev, function()
    if R.ReadProfession() then ns.Engine:QueueRefresh() end
  end)
end

-- Costs ----------------------------------------------------------------------

-- Auction price in copper from Auctionator when it is installed, else nil.
local function auctionPrice(itemID)
  local api = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
  if not (api and api.GetAuctionPriceByItemID) then return nil end
  local ok, p = pcall(api.GetAuctionPriceByItemID, "FreegorGuide", itemID)
  return ok and p or nil
end

local function money(copper)
  local g, s = math.floor(copper / 10000), math.floor(copper / 100) % 100
  if g > 0 then return ("%dg %ds"):format(g, s) end
  return ("%ds %dc"):format(s, copper % 100)
end

-- Basic reagents of a recipe: { {item=, qty=} }, priced cost (or nil), unit count
local function reagentsOf(recipeID)
  local TS = T()
  local ok, schem = pcall(TS.GetRecipeSchematic, recipeID, false)
  if not ok or not schem then return {}, nil, 0 end
  local list, cost, units = {}, 0, 0
  for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
    local first = slot.reagents and slot.reagents[1]
    if slot.required and slot.reagentType == BASIC_REAGENT and first and first.itemID then
      list[#list + 1] = { item = first.itemID, qty = slot.quantityRequired or 1 }
      units = units + (slot.quantityRequired or 1)
      local p = auctionPrice(first.itemID)
      if p and cost then cost = cost + p * (slot.quantityRequired or 1) else cost = nil end
    end
  end
  return list, cost, units
end

-- Pick the recipes giving the most skill for the least reagents.
local function rank(p)
  local TS = T()
  local out = {}
  for _, r in ipairs(p.recipes) do
    if r.learned and r.canSkillUp and CHANCE[r.diff] then
      local reagents, cost, units = reagentsOf(r.id)
      local perCraft = r.ups * CHANCE[r.diff]
      local craftable = TS.GetCraftableCount and TS.GetCraftableCount(r.id) or 0
      local price = cost or units * 1000 -- without prices, fewer reagents is cheaper
      local score = perCraft / math.max(price, 1) * (craftable > 0 and 1.5 or 1)
      out[#out + 1] = { r = r, reagents = reagents, cost = cost, perCraft = perCraft, score = score }
    end
  end
  table.sort(out, function(a, b) return a.score > b.score end)
  return out
end

-- Full leveling path from the recipe thresholds (Retail/Data/Professions.lua) ---
--
-- Each recipe is orange below its "yellow" skill, then its chance to give a
-- point drops linearly to 0 at its "grey" skill (the game's classic rule).
-- From the current skill to the maximum, every level uses the known recipe
-- with the most expected points per reagent; consecutive levels using the
-- same recipe make one step.

local function chanceAt(t, s)
  local low, high = t[2], t[3]
  if s < low then return 1 end
  if s >= high then return 0 end
  return (high - s) / math.max(high - low, 1)
end
R.ChanceAt = chanceAt

local MAX_SEGMENTS = 12

function R.PlanPath(p, title)
  local data = R.Recipes or {}
  local cands = {}
  for _, r in ipairs(p.recipes) do
    local t = data[r.id]
    if r.learned and t and t[1] == p.skillLine and not Freegor:IsSkipped(title, "path:" .. r.id) then
      local reagents, cost, units = reagentsOf(r.id)
      cands[#cands + 1] = { r = r, t = t, reagents = reagents, cost = cost, price = cost or math.max(units, 1) * 1000 }
    end
  end
  if #cands == 0 then return nil end

  local function best(level)
    local b, bs
    for _, c in ipairs(cands) do
      local e = c.t[4] * chanceAt(c.t, level)
      if e > 0 then
        local score = e / c.price
        if not bs or score > bs then b, bs = c, score end
      end
    end
    return b
  end

  local segs, s = {}, p.level
  while s < p.max and #segs < MAX_SEGMENTS do
    local c = best(s)
    if not c then break end
    local seg = { c = c, from = s, crafts = 0 }
    while s < p.max and best(s) == c do
      seg.crafts = seg.crafts + 1 / (c.t[4] * chanceAt(c.t, s)) -- average crafts for one point
      s = s + 1
    end
    seg.to, seg.crafts = s, math.max(1, math.ceil(seg.crafts))
    segs[#segs + 1] = seg
  end
  return segs, s
end

local function pathStep(p, seg, first)
  local c = seg.c
  local lines = { "step", " key path:" .. c.r.id }
  if first then lines[#lines + 1] = " note " .. clean(L.PROF_STATUS:format(p.name, p.level, p.max)) end
  for _, l in ipairs({
    " note " .. clean(L.PROF_SEG:format(seg.from, seg.to, seg.crafts, c.r.name)),
    (" recipe %d %d %s"):format(c.r.id, seg.crafts, clean(c.r.name)) }) do lines[#lines + 1] = l end
  for i, rg in ipairs(c.reagents) do
    if i > 6 then break end
    lines[#lines + 1] = (" reagent %d %d"):format(rg.item, rg.qty * seg.crafts)
  end
  lines[#lines + 1] = (" skill %d %d %s"):format(p.skillLine, seg.to, clean(p.name))
  if c.cost then lines[#lines + 1] = " note " .. L.PROF_COST_AH:format(money(c.cost * seg.crafts)) end
  return table.concat(lines, "\n")
end

-- Unknown recipes that still give skill at `level`, for when the path stops early.
local function learnAfter(p, level)
  local TS, data = T(), R.Recipes or {}
  local lines = { "step", " key learn", " note " .. clean(L.PROF_PATH_END:format(level)) }
  local n = 0
  for _, r in ipairs(p.recipes) do
    local t = data[r.id]
    if not r.learned and t and t[1] == p.skillLine and chanceAt(t, level) > 0 and n < 6 then
      n = n + 1
      local src
      if TS.GetRecipeSourceText then
        local ok, text = pcall(TS.GetRecipeSourceText, r.id)
        src = ok and text or nil
      end
      lines[#lines + 1] = " note " .. clean(L.PROF_LEARN:format(r.name, src and clean(src) or "?"))
    end
  end
  if n == 0 then lines[#lines + 1] = " note " .. L.PROF_NO_RECIPE end
  return table.concat(lines, "\n")
end

-- Guide text -------------------------------------------------------------------

local function craftStep(p, c, alt)
  local need = math.max(p.max - p.level, 1)
  local n = math.min(math.max(math.ceil(math.min(need, 5) / c.perCraft), 1), 20)
  local target = math.min(p.max, p.level + math.max(1, math.floor(n * c.perCraft)))
  local lines = { "step", " key craft:" .. c.r.id }
  if alt then lines[#lines + 1] = " note " .. L.PROF_ALT end
  lines[#lines + 1] = " note " .. clean(L.PROF_STATUS:format(p.name, p.level, p.max))
  lines[#lines + 1] = (" recipe %d %d %s"):format(c.r.id, n, clean(c.r.name))
  for i, rg in ipairs(c.reagents) do
    if i > 6 then break end
    lines[#lines + 1] = (" reagent %d %d"):format(rg.item, rg.qty * n)
  end
  lines[#lines + 1] = (" skill %d %d %s"):format(p.skillLine, target, clean(p.name))
  lines[#lines + 1] = " note " .. clean(L.PROF_CRAFT:format(n, c.r.name, L["DIFF_" .. c.r.diff], c.perCraft))
  if c.cost then lines[#lines + 1] = " note " .. L.PROF_COST_AH:format(money(c.cost)) end
  return table.concat(lines, "\n")
end

local function firstCraftStep(p)
  local list = {}
  for _, r in ipairs(p.recipes) do
    if r.learned and r.firstCraft then list[#list + 1] = r end
  end
  if #list == 0 then return nil end
  table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
  local lines = { "step", " key first", " note " .. L.PROF_FIRST }
  for i, r in ipairs(list) do
    if i > 8 then break end
    lines[#lines + 1] = (" recipe %d 1 %s"):format(r.id, clean(r.name))
  end
  return table.concat(lines, "\n")
end

local function learnStep(p)
  local TS = T()
  local lines = { "step", " key learn", " note " .. L.PROF_NO_RECIPE }
  local n = 0
  for _, r in ipairs(p.recipes) do
    if not r.learned and CHANCE[r.diff] and n < 6 then
      n = n + 1
      local src
      if TS.GetRecipeSourceText then
        local ok, text = pcall(TS.GetRecipeSourceText, r.id)
        src = ok and text or nil
      end
      lines[#lines + 1] = " note " .. clean(L.PROF_LEARN:format(r.name, src and clean(src) or "?"))
    end
  end
  return table.concat(lines, "\n")
end

function R.BuildProfessionGuide(baseSkillLine, baseName)
  local title = L.PROF_TITLE:format(baseName)
  local childID = R.lastChild[baseSkillLine]
  local p = childID and R.profs[childID]
  if not p then
    return ("step\n key open\n profopen %d %s\n note %s\n"):format(baseSkillLine, clean(baseName),
      clean(L.PROF_OPEN:format(baseName)))
  end
  if p.gathering then
    return ("step\n key gather\n note %s\n note %s\n skill %d %d %s\n"):format(
      clean(L.PROF_STATUS:format(p.name, p.level, p.max)), clean(L.PROF_GATHER:format(baseName)),
      p.skillLine, p.max, clean(p.name))
  end

  local parts = {}
  local planned, reached = R.PlanPath(p, title)
  if p.level >= p.max and p.max > 0 then
    parts[#parts + 1] = "step\n key maxed\n note " .. clean(L.PROF_MAXED:format(p.name))
  elseif planned then
    for i, seg in ipairs(planned) do parts[#parts + 1] = pathStep(p, seg, i == 1) end
    if reached < p.max then parts[#parts + 1] = learnAfter(p, reached) end
  else
    local ranked, shown = rank(p), 0
    for _, c in ipairs(ranked) do
      if shown >= 2 then break end
      if not Freegor:IsSkipped(title, "craft:" .. c.r.id) then
        parts[#parts + 1] = craftStep(p, c, shown == 1)
        shown = shown + 1
      end
    end
    if shown == 0 then parts[#parts + 1] = learnStep(p) end
  end
  local first = not Freegor:IsSkipped(title, "first") and firstCraftStep(p)
  if first then parts[#parts + 1] = first end
  return table.concat(parts, "\n") .. "\n"
end

-- One guide per profession the character has --------------------------------

local registered = {}
local EVENTS = { "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_SHOW",
  "NEW_RECIPE_LEARNED", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED" }

function R.RegisterProfessionGuides()
  if not GetProfessions then return end
  local prof1, prof2, _, fishing, cooking = GetProfessions()
  for _, index in ipairs({ prof1, prof2, cooking, fishing }) do
    if index then
      local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
      if name and skillLine and not registered[skillLine] then
        registered[skillLine] = true
        Freegor:RegisterDynamicGuide({
          title = L.PROF_TITLE:format(name),
          category = "professions",
          description = L.PROF_DESC,
          events = EVENTS,
          build = function() return R.BuildProfessionGuide(skillLine, name) end,
        })
      end
    end
  end
end

ns.On("INIT", R.RegisterProfessionGuides)
ns.RegisterEvent("SKILL_LINES_CHANGED", function() R.RegisterProfessionGuides() end)
