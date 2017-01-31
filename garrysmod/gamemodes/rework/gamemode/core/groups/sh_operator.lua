--[[ 
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before 
	the framework is publicly released.
--]]

GROUP:SetName("Operator");
GROUP:SetDescription("A staff member that watches the players.");
GROUP:SetColor(Color(255, 255, 255));
GROUP:SetIcon("icon16/smile.png");
GROUP:SetImmunity(100);
GROUP:SetBase("user");
GROUP:SetPermissions({
	test = PERM_ALLOW
});