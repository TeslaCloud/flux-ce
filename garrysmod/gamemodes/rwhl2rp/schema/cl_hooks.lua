--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function Schema:HUDPaint()
	rw.client.colorModify = true

	rw.client.colorModifyTable = {
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0.01,
		["$pp_colour_brightness"] = 0,
		["$pp_colour_contrast"] = 1,
		["$pp_colour_colour"] = 0.85,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	}

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(util.GetMaterial("materials/rework/hl2rp/vignette.png"))
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end