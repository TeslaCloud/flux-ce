--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

Class "Command";

Command.uniqueID = "undefined";
Command.name = "Unknown";
Command.description = "An undescribed command.";
Command.syntax = "[none]";
Command.immunity = false;
Command.playerArg = nil;
Command.arguments = 0;
Command.noConsole = false;

function Command:Command(id)
	self.uniqueID = id;
end;

function Command:OnRun() end;

function Command:Register()
	rw.command:Create(self.uniqueID, self);
end;