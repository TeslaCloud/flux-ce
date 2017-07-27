--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

config.Set("chatbox_message_margin", 4)
config.Set("chatbox_max_messages", 100)

function chatbox.CanHear(listener, position, radius)
	if (listener:HasInitialized()) then
		if (!isnumber(radius)) then return false end
		if (radius == 0) then return true end
		if (radius < 0) then return false end

		if (position:Distance(listener:GetPos()) <= radius) then
			return true
		end
	end

	return false
end

function chatbox.PlayerCanHear(listener, messageData)
	if (!IsValid(listener)) then
		return messageData.filter != "ic"
	end
end

function chatbox.AddText(listeners, ...)

end