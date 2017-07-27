--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local CATEGORY = config.CreateCategory("chatbox", "Chatbox Settings", "Customize how the chat box works for your server!")
CATEGORY:AddSlider("chatbox_message_margin", "Chat Message Margin", "How much vertical space to put between two messages?", {min = 0, max = 64, default = 4})
CATEGORY:AddSlider("chatbox_max_messages", "Max Chat Messages", "How much messages should the chat history hold?", {min = 1, max = 256, default = 100})

function chatbox.Compile(messageData)
	
end