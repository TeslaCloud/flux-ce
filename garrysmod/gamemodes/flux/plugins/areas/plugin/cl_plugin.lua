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
	local areaColors = {}

	function flAreas:PostDrawOpaqueRenderables(bDrawDepth, bDrawSkybox)
		if (bDrawDepth or bDrawSkybox) then return end

		local weapon = fl.client:GetActiveWeapon()

		if (IsValid(weapon) and weapon:GetClass() == "gmod_tool" and weapon:GetMode() == "area") then
			local tool = fl.client:GetTool()
			local mode = tool:GetAreaMode()
			local verts = (tool and tool.area and tool.area.verts)
			local areasTable = areas.GetByType(mode.areaType)
			local areasCount = #areasTable

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
			elseif (!verts) then
				tempCache = nil
			end

			if (!lastAmt) then lastAmt = areasCount end

			if (!cache or lastAmt != areasCount) then
				cache = {}

				areaColors[mode.areaType] = areas.GetColor(mode.areaType)

				for k, v in pairs(areasTable) do
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

			local areaRenderColor = areaColors[mode.areaType]

			if (cache) then
				for k, v in ipairs(cache) do
					local p, ap = v[1], v[3]

					render.DrawLine(p, v[2], areaRenderColor)
					render.DrawLine(ap, v[4], areaRenderColor)
					render.DrawLine(ap, p, areaRenderColor)
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

function flAreas:HUDPaint()
	if (istable(fl.client.textAreas)) then
		local lastY = 400
		local curTime = CurTime()

		for k, v in pairs(fl.client.textAreas) do
			if (istable(v) and v.endTime > curTime) then
				v.alpha = v.alpha or 255

				draw.SimpleText(v.text, theme.GetFont("Text_Large"), 32, lastY, Color(255, 255, 255, v.alpha))

				if (curTime + 2 >= v.endTime) then
					v.alpha = math.Clamp(v.alpha - 1, 0, 255)
				end

				lastY = lastY + 50
			end
		end
	end
end

netstream.Hook("PlayerEnteredArea", function(areaIdx, idx, pos)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), fl.client, area, true, pos, CurTime())
end)

netstream.Hook("PlayerLeftArea", function(areaIdx, idx, pos)
	local area = areas.GetAll()[areaIdx]

	Try("Areas", areas.GetCallback(area.type), fl.client, area, false, pos, CurTime())
end)

netstream.Hook("flLoadAreas", function(areaStorage)
	areas.SetStored(areaStorage)
end)

netstream.Hook("flAreaRemove", function(uniqueID)
	areas.Remove(uniqueID)
end)

netstream.Hook("flAreaRegister", function(id, data)
	areas.Register(id, data)
end)