--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("flCharacters")

util.Include("cl_hooks.lua")
util.Include("sv_plugin.lua")
util.Include("sv_hooks.lua")
util.Include("sh_enums.lua")

if (CLIENT) then
	if (IsValid(fl.IntroPanel)) then
		fl.IntroPanel:Remove()

		fl.IntroPanel = vgui.Create("flIntro")
		fl.IntroPanel:MakePopup()
	end
end