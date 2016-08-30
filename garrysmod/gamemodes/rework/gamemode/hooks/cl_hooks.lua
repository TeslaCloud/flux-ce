--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

function GM:InitPostEntity()
	rw.client = rw.client or LocalPlayer();
end;

netstream.Hook("SharedTables", function(sharedTable)
	rw.sharedTable = sharedTable or {};
end);