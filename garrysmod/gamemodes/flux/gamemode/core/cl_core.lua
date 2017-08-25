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

	function fl.SetColorModifyVal(strIndex, nValue)
		if (!fl.client.colorModifyTable) then
			fl.client.colorModifyTable = defaultColorModify
		end

		if (isstring(strIndex)) then
			if (!strIndex:StartWith("$pp_colour_")) then
				if (strIndex == "color") then strIndex = "colour" end

				fl.client.colorModifyTable["$pp_colour_"..strIndex] = (isnumber(nValue) and nValue) or 0
			else
				fl.client.colorModifyTable[strIndex] = (isnumber(nValue) and nValue) or 0
			end
		end
	end

	function fl.SetColorModifyTable(tTable)
		if (istable(tTable)) then
			fl.client.colorModifyTable = tTable
		end
	end
end

function surface.DrawScaledText(strText, strFontName, nPosX, nPosY, nScale, color)
	local matrix = Matrix()
	local pos = Vector(nPosX, nPosY)

	matrix:Translate(pos)
	matrix:Scale(Vector(1, 1, 1) * nScale)
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		surface.SetFont(strFontName)
		surface.SetTextColor(color)
		surface.SetTextPos(nPosX, nPosY)
		surface.DrawText(strText)
	cam.PopModelMatrix()
end

function surface.DrawRotatedText(strText, strFontName, nPosX, nPosY, angle, color)
	local matrix = Matrix()
	local pos = Vector(nPosX, nPosY)

	matrix:Translate(pos)
	matrix:Rotate(Angle(0, angle, 0))
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		surface.SetFont(strFontName)
		surface.SetTextColor(color)
		surface.SetTextPos(nPosX, nPosY)
		surface.DrawText(strText)
	cam.PopModelMatrix()
end

function surface.DrawScaled(nPosX, nPosY, nScale, callback)
	local matrix = Matrix()
	local pos = Vector(nPosX, nPosY)

	matrix:Translate(pos)
	matrix:Scale(Vector(1, 1, 0) * nScale)
	matrix:Rotate(Angle(0, 0, 0))
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		if (callback) then
			Try("DrawScaled", callback, nPosX, nPosY, nScale)
		end
	cam.PopModelMatrix()
end

function surface.DrawRotated(nPosX, nPosY, angle, callback)
	local matrix = Matrix()
	local pos = Vector(nPosX, nPosY)

	matrix:Translate(pos)
	matrix:Rotate(Angle(0, angle, 0))
	matrix:Translate(-pos)

	cam.PushModelMatrix(matrix)
		if (callback) then
			Try("DrawRotated", callback, nPosX, nPosY, angle)
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
		passes = passes or 100

		local id = x.."|"..y.."|"..radius.."|"..passes
		local info = cache[id]

		if (!info) then
			info = {}

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

	function surface.DrawPartialCircle(percentage, x, y, radius, passes)
		if (!percentage or !x or !y or !radius) then
			error("surface.DrawPartialCircle - Too few arguments to function call (4 expected)")
		end

		-- In case no passes variable was passed, in which case we give a normal smooth circle.
		passes = passes or 360

		local id = percentage.."|"..x.."|"..y.."|"..radius.."|"..passes
		local info = cache[id]

		if (!info) then
			info = {}

			local breakAt = math.floor(passes * (percentage / 100))

		 	-- Since tables start at index 1.
			for i = 1, passes + 1 do
				if (i == breakAt) then break end

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
end

function draw.TexturedRect(x, y, w, h, material, color)
	if (!material) then return end

	color = (IsColor(color) and color) or Color(255, 255, 255)

	surface.SetDrawColor(color.r, color.g, color.b, color.a)
	surface.SetMaterial(material)
	surface.DrawTexturedRect(x, y, w, h)
end