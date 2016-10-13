--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local OWNER = Group("owner");
	OWNER:SetName("Owner");
	OWNER:SetDescription("Ultimate staff member who runs this server.");
	OWNER:SetColor(Color(255, 255, 255));
	OWNER:SetIcon("icon16/key.png");
	OWNER:SetImmunity(1000);
	OWNER:SetBase("superadmin");
	OWNER:SetPermissions({
		all = PERM_ALLOW_OVERRIDE
	})

OWNER:Register();