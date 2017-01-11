--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local COMMAND = Command("giveitem");
COMMAND.name = "GiveItem";
COMMAND.description = "Gives specified item to a player.";
COMMAND.syntax = "<string target> <string item name or unique ID>";
COMMAND.category = "character_management";
COMMAND.arguments = 2;
COMMAND.playerArg = 1;
COMMAND.aliases = {"chargiveitem", "plygiveitem"};

function COMMAND:OnRun(player, target, itemName, amount)
	local itemTable = item.Find(itemName);

	if (itemTable) then
		amount = tonumber(amount) or 1;
		for i = 1, amount do
			target:GiveItem(itemTable.uniqueID);
		end;

		rw.player:Notify(player, "You have given "..amount.." "..itemTable.Name.."'s to "..target:Name()..".");
		rw.player:Notify(target, player:Name().." has given you "..amount.." "..itemTable.Name.."'s.");
	else
		rw.player:Notify(player, "'"..itemName.."' is not a valid item!");
	end;
end;

COMMAND:Register();