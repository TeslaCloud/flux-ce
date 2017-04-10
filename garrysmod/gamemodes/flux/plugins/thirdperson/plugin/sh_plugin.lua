--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

if (SERVER) then
	concommand.Add("flThirdPerson", function(player)
		local oldValue = player:GetNetVar("flThirdPerson")

		if (oldValue == nil) then
			oldValue = false
		end

		player:SetNetVar("flThirdPerson", !oldValue)
	end)
else
	local startTime = PLUGIN.startTime or nil
	PLUGIN.startTime = startTime

	local offset = PLUGIN.offset or Vector(0, 0, 0)
	PLUGIN.offset = offset

	local duration = 0.15

	local flippedStart = PLUGIN.flippedStart or false
	PLUGIN.flippedStart = flippedStart

	-- This is very basic and WIP, but it works.
	function PLUGIN:CalcView(player, pos, angles, fov)
		local view = {}
		local curTime = CurTime()

		view.origin = pos
		view.angles = angles
		view.fov = fov

		if (player:GetNetVar("flThirdPerson")) then
			if (!startTime or flippedStart) then
				startTime = curTime
				flippedStart = false
			end

			local forward = angles:Forward() * 75
			local fraction = (curTime - startTime) / duration

			if (fraction <= 1) then
				offset.x = Lerp(fraction, 0, forward.x)
				offset.y = Lerp(fraction, 0, forward.y)
				offset.z = Lerp(fraction, 0, forward.z)
			else
				offset = forward
			end

			view.origin = pos - offset
			view.drawviewer = true
		else
			if (!flippedStart) then
				startTime = curTime
				flippedStart = true
			end

			local forward = angles:Forward() * 75
			local fraction = (curTime - startTime) / duration

			if (fraction <= 1) then
				offset.x = Lerp(fraction, forward.x, 0)
				offset.y = Lerp(fraction, forward.y, 0)
				offset.z = Lerp(fraction, forward.z, 0)
				view.drawviewer = true
			else
				offset = Vector(0, 0, 0)
			end

			view.origin = pos - offset
		end

		return view
	end

	fl.binds:AddBind("ToggleThirdPerson", "flThirdPerson", KEY_X)
end