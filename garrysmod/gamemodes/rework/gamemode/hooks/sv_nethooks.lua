--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

netstream.Hook("ClientIncludedSchema", function(player)
	character.Load(player);
end);