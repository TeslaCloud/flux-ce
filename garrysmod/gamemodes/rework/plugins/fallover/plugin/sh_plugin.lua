--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

rw.core:Include("sv_plugin.lua");
rw.core:Include("sv_hooks.lua");

function PLUGIN:PlayerSetupDataTables(player)
	player:DTVar("Int", INT_RAGDOLL_STATE, "RagdollState");
end;