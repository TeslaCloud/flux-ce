--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local playerMeta = FindMetaTable("Player");

function playerMeta:HasInitialized()
	return self:GetDTBool(BOOL_INITIALIZED) or false;
end;

function playerMeta:SetInitialized(bIsInitialized)
	if (bIsInitialized == nil) then bIsInitialized = true; end;
	
	self:SetDTBool(BOOL_INITIALIZED, bIsInitialized);
end;