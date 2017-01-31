--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

GROUP:SetName("Super Admin");
GROUP:SetDescription("A staff member that overwatches server's administration and the server itself.");
GROUP:SetColor(Color(255, 255, 255));
GROUP:SetIcon("icon16/shield.png");
GROUP:SetImmunity(300);
GROUP:SetBase("admin");
GROUP:SetPermissions({
	server_management = PERM_ALLOW,
	player_management = PERM_ALLOW,
	character_management = PERM_ALLOW
});