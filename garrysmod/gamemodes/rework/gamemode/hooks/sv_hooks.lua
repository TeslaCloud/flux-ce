--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

function GM:PlayerInitialSpawn(player)
	netstream.Start(player, "SchemaInfo", rw.core:GetSchemaInfo());
end;