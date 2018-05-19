--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function PLUGIN:PlayerDeath(player)
	player:SetRagdollState(RAGDOLL_DUMMY)
end

function PLUGIN:PlayerSpawn(player)
	player:SetRagdollState(RAGDOLL_NONE)
end
