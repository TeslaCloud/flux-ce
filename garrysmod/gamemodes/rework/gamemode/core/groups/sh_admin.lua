--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

GROUP:SetName("Administrator");
GROUP:SetDescription("A staff member that watches operators and players.");
GROUP:SetColor(Color(255, 255, 255));
GROUP:SetIcon("icon16/star.png");
GROUP:SetImmunity(200);
GROUP:SetBase("operator");
GROUP:SetPermissions({
	test = PERM_ALLOW
});