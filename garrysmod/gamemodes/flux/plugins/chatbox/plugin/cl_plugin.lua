--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local CATEGORY = config.CreateCategory("chatbox", "Chatbox Settings", "Customize how the chat box works for your server!")
CATEGORY:AddSlider("chatbox_message_margin", "Chat Message Margin", "How much vertical space to put between two messages?", {min = 0, max = 64, default = 4})
CATEGORY:AddSlider("chatbox_message_fade_delay", "Chat Message Fade Delay", "How long do the messages stay on the screen before fading away?", {min = 1, max = 128, default = 12})
CATEGORY:AddSlider("chatbox_max_messages", "Max Chat Messages", "How much messages should the chat history hold?", {min = 1, max = 256, default = 100})

chatbox.width = 100
chatbox.height = 100
chatbox.x = 0
chatbox.y = 0

chatbox.oldAddText = chatbox.oldAddText or chat.AddText

function chat.AddText(...)
	netstream.Start("Chatbox::AddText", ...)
end

function chatbox.Compile(messageTable)
	local compiled = {}
	local data = messageTable.data
	local shouldTranslate = messageTable.shouldTranslate
	local curSize = messageTable.size or 16
	local curX, curY = 0, 0
	local totalHeight = 32
	local font = font.GetSize(theme.GetFont("Chatbox_Normal"), curSize)

	for k, v in ipairs(data) do
		if (isstring(v)) then
			if (shouldTranslate) then
				data[k] = fl.lang:TranslateText(v)
			end

			local wrapped = util.WrapText(v, font, chatbox.width, curX)
			local nWrapped = #wrapped

			for k, v in ipairs(wrapped) do
				local w, h = util.GetTextSize(v, font)

				table.insert(compiled, {text = v, w = w, h = h, x = curX, y = curY})

				curX = curX + w

				if (nWrapped > 1) then
					curY = curY + h + config.Get("chatbox_message_margin")

					totalHeight = totalHeight + h + config.Get("chatbox_message_margin")

					curX = 0
				end
			end
		elseif (isnumber(v)) then
			curSize = v

			font = font.GetSize(theme.GetFont("Chatbox_Normal"), curSize)

			table.insert(compiled, v)
		elseif (istable(v)) then
			if (v.image) then
				local imageData = {
					image = v.image,
					x = curX + 1,
					y = curY,
					w = font.Scale(v.width),
					h = font.Scale(v.height)
				}

				curX = curX + imageData.w + 2

				table.insert(compiled, imageData)
			end
		elseif (IsColor(v)) then
			table.insert(compiled, v)
		end
	end

	compiled.totalHeight = totalHeight

	return compiled
end

function chatbox.Show()
	if (!IsValid(chatbox.panel)) then
		chatbox.width = theme.GetOption("Chatbox_Width") or 100
		chatbox.height = theme.GetOption("Chatbox_Height") or 100
		chatbox.x = theme.GetOption("Chatbox_X") or 0
		chatbox.y = theme.GetOption("Chatbox_Y") or 0

		chatbox.panel = vgui.Create("flChatPanel")
	end

	chatbox.panel:SetOpen(true)
end

function chatbox.Hide()
	if (IsValid(chatbox.panel)) then
		chatbox.panel:SetOpen(false)

		chatbox.panel:SetMouseInputEnabled(false)
		chatbox.panel:SetKeyboardInputEnabled(false)
	end
end

concommand.Add("fl_reset_chat", function()
	if (IsValid(chatbox.panel)) then
		chatbox.panel:SafeRemove()
	end
end)