--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}

function PANEL:Init()

end

function PANEL:GetMenuSize()
	return font.Scale(1280), font.Scale(900)
end

vgui.Register("flScoreboard", PANEL, "flFrame")