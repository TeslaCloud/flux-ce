--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

local OPERATOR = Group("operator");
	OPERATOR:SetName("Operator");
	OPERATOR:SetDescription("A staff member that watches the players.");
	OPERATOR:SetColor(Color(255, 255, 255));
	OPERATOR:SetIcon("icon16/smile.png");
	OPERATOR:SetImmunity(100);
	OPERATOR:SetBase("user");
	OPERATOR:SetPermissions({
		test = PERM_ALLOW
	})

OPERATOR:Register();