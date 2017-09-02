--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flChatbox:OnThemeLoaded(activeTheme)
	activeTheme:SetFont("Chatbox_Normal", "flRoboto", font.Scale(18))
	activeTheme:SetFont("Chatbox_Bold", "flRobotoBold", font.Scale(18))
	activeTheme:SetFont("Chatbox_Italic", "flRobotoItalic", font.Scale(18))
	activeTheme:SetFont("Chatbox_ItalicBold", "flRobotoItalicBold", font.Scale(18))
	activeTheme:SetFont("Chatbox_Syntax", "flRobotoCondensed", font.Scale(22))
end

function flChatbox:OnResolutionChanged(newW, newH)
	chatbox.width = newW * 0.3
	chatbox.height = newH * 0.3
	chatbox.x = 4
	chatbox.y = newH - chatbox.height - 36

	--chatbox.UpdateDisplay()

	if (chatbox.panel) then
		chatbox.panel:Remove()
		chatbox.panel = nil
	end
end

function flChatbox:PlayerBindPress(player, bind, bPress)
	if (fl.client:HasInitialized() and (string.find(bind, "messagemode") or string.find(bind, "messagemode2")) and bPress) then
		if (string.find(bind, "messagemode2")) then
			fl.client.isTypingTeamChat = true
		else
			fl.client.isTypingTeamChat = false
		end

		chatbox.Show()

		return true
	end
end

function flChatbox:GUIMousePressed(mouseCode, aimVector)
	if (IsValid(chatbox.panel)) then
		chatbox.Hide()
	end
end