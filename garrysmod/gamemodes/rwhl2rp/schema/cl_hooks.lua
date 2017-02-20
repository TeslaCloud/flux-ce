--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function Schema:HUDPaint()
	rw.core:EnableColorModify()
	rw.core:SetColorModifyVal("color", 0.85)
	rw.core:SetColorModifyVal("addb", 0.015)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(util.GetMaterial("materials/rework/hl2rp/vignette.png"))
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end