local _, ns = ...
local L = ns.L
local Parser = ns.Parser

-- Retail goal types. They plug into the shared engine through ns.GoalTypes
-- (status / text / primary) and Parser.RegisterGoal (guide syntax).

local R = ns.Retail or {}
ns.Retail = R
R.profs = R.profs or {}      -- [skillLineID] = { name, level, max, ... } read from the profession window
R.killed = R.killed or {}    -- ["instance|boss"] = true when killed this reset

local function lc(s) return (s or ""):lower() end

local function numArgs(args, n)
  local out, rest = {}, args
  for i = 1, n do
    local v, r = rest:match("^(%d+)%s*(.*)$")
    if not v then return nil end
    out[i], rest = tonumber(v), r
  end
  out.rest = rest ~= "" and rest or nil
  return out
end

local function register(name, minNums, build, def)
  Parser.RegisterGoal(name, function(args, opts)
    local a = numArgs(args, minNums)
    if not a then return nil, ("expected: %s with %d number(s)"):format(name, minNums) end
    local goal = build(a, opts)
    goal.type = name
    return goal
  end)
  ns.GoalTypes[name] = def
end

---------------------------------------------------------------------------
-- Game data helpers
---------------------------------------------------------------------------

function R.MountInfo(mountID)
  local MJ = C_MountJournal
  if not (MJ and MJ.GetMountInfoByID) then return nil end
  local name, spellID, icon, _, _, sourceType, _, isFactionSpecific, faction, shouldHide, isCollected =
    MJ.GetMountInfoByID(mountID)
  return name, isCollected, sourceType, isFactionSpecific, faction, shouldHide, icon, spellID
end

-- Bags + bank + reagent bank + warband bank.
function R.ItemCount(itemID)
  if C_Item and C_Item.GetItemCount then
    local ok, n = pcall(C_Item.GetItemCount, itemID, true, false, true, true)
    if ok and n then return n end
  end
  return ns.Compat.GetItemCount(itemID)
end

function R.ItemName(itemID)
  return ns.Compat.GetItemName(itemID)
end

function R.RecipeInfo(recipeID)
  local T = C_TradeSkillUI
  if not (T and T.GetRecipeInfo) then return nil end
  local ok, info = pcall(T.GetRecipeInfo, recipeID)
  return ok and info or nil
end

-- Saved instances: bosses killed during the current reset.
function R.ScanLockouts()
  wipe(R.killed)
  if not (GetNumSavedInstances and GetSavedInstanceInfo and GetSavedInstanceEncounterInfo) then return end
  for i = 1, GetNumSavedInstances() do
    local name, _, reset, _, locked, _, _, _, _, _, numEncounters = GetSavedInstanceInfo(i)
    if name and locked and (reset or 0) > 0 then
      for e = 1, (numEncounters or 0) do
        local boss, _, killed = GetSavedInstanceEncounterInfo(i, e)
        if boss and killed then R.killed[lc(name) .. "|" .. lc(boss)] = true end
      end
    end
  end
end

function R.InstanceName(journalInstanceID)
  if not EJ_GetInstanceInfo then return nil end
  local ok, name = pcall(EJ_GetInstanceInfo, journalInstanceID)
  return ok and name or nil
end

function R.IsBossKilled(journalInstanceID, boss)
  local inst = R.InstanceName(journalInstanceID)
  if not inst or not boss then return false end
  local key = lc(inst) .. "|" .. lc(boss)
  if R.killed[key] then return true end
  -- the saved-instance boss name can be a longer form of the source text name
  for k in pairs(R.killed) do
    local i, b = k:match("^(.-)|(.*)$")
    if i == lc(inst) and (b:find(lc(boss), 1, true) or lc(boss):find(b, 1, true)) then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Goal types
---------------------------------------------------------------------------

-- mount <mountID> [name]: the mount is in the collection
register("mount", 1, function(a) return { mount = a[1], text = a.rest } end, {
  status = function(goal)
    local _, collected = R.MountInfo(goal.mount)
    return collected and "done" or "todo"
  end,
  text = function(goal, text)
    return L.GOAL_MOUNT:format(R.MountInfo(goal.mount) or text or ("#" .. goal.mount))
  end,
})

-- skill <skillLineID> <level> [name]: profession skill reached
register("skill", 2, function(a) return { skillLine = a[1], level = a[2], text = a.rest } end, {
  status = function(goal)
    local p = R.profs[goal.skillLine]
    if not p then return "todo" end
    return p.level >= goal.level and "done" or "todo", ("%d/%d"):format(p.level, goal.level)
  end,
  text = function(goal, text)
    local p = R.profs[goal.skillLine]
    return L.GOAL_SKILL:format(goal.level, (p and p.name) or text or "?")
  end,
})

