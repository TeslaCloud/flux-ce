--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

DeriveGamemode("sandbox")

do
	local defaultColorModify = {
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = 0,
		["$pp_colour_contrast"] = 1,
		["$pp_colour_colour"] = 1,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	}

	function fl.SetColorModifyEnabled(bEnable)
		if (!fl.client.colorModifyTable) then
			fl.client.colorModifyTable = defaultColorModify
		end

		if (bEnable) then
			fl.client.colorModify = true

			return true
		end

		fl.client.colorModify = false
	end

	function fl.EnableColorModify()
		return fl.SetColorModifyEnabled(true)
	end

	function fl.DisableColorModify()
		return fl.SetColorModifyEnabled(false)
	end

	function fl.SetColorModifyVal(index, value)
		if (!fl.client.colorModifyTable) then
			fl.client.colorModifyTable = defaultColorModify
		end

		if (isstring(index)) then
			if (!index:StartWith("$pp_colour_")) then
				if (index == "color") then index = "colour" end

				fl.client.colorModifyTable["$pp_colour_"..index] = (isnumber(value) and value) or 0
			else
				fl.client.colorModifyTable[index] = (isnumber(value) and value) or 0
			end
		end
	end

	function fl.SetColorModifyTable(tab)
		if (istable(tab)) then
			fl.client.colorModifyTable = tab
		end
	end
end

function surface.DrawScaledText(text, font, x, y, scale, color)
	local matrix = Matrix()
	local pos = Vector(x, y)

	matrix:Translate(pos)
	matrix:Scale(Vector(1, 1, 1) * scale)
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		surface.SetFont(font)
		surface.SetTextColor(color)
		surface.SetTextPos(x, y)
		surface.DrawText(text)
	cam.PopModelMatrix()
end

function surface.DrawRotatedText(text, font, x, y, angle, color)
	local matrix = Matrix()
	local pos = Vector(x, y)

	matrix:Translate(pos)
	matrix:Rotate(Angle(0, angle, 0))
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		surface.SetFont(font)
		surface.SetTextColor(color)
		surface.SetTextPos(x, y)
		surface.DrawText(text)
	cam.PopModelMatrix()
end

function surface.DrawScaled(x, y, scale, callback)
	local matrix = Matrix()
	local pos = Vector(x, y)

	matrix:Translate(pos)
	matrix:Scale(Vector(1, 1, 0) * scale)
	matrix:Rotate(Angle(0, 0, 0))
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		if (callback) then
			Try("DrawScaled", callback, x, y, scale)
		end
	cam.PopModelMatrix()
end

function surface.DrawRotated(x, y, angle, callback)
	local matrix = Matrix()
	local pos = Vector(x, y)

	matrix:Translate(pos)
	matrix:Rotate(Angle(0, angle, 0))
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		if (callback) then
			Try("DrawRotated", callback, x, y, angle)
		end
	cam.PopModelMatrix()
end

do
	local cache = surface.CircleInfoCache or {}
	surface.CircleInfoCache = cache

	local blurTexture = Material("pp/blurscreen")

	function surface.DrawCircle(x, y, radius, passes)
		if (!x or !y or !radius) then
			error("surface.DrawCircle - Too few arguments to function call (3 expected)")
		end

		-- In case no passes variable was passed, in which case we give a normal smooth circle.
		passes = passes or 360

		local id = x.."|"..y.."|"..radius.."|"..passes
		local info = cache[id]

		if (!info) then
		    info = {}

		 	-- Since tables start at index 1.
		    for i = 1, passes + 1 do
		    	local degInRad = i * math.pi / (passes / 2)

		        info[i] = {
		            x = x + math.cos(degInRad) * radius,
		            y = y + math.sin(degInRad) * radius
		        }
		    end

			cache[id] = info
		end

		draw.NoTexture() -- Otherwise we draw a transparent circle.
		surface.DrawPoly(info)
	end

	function surface.DrawOutlinedCircle(x, y, radius, thickness, passes, bStencil)
		render.ClearStencil()
		render.SetStencilEnable(true)
			render.SetStencilWriteMask(255)
			render.SetStencilTestMask(255)
			render.SetStencilReferenceValue(28)
			render.SetStencilFailOperation(STENCIL_REPLACE)

			render.SetStencilCompareFunction(STENCIL_EQUAL)
				surface.DrawCircle(x, y, radius - (thickness or 1), passes)
			render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
				surface.DrawCircle(x, y, radius, passes)
		render.SetStencilEnable(false)
		render.ClearStencil()
	end

	-- Requires to be executed within a panel.
	function draw.SimpleBlurBox(x, y, w, h, color, blurAmt)
		blurAmt = blurAmt or 4

		draw.RoundedBox(0, 0, 0, w, h, color)

		surface.SetMaterial(blurTexture)
		surface.SetDrawColor(255, 255, 255, 255)

		for i = -0.2, 1, 0.2 do
			blurTexture:SetFloat("$blur", i * blurAmt)
			blurTexture:Recompute()

			render.UpdateScreenEffectTexture()

			render.SetScissorRect(x, y, x + w, y + h, true)
				surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
			render.SetScissorRect(0, 0, 0, 0, false)
		end
	end

	-- More advanced way to do blur boxes.
	function draw.BlurBox(px, py, x, y, w, h, color, blurAmt)
		blurAmt = 4

		draw.RoundedBox(0, x, y, w, h, color)

		surface.SetMaterial(blurTexture)
		surface.SetDrawColor(255, 255, 255, 255)

		for i = -0.2, 1, 0.2 do
			blurTexture:SetFloat("$blur", i * blurAmt)
			blurTexture:Recompute()

			render.UpdateScreenEffectTexture()

			render.SetScissorRect(px, py, w, h, true)
				surface.DrawTexturedRect(-px, -py, ScrW(), ScrH())
			render.SetScissorRect(0, 0, 0, 0, false)
		end
	end
end