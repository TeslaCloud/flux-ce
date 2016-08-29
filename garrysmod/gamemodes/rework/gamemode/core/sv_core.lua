--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

oldFileioWrite = oldFileioWrite or fileio.Write;

function fileio.Write(fileName, content)
	local exploded = string.Explode("/", fileName);
	local curPath = "";

	for k, v in ipairs(exploded) do
		if (string.GetExtensionFromFilename(v) != nil) then
			break;
		end;

		curPath = curPath..v.."/";

		if (!file.Exists(curPath, "GAME")) then
			fileio.MakeDirectory(curPath);
		end;
	end;

	oldFileioWrite(fileName, content);
end;

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