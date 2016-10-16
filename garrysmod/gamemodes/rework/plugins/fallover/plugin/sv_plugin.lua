--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local playerMeta = FindMetaTable("Player");

function playerMeta:SetRagdollState(state)
	self:SetDTInt(INT_RAGDOLL_STATE, (state or RAGDOLL_NONE));
end;