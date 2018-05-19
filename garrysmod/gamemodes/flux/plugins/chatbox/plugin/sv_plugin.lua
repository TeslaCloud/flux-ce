--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

config.Set("chatbox_message_margin", 2)
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
	size = 20,
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
	return plugin.call("PlayerCanHear", listener, messageData) or chatbox.CanHear(listener, messageData)
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
		size = 20,
		text = nil,
		teamChat = false,
		maxHeight = 20
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

			if (messageData.maxHeight < v) then
				messageData.maxHeight = v
			end
		elseif (IsColor(v)) then
			table.insert(messageData.data, v)
		elseif (istable(v)) then
			if (!v.isData and !clientMode) then
				table.Merge(messageData, v)
			else
				table.insert(messageData.data, v)
			end
		elseif (IsValid(v)) then
			table.insert(messageData.data, v)
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
	if (!IsValid(player)) then return end

	chatbox.SetClientMode(true)
	chatbox.AddText(player, ...)
	chatbox.SetClientMode(false)
end)

netstream.Hook("Chatbox::PlayerSay", function(player, text, bTeamChat)
	if (!IsValid(player)) then return end

	local playerSayOverride = hook.Run("PlayerSay", player, text, bTeamChat)

	if (isstring(playerSayOverride)) then
		if (playerSayOverride == "") then return end

		text = playerSayOverride
	end

	local message = {
		hook.Run("ChatboxGetPlayerIcon", player, text, bTeamChat) or {},
		hook.Run("ChatboxGetPlayerColor", player, text, bTeamChat) or _team.GetColor(player:Team()),
		player,
		hook.Run("ChatboxGetMessageColor", player, text, bTeamChat) or Color(255, 255, 255),
		": ",
		text,
		{sender = player}
	}

	hook.Run("ChatboxAdjustPlayerSay", player, text, message)

	chatbox.AddText(nil, unpack(message))
end)
