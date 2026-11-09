local _, ns = ...
local Engine = ns.Engine

-- Optional automation (/freegor auto): accepts and turns in the quests named in
-- the current guide step and the next few steps. Hold Shift to suspend it.
-- Quests with several reward choices are left to the player.

local LOOKAHEAD = 3

local function wanted()
  local accept, turnin = {}, {}
  local g = Engine.guide
  if not g then return accept, turnin end
  local seen, i = 0, Engine.stepIndex
  while g.steps[i] and seen <= LOOKAHEAD do
    local step = g.steps[i]
    if Engine:StepApplies(step) then
      seen = seen + 1
      for _, goal in ipairs(step.goals) do
        if goal.type == "accept" then accept[goal.quest] = true end
        if goal.type == "turnin" then turnin[goal.quest] = true end
      end
    end
    i = i + 1
  end
  return accept, turnin
end

local function enabled()
  return ns.db.autoQuest and Engine.guide and not IsShiftKeyDown()
end

local function currentQuestID()
  local id = GetQuestID and GetQuestID()
  return id and id > 0 and id or nil
end

ns.RegisterEvent("QUEST_DETAIL", function()
  if not enabled() then return end
  local id = currentQuestID()
  local accept = wanted()
  if id and accept[id] then AcceptQuest() end
end)

ns.RegisterEvent("QUEST_PROGRESS", function()
  if not enabled() then return end
  local id = currentQuestID()
  local _, turnin = wanted()
  if id and turnin[id] and IsQuestCompletable() then CompleteQuest() end
end)

ns.RegisterEvent("QUEST_COMPLETE", function()
  if not enabled() then return end
  local id = currentQuestID()
  local _, turnin = wanted()
  if not (id and turnin[id]) then return end
  local choices = GetNumQuestChoices() or 0
  if choices <= 1 then GetQuestReward(choices) end
end)

-- Modern gossip window (quest lists by quest ID).
ns.RegisterEvent("GOSSIP_SHOW", function()
  if not enabled() then return end
  local G = C_GossipInfo
  if not G then return end
  local accept, turnin = wanted()
  for _, q in ipairs(G.GetActiveQuests and G.GetActiveQuests() or {}) do
    if q.questID and turnin[q.questID] and q.isComplete then
      return G.SelectActiveQuest(q.questID)
    end
  end
  for _, q in ipairs(G.GetAvailableQuests and G.GetAvailableQuests() or {}) do
    if q.questID and accept[q.questID] then
      return G.SelectAvailableQuest(q.questID)
    end
  end
end)

-- Older quest greeting window (numbered buttons).
ns.RegisterEvent("QUEST_GREETING", function()
  if not enabled() then return end
  local accept, turnin = wanted()
  if GetActiveQuestID then
    for i = 1, (GetNumActiveQuests() or 0) do
      local id = GetActiveQuestID(i)
      local _, complete = GetActiveTitle(i)
      if id and turnin[id] and complete then return SelectActiveQuest(i) end
    end
  end
  if GetAvailableQuestInfo then
    for i = 1, (GetNumAvailableQuests() or 0) do
      local id = select(5, GetAvailableQuestInfo(i))
      if id and accept[id] then return SelectAvailableQuest(i) end
    end
  end
end)

function ns.ToggleAutoQuest()
  ns.db.autoQuest = not ns.db.autoQuest
  ns.Print(ns.db.autoQuest and ns.L.AUTO_ON or ns.L.AUTO_OFF)
end
