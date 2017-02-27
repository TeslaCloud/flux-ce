--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetName("Rework Dev HUD")
PLUGIN:SetAuthor("Mr. Meow")
PLUGIN:SetDescription("Adds developer HUD.")

function PLUGIN:HUDPaint()
	if (rw.Devmode) then
		draw.SimpleText("Rework version "..(GAMEMODE.Version or "UNKNOWN")..", developer mode on.", "default", 8, ScrH() - 18, Color(200, 200, 200, 200))
	end
end