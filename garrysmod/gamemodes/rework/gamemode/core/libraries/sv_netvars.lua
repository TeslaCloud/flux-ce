--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (netvars) then return end

library.New("netvars", _G)

local stored = netvars.stored or {}
netvars.stored = stored

local globals = netvars.globals or {}
netvars.globals = globals

local entityMeta = FindMetaTable("Entity")
local playerMeta = FindMetaTable("Player")

local function IsBadType(key, val)
	if (isfunction(val)) then
		ErrorNoHalt("[Rework] Cannot store functions as NetVars! ("..key..")\n")

		return true
	end

	return false
end

function netvars.GetNetVar(key, default)
	if (globals[key] != nil) then
		return globals[key]
	end

	return default
end

function netvars.SetNetVar(key, value, send)
	if (IsBadType(key, value)) then return end
	if (netvars.GetNetVar(key) == value) then return end

	globals[key] = value

	netstream.Start(send, "nv_globals", key, value)
end

function entityMeta:SendNetVar(key, recv)
	netstream.Start(recv, "nv_vars", self:EntIndex(), key, (stored[self] and stored[self][key]))
end

function entityMeta:GetNetVar(key, default)
	if (stored[self] and stored[self][key] != nil) then
		return stored[self][key]
	end

	return default
end

function entityMeta:ClearNetVars(recv)
	stored[self] = nil
	netstream.Start(recv, "nv_delete", self:EntIndex())
end

function entityMeta:SetNetVar(key, value, send)
	if (IsBadType(key, value)) then return end
	if (!istable(value) and self:GetNetVar(key) == value) then return end

	stored[self] = stored[self] or {}
	stored[self][key] = value

	self:SendNetVar(key, send)
end

function playerMeta:SyncNetVars()
	for k, v in pairs(globals) do
		netstream.Start(self, "nv_globals", k, v)
	end

	for k, v in pairs(stored) do
		if (IsValid(k)) then
			for k2, v2 in pairs(v) do
				netstream.Start(self, "nv_vars", k:EntIndex(), k2, v2)
			end
		end
	end
end