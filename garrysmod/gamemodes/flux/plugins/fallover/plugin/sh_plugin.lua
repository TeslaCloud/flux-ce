--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

util.Include("sv_plugin.lua")
util.Include("sv_hooks.lua")

function PLUGIN:PlayerSetupDataTables(player)
	player:DTVar("Int", INT_RAGDOLL_STATE, "RagdollState")
	player:DTVar("Entity", ENT_RAGDOLL, "RagdollEntity")
end