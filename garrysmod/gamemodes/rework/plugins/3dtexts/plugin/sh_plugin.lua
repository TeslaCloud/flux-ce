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

	function rw3DText:AddText(data)
		if (!data or !data.text or !data.pos or !data.angle or !data.style or !data.scale) then return end

		self.count = (self.count or 0) + 1
		
		self.stored[self.count] = data

		self:Save()

		netstream.Start(nil, "rw3DText_Add", self.count, data)
	end

	function rw3DText:Remove(player)
		if (player:HasPermission("textremove")) then
			netstream.Start(player, "rw3DText_Calculate", true)
		end
	end

	netstream.Hook("rw3DText_Remove", function(player, idx)
		if (player:HasPermission("textremove")) then
			rw3DText.stored[idx] = nil
			rw3DText:Save()

			netstream.Start(nil, "rw3DText_Remove", idx)

			rw.player:Notify(player, "You have removed a 3D text.")
		end
	end)
else
	netstream.Hook("rwLoad3DTexts", function(data)
		rw3DText.stored = data or {}
	end)

	netstream.Hook("rw3DText_Add", function(idx, data)
		rw3DText.stored[idx] = data
	end)

	netstream.Hook("rw3DText_Remove", function(idx)
		rw3DText.stored[idx] = nil
	end)

	netstream.Hook("rw3DText_Calculate", function()
		rw3DText:RemoveAtTrace(rw.client:GetEyeTraceNoCursor())
	end)

	function rw3DText:RemoveAtTrace(trace)
		if (!trace) then return false end
		
		local hitPos = trace.HitPos
		local traceStart = trace.StartPos

		for k, v in pairs(self.stored) do
			local pos = v.pos
			local normal = v.normal
			local ang = normal:Angle()
			local w, h = util.GetTextSize(v.text, theme.GetFont("Text_3D2D"))

			local startPos = pos - -ang:Right() * (w / 20) * v.scale
			local endPos = pos + -ang:Right() * (w / 20) * v.scale

			if (math.abs(math.abs(hitPos.z) - math.abs(pos.z)) < 4 * v.scale) then

				if (util.VectorsIntersect(traceStart, hitPos, startPos, endPos)) then
					netstream.Start("rw3DText_Remove", k)

					return true
				end
			end
		end

		return false
	end
end