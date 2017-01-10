--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local ADMIN = Group("admin");
	ADMIN:SetName("Administrator");
	ADMIN:SetDescription("A staff member that watches operators and players.");
	ADMIN:SetColor(Color(255, 255, 255));
	ADMIN:SetIcon("icon16/star.png");
	ADMIN:SetImmunity(200);
	ADMIN:SetBase("operator");
	ADMIN:SetPermissions({
		test = PERM_ALLOW
	})

ADMIN:Register();