--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local COMMAND = Command("playsound");
COMMAND.name = "PlaySound";
COMMAND.description = "Plays a sound file from a URL to all players or a specific player.";
COMMAND.category = "server_management";
COMMAND.syntax = "[string URL] [number 0-1 Volume] [string Target]";
COMMAND.arguments = 1;

function COMMAND:OnRun(player, url, volume, target)
	if (target and target != "") then
		target = _player.Find(target);

		if (!IsValid(target) or !isentity(target)) then
			target = nil;
		end;
	else
		target = nil;
	end;

	netstream.Start(target, "RWPlaySound", url, volume);
end;

COMMAND:Register();

if (CLIENT) then
	netstream.Hook("RWPlaySound", function(url, volume)
		rw.sound:PlayFromURL(url, volume);
	end);
end;