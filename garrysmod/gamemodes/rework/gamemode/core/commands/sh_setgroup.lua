--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local COMMAND = Command("setgroup");
COMMAND.name = "SetGroup";
COMMAND.description = "Sets player's usergroup.";
COMMAND.syntax = "<target> <usergroup>";
COMMAND.category = "player_management";
COMMAND.arguments = 1;
COMMAND.immunity = true;
COMMAND.aliases = {"plysetgroup", "setusergroup", "plysetusergroup"};

function COMMAND:OnRun(player, target, userGroup)
	if (rw.admin:GroupExists(userGroup)) then
		rw.player:SetUserGroup(target, userGroup);

		rw.player:NotifyAll(((IsValid(player) and player:Name()) or "Console").." has set "..target:Name().."'s user group to "..userGroup..".");
	else
		rw.player:Notify(player, "'"..userGroup.."' is not a valid user group!");
	end;
end;

COMMAND:Register();