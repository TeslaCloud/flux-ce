--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

GROUP:SetName("Operator");
GROUP:SetDescription("An administrative rank below superadmin.");
GROUP:SetColor(Color(255, 255, 255));
GROUP:SetIcon("icon16/smile.png");
GROUP:SetImmunity(100);
GROUP:SetBase("user");
GROUP:SetPermissions({
	test = PERM_ALLOW
});