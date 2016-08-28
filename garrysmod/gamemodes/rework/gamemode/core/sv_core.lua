--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

-- A function to get the schema gamemode info.
function rw.core:GetSchemaInfo()
	if (self.SchemaInfo) then return self.SchemaInfo; end;

	local schemaFolder = string.lower(self:GetSchemaFolder());
	local schemaData = util.KeyValuesToTable(
		fileio.Read("gamemodes/"..schemaFolder.."/"..schemaFolder..".txt")
	);

	if (!schemaData) then
		schemaData = {};
	end;

	if (schemaData["Gamemode"]) then
		schemaData = schemaData["Gamemode"];
	end;

	self.SchemaInfo = {};
		self.SchemaInfo["name"] = schemaData["title"] or "Undefined";
		self.SchemaInfo["author"] = schemaData["author"] or "Undefined";
		self.SchemaInfo["description"] = schemaData["description"] or "Undefined";
		self.SchemaInfo["version"] = schemaData["version"] or "Undefined";
	return self.SchemaInfo;
end;