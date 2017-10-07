--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}

function PANEL:Init()

end

function PANEL:GetMenuSize()
	return font.Scale(800), font.Scale(600)
end

vgui.Register("flScoreboard", PANEL, "flBasePanel")