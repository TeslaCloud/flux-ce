--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

local COMMAND = Command("kick");
COMMAND.name = "Kick";
COMMAND.description = "Kicks player from the server.";
COMMAND.syntax = "<target> [reason]";
COMMAND.arguments = 1;
COMMAND.immunity = true;

function COMMAND:OnRun(player, target, ...)
	local pieces = {...};
	local reason = "Kicked for unspecified reason.";

	if (#pieces > 0) then
		reason = string.Implode(" ", pieces);
	end;

	target:Kick(reason);
end;

COMMAND:Register();