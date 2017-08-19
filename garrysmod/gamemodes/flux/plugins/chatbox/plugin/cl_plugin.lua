--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local CATEGORY = config.CreateCategory("chatbox", "Chatbox Settings", "Customize how the chat box works for your server!")
CATEGORY:AddSlider("chatbox_message_margin", "Chat Message Margin", "How much vertical space to put between two messages?", {min = 0, max = 64, default = 4})
CATEGORY:AddSlider("chatbox_message_fade_delay", "Chat Message Fade Delay", "How long do the messages stay on the screen before fading away?", {min = 1, max = 128, default = 12})
CATEGORY:AddSlider("chatbox_max_messages", "Max Chat Messages", "How much messages should the chat history hold?", {min = 1, max = 256, default = 100})

chatbox.oldAddText = chatbox.oldAddText or chat.AddText

function chat.AddText(...)
	netstream.Start("Chatbox::AddText", ...)
end

function chatbox.Compile(messageTable)
	local text = messageTable.text

	if (!isstring(text)) then return end

	local compiled = {}
	
	if (messageData.shouldTranslate) then
		text = fl.lang:TranslateText(text)

		messageTable.text = text
	end

	local font = font.GetSize(theme.GetFont("Chatbox_Normal"), messageData.size or 16)
	local wrapped = util.WrapText(text, font, 100)

	for k, v in ipairs(wrapped) do
		local w, h = util.GetTextSize(v, font)

		table.insert(compiled, {
			width = w,
			height = h,
			data = {}
		})
	end

	return compiled
end

function chatbox.Show()
	if (!IsValid(chatbox.panel)) then
		chatbox.panel = vgui.Create("flChatPanel")
	end

	chatbox.panel:SetOpen(true)
end

function chatbox.Hide()
	if (IsValid(chatbox.panel)) then
		chatbox.panel:SetOpen(false)
	end
end