--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

GROUP:SetName("Owner")
GROUP:SetDescription("#PlayerGroup_Owner")
GROUP:SetColor(Color(255, 255, 255))
GROUP:SetIcon("icon16/key.png")
GROUP:SetImmunity(1000)
GROUP:SetBase("superadmin")
GROUP:SetPermissions({
	all = PERM_ALLOW_OVERRIDE
});