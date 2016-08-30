--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

if (netvars) then return; end;

library.New("netvars", _G);
local stored = {};
local globals = {};
local entityMeta = FindMetaTable("Entity");

function netvars.GetNetVar(key, default)
	if (globals[key] != nil) then
		return globals[key];
	end;

	return default;
end;

-- Cannot set them on client.
function netvars.SetNetVar() end;

function entityMeta:GetNetVar(key, default)
	if (stored[self] and stored[self][key] != nil) then
		return stored[self][key];
	end;

	return default;
end;

netstream.Hook("nv_globals", function(key, value)
	if (key and value != nil) then
		globals[key] = value;
	end;
end);

netstream.Hook("nv_vars", function(entIdx, key, value)
	if (key and value != nil) then
		stored[entIdx] = stored[entIdx] or {};
		stored[entIdx][key] = value;
	end;
end);

netstream.Hook("nv_delete", function(entIdx)
	stored[entIdx] = nil;
end);