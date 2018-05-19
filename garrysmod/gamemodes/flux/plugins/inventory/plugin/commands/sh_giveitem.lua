--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

local COMMAND = Command("giveitem")
COMMAND.Name = "GiveItem"
COMMAND.Description = "Gives specified item to a player."
COMMAND.Syntax = "<string target> <string item name or unique ID>"
COMMAND.Category = "character_management"
COMMAND.Arguments = 2
COMMAND.PlayerArg = 1
COMMAND.Aliases = {"chargiveitem", "plygiveitem"}

function COMMAND:OnRun(player, targets, itemName, amount)
  local itemTable = item.Find(itemName)

  if (itemTable) then
    amount = tonumber(amount) or 1

    for k, v in ipairs(targets) do
      for i = 1, amount do
        v:GiveItem(itemTable.uniqueID)
      end

      fl.player:Notify(v, ((IsValid(player) and player:Name()) or "Console").." has given you "..amount.." "..itemTable.Name.."'s.")
    end

    fl.player:Notify(player, "You have given "..amount.." "..itemTable.Name.."'s to "..util.PlayerListToString(targets)..".")
  else
    fl.player:Notify(player, "'"..itemName.."' is not a valid item!")
  end
end

COMMAND:Register()
