--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

do
	local cache = nil
	local tempCache = nil
	local renderColor = Color(50, 255, 50)
	local renderColorRed = Color(255, 50, 50)
	local lastAmt = nil
	local render = render

	function flAreas:PostDrawOpaqueRenderables(bDrawDepth, bDrawSkybox)
		if (bDrawDepth or bDrawSkybox) then return end

		local weapon = fl.client:GetActiveWeapon()

		if (IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "area") then
			local tool = fl.client:GetTool()
			local verts = (tool and tool.area and tool.area.verts)
			local areasCount = areas.GetCount()

			if (istable(verts) and (!tempCache or #tempCache != #verts)) then
				tempCache = {}

				for k, v in ipairs(verts) do
					local n

					if (k == #verts) then
						n = verts[1]
					else
						n = verts[k + 1]
					end

					table.insert(tempCache, {v, n})
				end
			end

			if (!lastAmt) then lastAmt = areasCount end

			if (!cache or lastAmt != areasCount) then
				cache = {}

				for k, v in pairs(areas.GetAll()) do
					for k2, v2 in ipairs(v.polys) do
						for idx, p in ipairs(v2) do
							local n

							if (idx == #v2) then
								n = v2[1]
							else
								n = v2[idx + 1]
							end

							local add = Vector(0, 0, v.maxH)

							table.insert(cache, {p, n, p + add, n + add})
						end
					end
				end
			end

			if (cache) then
				for k, v in ipairs(cache) do
					local p, ap = v[1], v[3]

					render.DrawLine(p, v[2], renderColor)
					render.DrawLine(ap, v[4], renderColor)
					render.DrawLine(ap, p, renderColor)
				end
			end

			if (tempCache) then
				for k, v in ipairs(tempCache) do
					render.DrawLine(v[1], v[2], renderColorRed)
				end
			end
		end
	end
end

netstream.Hook("PlayerEnteredArea", function(areaIdx, idx, pos, curTime)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), fl.client, area, area.polys[idx], true, pos, curTime)
end)

netstream.Hook("PlayerLeftArea", function(areaIdx, idx, pos, curTime)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), fl.client, area, area.polys[idx], false, pos, curTime)
end)