--[[ 
	Rework © 2016 Mr. Meow and NightAngel
	Do not share, re-distribute or sell.
--]]

local SUPERADMIN = Group("superadmin");
	SUPERADMIN:SetName("Super Admin");
	SUPERADMIN:SetDescription("A staff member that overwatches server's administration and the server itself.");
	SUPERADMIN:SetColor(Color(255, 255, 255));
	SUPERADMIN:SetImmunity(300);
	SUPERADMIN:SetBase("admin");
	SUPERADMIN:SetPermissions({
		test = PERM_ALLOW
	})
	
SUPERADMIN:Register();