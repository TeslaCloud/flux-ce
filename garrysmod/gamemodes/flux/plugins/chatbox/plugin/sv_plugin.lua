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
	data = {},
	position = nil,
	radius = 0,
	filter = nil,
	shouldTranslate = false,
	rich = false,
	size = 16,
	text = nil,
	teamChat = false
}

local filters = {}
local clientMode = false

function chatbox.AddFilter(id, data)
	filters[id] = data
end

function chatbox.CanHear(listener, messageData)
	if (listener:HasInitialized()) then
		local position, radius = messageData.position, messageData.radius

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
	return plugin.Call("PlayerCanHear", listener, messageData) or chatbox.CanHear(listener, messageData)
end

function chatbox.AddText(listeners, ...)
	local messageData = {
		sender = nil,
		listeners = listeners or {},
		data = {},
		position = nil,
		radius = 0,
		filter = nil,
		shouldTranslate = false,
		rich = false,
		size = 16,
		text = nil,
		teamChat = false
	}

	if (!istable(listeners)) then
		if (IsValid(listeners)) then
			listeners = {listeners}
		else
			listeners = _player.GetAll()
		end
	end

	-- Compile the initial message data table.
	for k, v in ipairs({...}) do
		if (isstring(v)) then
			table.insert(messageData.data, v)

			if (k == 1) then
				messageData.text = v
			end
		elseif (isnumber(v)) then
			table.insert(messageData.data, v)
		elseif (istable(v)) then
			if (!v.isData and !clientMode) then
				table.Merge(messageData, v)
			else
				table.insert(messageData.data, v)
			end
		elseif (IsColor(v)) then
			table.insert(messageData.data, color)
		end
	end

	if (IsValid(messageData.sender)) then
		if (hook.Run("PlayerSay", messageData.sender, messageData.text or "")) then
			
		end
	end

	for k, v in ipairs(listeners) do
		if (chatbox.PlayerCanHear(v, messageData)) then
			netstream.Start(v, "Chatbox::AddMessage", messageData)
		end
	end
end

function chatbox.SetClientMode(bClientMode)
	clientMode = bClientMode
end

netstream.Hook("Chatbox::AddText", function(player, ...)
	chatbox.SetClientMode(true)
	chatbox.AddText(player, ...)
	chatbox.SetClientMode(false)
end)

netstream.Hook("Chatbox::PlayerSay", function(player, text, bTeamChat)
	chatbox.AddText(nil, text, {sender = player, teamChat = bTeamChat})
end)