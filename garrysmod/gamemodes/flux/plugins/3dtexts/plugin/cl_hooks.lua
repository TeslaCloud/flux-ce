--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function fl3DText:PostDrawOpaqueRenderables()
	local weapon = fl.client:GetActiveWeapon()

	if (IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "texts") then
		local tool = fl.client:GetTool()
		local text = tool:GetClientInfo("text")
		local scale = tool:GetClientNumber("scale")
		local style = tool:GetClientNumber("style")
		local color = Color(tool:GetClientInfo("color") or "white")
		local trace = fl.client:GetEyeTrace()
		local pos = trace.HitPos
		local normal = trace.HitNormal
		local angle = normal:Angle()
		local w, h = util.GetTextSize(text, theme.GetFont("Text_3D2D"))
		angle:RotateAroundAxis(angle:Forward(), 90)
		angle:RotateAroundAxis(angle:Right(), 270)

		cam.Start3D2D(pos + (normal * 1.25), angle, 0.1 * scale)
			if (style >= 5) then
				local extraColor = Color(tool:GetClientInfo("extraColor") or "#FF000033")
				draw.RoundedBox(0, -w / 2 - 32, -h / 2 - 16, w + 64, h + 32, ColorAlpha(extraColor, 40))
			end

			draw.SimpleText(text, theme.GetFont("Text_3D2D"), -w / 2, -h / 2, ColorAlpha(color, 60))
		cam.End3D2D()
	end

	for k, v in pairs(self.stored) do
		local pos = v.pos
		local clientPos = fl.client:GetPos()
		local distance = clientPos:Distance(pos)
		local fadeOffset = v.fadeOffset or 1000
		local drawDistance = (1024 + fadeOffset)

		if (distance > drawDistance) then continue end

		local fadeAlpha = 255
		local fadeDistance = (768 + fadeOffset)

		if (distance > fadeDistance) then
			local d = distance - fadeDistance
			fadeAlpha = math.Clamp((255 * ((drawDistance - fadeDistance) - d) / (drawDistance - fadeDistance)), 0, 255)
		end

		local angle = v.angle
		local normal = v.normal
		local scale = v.scale
		local text = v.text
		local textColor = v.color
		local backColor = v.extraColor
		local style = v.style
		local w, h = util.GetTextSize(text, theme.GetFont("Text_3D2D"))
		local posX, posY = -w / 2, -h / 2

		if (style >= 2) then
			cam.Start3D2D(pos + (normal * 0.4), angle, 0.1 * scale)
				if (style >= 5) then
					local boxAlpha = backColor.a

					if (style >= 6) then
						boxAlpha = boxAlpha * math.abs(math.sin(CurTime() * 3))
					end

					draw.RoundedBox(0, posX - 32, posY - 16, w + 64, h + 32, ColorAlpha(v.extraColor, math.Clamp(fadeAlpha, 0, boxAlpha)))
				end

				if (style != 3) then
					draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, ColorAlpha(textColor, math.Clamp(fadeAlpha, 0, 160)):Darken(30))
				end
			cam.End3D2D()
		end

		if (style >= 3) then
			cam.Start3D2D(pos + (normal * 0.95), angle, 0.1 * scale)
				draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, Color(0, 0, 0, math.Clamp(fadeAlpha, 0, 240)))
			cam.End3D2D()
		end

		cam.Start3D2D(pos + (normal * 1.25), angle, 0.1 * scale)
			draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, ColorAlpha(textColor, fadeAlpha))
		cam.End3D2D()
	end
end