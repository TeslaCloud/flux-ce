--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

netstream.Hook("SchemaInfo", function(schemaTable)
	rw.core.SchemaInfo = schemaTable or {};
end);