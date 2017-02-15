--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

PLUGIN:SetAlias("rw3DText")

rw3DText.stored = rw3DText.stored or {}

util.Include("cl_hooks.lua")

if (SERVER) then
	function rw3DText:Save()
		data.SavePluginData("3dtexts", rw3DText.stored)
	end

	function rw3DText:Load()
		local loaded = data.LoadPluginData("3dtexts", {})

		self.stored = loaded
	end

	function rw3DText:PlayerInitialized(player)
		netstream.Start(player, "rwLoad3DTexts", self.stored)
	end

	function rw3DText:InitPostEntity()
		self:Load()
	end

	function rw3DText:SaveData()
		self:Save()
	end

	netstream.Hook("rw3DText_Remove", function(player, idx)
		rw3DText.stored[idx] = nil
	end)
else
	netstream.Hook("rwLoad3DTexts", function(data)
		rw3DText.stored = data or {}
	end)
end

function rw3DText:AddText(data)
	if (!data or !data.text or !data.pos or !data.angle) then return end

	self.count = (self.count or 0) + 1
	
	self.stored[self.count] = data
end

function rw3DText:RemoveAtTrace(trace)
	if (!trace or SERVER) then return end
	
	local hitPos = trace.HitPos
	local traceStart = trace.StartPos

	for k, v in pairs(self.stored) do
		local pos = v.pos
		local normal = v.normal
		local angle = v.angle
		local w, h = util.GetTextSize(v.text, theme.GetFont("Text_3D2D"))
		local textV = Vector(normal.x, normal.y, normal.z)
		textV:Rotate(angle)

		local startPos = pos + textV * (w / 20)
		local endPos = pos + textV * (-w / 20)

		if (math.abs(math.abs(hitPos.z) - math.abs(pos.z)) < 3) then
			if (util.VectorsIntersect(traceStart, hitPos, startPos, endPos)) then
				netstream.Start("rw3DText_Remove", k)
				self.stored[k] = nil

				break
			end
		end
	end
end