--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local COMMAND = Command("giveitem")
COMMAND.name = "GiveItem"
COMMAND.description = "Gives specified item to a player."
COMMAND.syntax = "<string target> <string item name or unique ID>"
COMMAND.category = "character_management"
COMMAND.arguments = 2
COMMAND.playerArg = 1
COMMAND.aliases = {"chargiveitem", "plygiveitem"}

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