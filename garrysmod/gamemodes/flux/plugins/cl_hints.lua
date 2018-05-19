--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

PLUGIN:SetAlias("flHints")
PLUGIN:SetName("Hints")
PLUGIN:SetDescription("Adds hints that are displayed to players.")
PLUGIN:SetAuthor("Mr. Meow")

local stored = {}

function flHints:Add(id, text, color, bPlaySound, callback)
  table.insert(stored, {id = id, text = text, color = color, playSound = bPlaySound or false, callback = callback})
end

function flHints:DisplayRandom()
  local hint = table.Random(stored)

  if (hint.callback and hint.callback() != true) then return end
  if (hint.playSound) then surface.PlaySound("hl1/fvox/blip.wav") end

  fl.notification:Add(hint.text, 15, hint.color)
end

function flHints:OneMinute()
  local curTime = CurTime()

  if (curTime >= (fl.client.nextHint or 0)) then
    flHints:DisplayRandom()

    fl.client.nextHint = curTime + 300
  end
end

do
  flHints:Add("#Hint_Forums", "#Hint_ForumsText")
  flHints:Add("#Hint_Hints", "#Hint_HintsText")
  flHints:Add("#Hint_TAB", "#Hint_TABText")
  flHints:Add("#Hint_Inventory", "#Hint_InventoryText")
  flHints:Add("#Hint_Commands", "#Hint_CommandsText")
  flHints:Add("#Hint_Bugs", "#Hint_BugsText")
end
