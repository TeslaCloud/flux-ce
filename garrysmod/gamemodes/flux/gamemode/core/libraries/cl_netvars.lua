--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (netvars) then return end

library.New "netvars"

local stored = netvars.stored or {}
netvars.stored = stored

local globals = netvars.globals or {}
netvars.globals = globals

local entityMeta = FindMetaTable("Entity")

-- A function to get a networked global.
function netvars.GetNetVar(key, default)
	if (globals[key] != nil) then
		return globals[key]
	end

	return default
end

-- Cannot set them on client.
function netvars.SetNetVar() end

-- A function to get entity's networked variable.
function entityMeta:GetNetVar(key, default)
	local index = self:EntIndex()

	if (stored[index] and stored[index][key] != nil) then
		return stored[index][key]
	end

	return default
end

-- Called from the server to set global networked variables.
netstream.Hook("net_globals", function(key, value)
	if (key and value != nil) then
		globals[key] = value
	end
end)

-- Called from the server to set entity's networked variable.
netstream.Hook("net_var", function(entIdx, key, value)
	if (key and value != nil) then
		stored[entIdx] = stored[entIdx] or {}
		stored[entIdx][key] = value
	end
end)

-- Called from the server to delete entity from networked table.
netstream.Hook("net_delete", function(entIdx)
	stored[entIdx] = nil
end)