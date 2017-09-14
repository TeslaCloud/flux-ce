--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
	

--]]

config.Set("talk_radius", 400)
config.Set("ic_color", "gold")

function PLUGIN:ChatboxAdjustPlayerSay(messageData)

end

function PLUGIN:PlayerCanHear(player, messageData)
	if (messageData.hearWhenLook) then
		local lookPos = player:GetEyeTraceNoCursor().HitPos

		return messageData.sender:GetPos():Distance(lookPos) <= messageData.radius
	end
end