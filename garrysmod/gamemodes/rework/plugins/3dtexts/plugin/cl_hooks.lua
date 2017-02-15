--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local queue = {}

function rw3DText:PostDrawOpaqueRenderables()
	for k, v in pairs(self.stored) do
		local pos = v.pos
		local angle = v.angle
		local normal = v.normal
		local text = v.text
		local textColor = v.color
		local backColor = v.extraColor
		local style = v.style
		local w, h = util.GetTextSize(text, theme.GetFont("Text_3D2D"))
		local posX, posY = -w / 2, -h / 2

		if (style >= 2) then
			cam.Start3D2D(pos + (normal * 0.3), angle, 0.1)
				if (style >= 5) then
					draw.RoundedBox(0, posX - 32, posY - 16, w + 64, h + 32, backColor)
				end

				if (style != 3) then
					draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, ColorAlpha(textColor, 160):Darken(30))
				end
			cam.End3D2D()
		end

		if (style >= 3) then
			cam.Start3D2D(pos + (normal * 0.95), angle, 0.1)
				draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, Color(0, 0, 0, 240))
			cam.End3D2D()
		end

		cam.Start3D2D(pos + (normal * 1.25), angle, 0.1)
			draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, textColor)
		cam.End3D2D()
	end
end