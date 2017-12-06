--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local blurTexture = Material("pp/blurscreen")

function fl3DText:PostDrawOpaqueRenderables()
	local weapon = fl.client:GetActiveWeapon()
	local clientPos = fl.client:GetPos()

	if (IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "texts") then
		local tool = fl.client:GetTool()
		local text = tool:GetClientInfo("text")
		local style = tool:GetClientNumber("style")
		local trace = fl.client:GetEyeTrace()
		local normal = trace.HitNormal
		local w, h = util.GetTextSize(text, theme.GetFont("Text_3D2D"))
		local angle = normal:Angle()
		angle:RotateAroundAxis(angle:Forward(), 90)
		angle:RotateAroundAxis(angle:Right(), 270)

		cam.Start3D2D(trace.HitPos + (normal * 1.25), angle, 0.1 * tool:GetClientNumber("scale"))
			if (style >= 5) then
				if (style != 8 and style != 9) then
					draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 - 16, w + 64, h + 32, ColorAlpha(Color(tool:GetClientInfo("extraColor") or "#FF000033"), 40))
				end

				if (style == 7 or style == 8) then
					draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 - 16, w + 64, 6, Color(255, 255, 255, 40))
					draw.RoundedBox(0, -w * 0.5 - 32, -h * 0.5 + h + 10, w + 64, 6, Color(255, 255, 255, 40))
				elseif (style == 9) then
					local wide = w + 64
					local barColor = Color(255, 255, 255, 40)
					local barX, barY = -w * 0.5 - 32, -h * 0.5 - 16
					local rectWidth = (wide / 3 - wide / 6) * 0.75

					-- Draw left thick rectangles
					draw.RoundedBox(0, barX, barY - 6, rectWidth, 10, barColor)
					draw.RoundedBox(0, barX, barY + h + 22, rectWidth, 10, barColor)

					-- ...and the right ones
					draw.RoundedBox(0, barX + wide - rectWidth, barY - 6, rectWidth, 10, barColor)
					draw.RoundedBox(0, barX + wide - rectWidth, barY + h + 22, rectWidth, 10, barColor)

					-- And the middle thingies
					draw.RoundedBox(0, -(wide / 1.75) * 0.5, barY, wide / 1.75, 4, barColor)
					draw.RoundedBox(0, -(wide / 1.75) * 0.5, barY + h + 22, wide / 1.75, 4, barColor)
				end
			end

			draw.SimpleText(text, theme.GetFont("Text_3D2D"), -w * 0.5, -h * 0.5, ColorAlpha(Color(tool:GetClientInfo("color") or "white"), 60))
		cam.End3D2D()
	end

	for k, v in ipairs(self.stored) do
		local pos = v.pos
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
		local posX, posY = -w * 0.5, -h * 0.5

		if (style >= 2) then
			cam.Start3D2D(pos + (normal * 0.4), angle, 0.1 * scale)
				if (style >= 5) then
					local boxAlpha = backColor.a
					local boxX, boxY = posX - 32, posY - 16

					if (style == 6) then
						boxAlpha = boxAlpha * math.abs(math.sin(CurTime() * 3))
					end

					if (style == 10) then
						render.ClearStencil()
						render.SetStencilEnable(true)
						render.SetStencilCompareFunction(STENCIL_ALWAYS)
						render.SetStencilPassOperation(STENCIL_REPLACE)
						render.SetStencilFailOperation(STENCIL_KEEP)
						render.SetStencilZFailOperation(STENCIL_KEEP)
						render.SetStencilWriteMask(254)
						render.SetStencilTestMask(254)
						render.SetStencilReferenceValue(ref or 75)

						surface.SetDrawColor(255, 255, 255, 10)
						surface.DrawRect(boxX, boxY, w + 64, h + 32)

						render.SetStencilCompareFunction(STENCIL_EQUAL)

						render.SetMaterial(blurTexture)

						for i = 0, 1, 0.2 do
							blurTexture:SetFloat("$blur", i * 8)
							blurTexture:Recompute()
							render.UpdateScreenEffectTexture()
							render.DrawScreenQuad()
						end

						render.SetStencilEnable(false)

						surface.SetDrawColor(ColorAlpha(backColor, 10))
						surface.DrawRect(boxX, boxY, w + 64, h + 32)
					elseif (style != 8 and style != 9) then
						draw.RoundedBox(0, boxX, posY - 16, w + 64, h + 32, ColorAlpha(v.extraColor, math.Clamp(fadeAlpha, 0, boxAlpha)))
					end

					if (style == 7 or style == 8) then
						local barColor = Color(255, 255, 255, math.Clamp(fadeAlpha, 0, boxAlpha))

						draw.RoundedBox(0, boxX, boxY, w + 64, 6, barColor)
						draw.RoundedBox(0, boxX, boxY + h + 26, w + 64, 6, barColor)
					elseif (style == 9) then
						local tall, wide = 6, w + 64
						local rectWidth = (wide / 3 - wide / 6) * 0.75
						local barColor = Color(255, 255, 255, math.Clamp(fadeAlpha, 0, boxAlpha))

						-- Draw left thick rectangles
						draw.RoundedBox(0, boxX, boxY - 6, rectWidth, 10, barColor)
						draw.RoundedBox(0, boxX, boxY + h + 22, rectWidth, 10, barColor)

						-- ...and the right ones
						draw.RoundedBox(0, boxX + wide - rectWidth, boxY - 6, rectWidth, 10, barColor)
						draw.RoundedBox(0, boxX + wide - rectWidth, boxY + h + 22, rectWidth, 10, barColor)

						-- And the middle thingies
						draw.RoundedBox(0, -(wide / 1.75) * 0.5, boxY, wide / 1.75, 4, barColor)
						draw.RoundedBox(0, -(wide / 1.75) * 0.5, boxY + h + 22, wide / 1.75, 4, barColor)
					end
				end

				if (style != 3) then
					draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, ColorAlpha(textColor, math.Clamp(fadeAlpha, 0, 100)):Darken(30))
				end
			cam.End3D2D()
		end

		if (style >= 3) then
			cam.Start3D2D(pos + (normal * 0.95 * (scale + 0.5)), angle, 0.1 * scale)
				draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, Color(0, 0, 0, math.Clamp(fadeAlpha, 0, 240)))
			cam.End3D2D()
		end

		cam.Start3D2D(pos + (normal * 1.25 * (scale + 0.5)), angle, 0.1 * scale)
			draw.SimpleText(text, theme.GetFont("Text_3D2D"), posX, posY, ColorAlpha(textColor, fadeAlpha))
		cam.End3D2D()
	end
end