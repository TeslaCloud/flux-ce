--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

config.Set("chatbox_message_margin", 4)
config.Set("chatbox_message_fade_delay", 12)
config.Set("chatbox_max_messages", 100)

local defaultMessageData = {
	sender = nil,
	listeners = {},
	text = nil,
	position = nil,
	radius = 0,
	filter = nil,
	shouldTranslate = false,
	rich = false,
	size = 16
}

local filters = {}

function chatbox.AddFilter(id, data)
	filters[id] = data
end

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
	return plugin.Call("PlayerCanHear", listener, messageData) or chatbox.CanHear(listener, messageData.position, messageData.radius or 0)
end

function chatbox.AddText(listeners, ...)
	local messageData = {
		sender = nil,
		listeners = listeners or {},
		text = nil,
		position = nil,
		radius = nil,
		filter = nil
	}
end

netstream.Hook("Chatbox::AddText", function(player, ...)
	chatbox.SetClientMode(true)
	chatbox.AddText(player, ...)
	chatbox.SetClientMode(false)
end)

netstream.Hook("Chatbox::PlayerSay", function(player, text)
	chatbox.AddText()
end)