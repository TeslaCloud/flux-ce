--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

function GM:InitPostEntity()
	rw.client = rw.client or LocalPlayer();
end;

function GM:HUDDrawScoreBoard()
	if (!rw.client:HasInitialized()) then
		draw.RoundedBox(0, 0, 0, ScrW(), ScrH(), Color(0, 0, 0));
	end;
end;

netstream.Hook("SharedTables", function(sharedTable)
	rw.sharedTable = sharedTable or {};
end);