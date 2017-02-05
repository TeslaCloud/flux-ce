--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

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

	draw.NoTexture(); -- Otherwise we draw a transparent circle.
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