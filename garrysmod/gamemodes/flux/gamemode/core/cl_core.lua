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

	function fl.core:SetColorModifyEnabled(bEnable)
		if (!fl.client.colorModifyTable) then
			fl.client.colorModifyTable = defaultColorModify
		end

		if (bEnable) then
			fl.client.colorModify = true

			return true
		end

		fl.client.colorModify = false
	end

	function fl.core:EnableColorModify()
		return self:SetColorModifyEnabled(true)
	end

	function fl.core:DisableColorModify()
		return self:SetColorModifyEnabled(false)
	end

	function fl.core:SetColorModifyVal(index, value)
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

	function fl.core:SetColorModifyTable(tab)
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
			render.SetStencilReferenceValue(1)
			render.SetStencilFailOperation(STENCIL_REPLACE)

			render.SetStencilCompareFunction(STENCIL_EQUAL)
				surface.DrawCircle(x, y, radius - (thickness or 1), passes)
			render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
				surface.DrawCircle(x, y, radius, passes)
		render.SetStencilEnable(false)
		render.ClearStencil()
	end
end