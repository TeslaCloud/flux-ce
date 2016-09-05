--[[ 
	Rework © 2016 TeslaCloud Studios
	Do not share, re-distribute or sell.
--]]

local SUPERADMIN = Group("superadmin");
	SUPERADMIN:SetName("Super Admin");
	SUPERADMIN:SetDescription("A staff member that overwatches server's administration and the server itself.");
	SUPERADMIN:SetColor(Color(255, 255, 255));
	SUPERADMIN:SetIcon("icon16/shield.png");
	SUPERADMIN:SetImmunity(300);
	SUPERADMIN:SetBase("admin");
	SUPERADMIN:SetPermissions({
		server_management = PERM_ALLOW,
		player_management = PERM_ALLOW
	})
	
SUPERADMIN:Register();