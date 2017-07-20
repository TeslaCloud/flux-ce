--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flChatbox:CreateFonts()
	font.Create("flChatFont", {
		font		= "Roboto",
		size		= 17
	})

	font.Create("flChatFontBold", {
		font		= "Roboto",
		size		= 17,
		weight		= 1000
	})

	font.Create("flChatSyntax", {
		font		= "Roboto",
		size		= 20
	})
end

function flChatbox:OnResolutionChanged(newW, newH)
	chatbox.width = newW * 0.3
	chatbox.height = newH * 0.3
	chatbox.x = 4
	chatbox.y = newH - chatbox.height - 36

	chatbox.UpdateDisplay()

	if (chatbox.panel) then
		chatbox.panel:Remove()
		chatbox.panel = nil
	end
end

function flChatbox:PlayerBindPress(player, bind, bPress)
	if ((string.find(bind, "messagemode") or string.find(bind, "messagemode2")) and bPress) then
		if (fl.client:HasInitialized()) then
			chatbox.Show()
		end

		return true
	end
end

function flChatbox:GUIMousePressed(mouseCode, aimVector)
	if (IsValid(chatbox.panel)) then
		chatbox.Hide()
	end
end

netstream.Hook("ChatboxTextEnter", function(player, messageData)
	if (IsValid(player)) then
		chat.PlaySound()

		print("["..messageData.filter:upper().."] "..player:Name()..": "..messageData.text)

		table.insert(chatbox.history, messageData)

		chatbox.UpdateDisplay()
		chatbox.Hide()
	end
end)

netstream.Hook("ChatboxAddText", function(messageData)
	chat.PlaySound()

	print("["..messageData.filter:upper().."] "..messageData.text)

	table.insert(chatbox.history, messageData)

	chatbox.UpdateDisplay()
end)