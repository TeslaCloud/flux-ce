--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local CATEGORY = config.CreateCategory("chatbox", "Chatbox Settings", "Customize how the chat box works for your server!")
CATEGORY:AddSlider("chatbox_message_margin", "Chat Message Margin", "How much vertical space to put between two messages?", {min = 0, max = 64, default = 4})
CATEGORY:AddSlider("chatbox_message_fade_delay", "Chat Message Fade Delay", "How long do the messages stay on the screen before fading away?", {min = 1, max = 128, default = 12})
CATEGORY:AddSlider("chatbox_max_messages", "Max Chat Messages", "How much messages should the chat history hold?", {min = 1, max = 256, default = 100})

function chatbox.Compile(messageTable)
	local compiled = {}
	local skip = 0
	local curX, curY, curSize, curColor = 0, 0, 0, Color(255, 255, 255)

	for k, v in ipairs(messageTable) do
		if (skip > 0) then
			skip = skip - 1

			continue
		end

		local parsed, skipAdd = chatbox.ParseBuffer(v, k, messageTable)

		if (isnumber(skipAdd)) then
			skip = skip + skipAdd
		end

		if (istable(parsed)) then
			table.insert(compiled, unpack(parsed))
		end
	end

	return compiled
end

function chatbox.Show()

end

function chatbox.Hide()

end