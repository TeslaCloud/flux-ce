--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

local OPERATOR = Group("operator");
	OPERATOR:SetName("Operator");
	OPERATOR:SetDescription("A staff member that watches the players.");
	OPERATOR:SetColor(Color(255, 255, 255));
	OPERATOR:SetImmunity(100);
	OPERATOR:SetBase("user");
	OPERATOR:SetPermissions({
		test = PERM_ALLOW
	})
	
OPERATOR:Register();