-- recipe <recipeID> [count] [name]: what to craft (information; click opens the recipe)
register("recipe", 1, function(a)
  local count, name = (a.rest or ""):match("^(%d+)%s*(.*)$")
  return { recipe = a[1], count = tonumber(count), text = name or a.rest }
end, {
  primary = false,
  status = function(goal)
    local info = R.RecipeInfo(goal.recipe)
    if info and info.relativeDifficulty then return "info", L["DIFF_" .. info.relativeDifficulty] end
    return "info"
  end,
  text = function(goal, text)
    local info = R.RecipeInfo(goal.recipe)
    local name = (info and info.name) or text or ("#" .. goal.recipe)
    return L.GOAL_RECIPE:format(goal.count and (goal.count .. " x ") or "", name)
  end,
  onClick = function(goal)
    if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then pcall(C_TradeSkillUI.OpenRecipe, goal.recipe) end
  end,
})

-- reagent <itemID> <count> [name]: shopping list line, with what you have (information)
register("reagent", 2, function(a) return { item = a[1], count = a[2], text = a.rest } end, {
  primary = false,
  status = function(goal)
    local have = R.ItemCount(goal.item)
    return have >= goal.count and "done" or "info", ("%d/%d"):format(math.min(have, goal.count), goal.count)
  end,
  text = function(goal, text)
    return L.GOAL_REAGENT:format(R.ItemName(goal.item) or text or ("#" .. goal.item))
  end,
})

-- currency <currencyID> <amount> [name]
register("currency", 2, function(a) return { currency = a[1], amount = a[2], text = a.rest } end, {
  status = function(goal)
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(goal.currency)
    local have = info and info.quantity or 0
    return have >= goal.amount and "done" or "todo", ("%d/%d"):format(math.min(have, goal.amount), goal.amount)
  end,
  text = function(goal, text)
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(goal.currency)
    return L.GOAL_CURRENCY:format(goal.amount, (info and info.name) or text or "?")
  end,
})

-- farm <mountID> <journalInstanceID> <boss>: done when the mount is collected,
-- or when the boss is already killed for this reset (come back next week)
register("farm", 2, function(a) return { mount = a[1], instance = a[2], boss = a.rest } end, {
  status = function(goal)
    local _, collected = R.MountInfo(goal.mount)
    if collected then return "done" end
    if R.IsBossKilled(goal.instance, goal.boss) then return "done", L.KILLED_THIS_WEEK end
    return "todo"
  end,
  text = function(goal)
    return L.GOAL_FARM:format(goal.boss or "?", R.InstanceName(goal.instance) or "?",
      R.MountInfo(goal.mount) or ("#" .. goal.mount))
  end,
})

-- profopen <baseSkillLineID> [name]: the profession window was read once
register("profopen", 1, function(a) return { skillLine = a[1], text = a.rest } end, {
  status = function(goal)
    return R.profs[goal.skillLine] and "done" or "todo"
  end,
  text = function(goal, text) return L.GOAL_PROFOPEN:format(text or "?") end,
})

-- achieve <achievementID> [name]: with criteria progress on Retail
ns.GoalTypes.achieve = {
  status = function(goal)
    if not GetAchievementInfo then return "info" end
    local id, _, _, completed = GetAchievementInfo(goal.achievement)
    if not id then return "info" end
    if completed then return "done" end
    local n = GetAchievementNumCriteria and GetAchievementNumCriteria(goal.achievement) or 0
    if n == 1 then
      local _, _, _, quantity, reqQuantity = GetAchievementCriteriaInfo(goal.achievement, 1)
      if reqQuantity and reqQuantity > 1 then return "todo", ("%d/%d"):format(quantity or 0, reqQuantity) end
    elseif n > 1 then
      local doneN = 0
      for i = 1, n do
        local _, _, c = GetAchievementCriteriaInfo(goal.achievement, i)
        if c then doneN = doneN + 1 end
      end
      return "todo", ("%d/%d"):format(doneN, n)
    end
    return "todo"
  end,
  text = function(goal, text)
    local _, name = GetAchievementInfo and GetAchievementInfo(goal.achievement)
    return L.GOAL_ACHIEVE:format(name or text or ("#" .. goal.achievement))
  end,
}

ns.RegisterEvent("UPDATE_INSTANCE_INFO", function() R.ScanLockouts() ns.Engine:QueueRefresh() end)
ns.RegisterEvent("NEW_MOUNT_ADDED", function() ns.Engine:QueueRefresh() end)
ns.RegisterEvent("CURRENCY_DISPLAY_UPDATE", function() ns.Engine:QueueRefresh() end)
ns.RegisterEvent("CRITERIA_UPDATE", function() ns.Engine:QueueRefresh() end)
ns.On("INIT", function()
  if RequestRaidInfo then RequestRaidInfo() end -- fills the saved-instance list
end)
