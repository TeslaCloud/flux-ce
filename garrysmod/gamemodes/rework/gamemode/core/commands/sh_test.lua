--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

local COMMAND = Command("test");
COMMAND.name = "Test";
COMMAND.description = "A test command.";
COMMAND.syntax = "<arg1> [arg2]";
COMMAND.arguments = 1;

function COMMAND:OnRun(player, arg1, arg2)
	print("Test command has been run!");
	
	print("arg1: "..arg1, "arg2: "..(arg2 or "[undefined]"));
end;

COMMAND:Register();