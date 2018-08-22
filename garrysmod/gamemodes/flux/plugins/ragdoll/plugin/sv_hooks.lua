--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]function PLUGIN:PlayerDeath(player)
  player:SetRagdollState(RAGDOLL_DUMMY)
end

function PLUGIN:PlayerSpawn(player)
  player:SetRagdollState(RAGDOLL_NONE)
end
