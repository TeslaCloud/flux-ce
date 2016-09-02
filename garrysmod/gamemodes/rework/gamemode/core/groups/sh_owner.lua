--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

local OWNER = Group("owner");
	OWNER:SetName("Owner");
	OWNER:SetDescription("Ultimate staff member who runs this server.");
	OWNER:SetColor(Color(255, 255, 255));
	OWNER:SetImmunity(1000);
	OWNER:SetBase("superadmin");
	OWNER:SetPermissions({
		all = PERM_ALLOW_OVERRIDE,
		test = PERM_ALLOW
	})
	
OWNER:Register();