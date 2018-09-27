function flChatbox:OnThemeLoaded(current_theme)
  local scr_w, scr_h = ScrW(), ScrH()

  font.Create('flChatFont', {
    font = 'Arial',
    size = 16,
    weight = 1000
  })

  current_theme:set_font('Chatbox_Normal', 'flChatFont', font.Scale(20))
  current_theme:set_font('Chatbox_Bold', 'flRobotoCondensedBold', font.Scale(20))
  current_theme:set_font('Chatbox_Italic', 'flRobotoCondensedItalic', font.Scale(20))
  current_theme:set_font('Chatbox_ItalicBold', 'flRobotoCondensedItalicBold', font.Scale(20))
  current_theme:set_font('Chatbox_Syntax', 'flRobotoCondensed', font.Scale(24))

  current_theme:set_option('Chatbox_Width', scr_w / 2.25)
  current_theme:set_option('Chatbox_Height', scr_h / 2.25)
  current_theme:set_option('Chatbox_X', font.Scale(8))
  current_theme:set_option('Chatbox_Y', scr_h - current_theme:get_option('Chatbox_Height') - font.Scale(32))
end

function flChatbox:OnResolutionChanged(newW, newH)
  theme.set_option('Chatbox_Width', newW / 2.25)
  theme.set_option('Chatbox_Height', newH / 2.25)
  theme.set_option('Chatbox_X', font.Scale(8))
  theme.set_option('Chatbox_Y', newH - theme.get_option('Chatbox_Height') - font.Scale(32))

  if chatbox.panel then
    chatbox.panel:Remove()
    chatbox.panel = nil
  end
end

function flChatbox:PlayerBindPress(player, bind, bPress)
  if fl.client:HasInitialized() and (string.find(bind, 'messagemode') or string.find(bind, 'messagemode2')) and bPress then
    if string.find(bind, 'messagemode2') then
      fl.client.typing_team_chat = true
    else
      fl.client.typing_team_chat = false
    end

    chatbox.Show()

    return true
  end
end

function flChatbox:GUIMousePressed(mouseCode, aimVector)
  if IsValid(chatbox.panel) then
    chatbox.Hide()
  end
end

function flChatbox:HUDShouldDraw(element)
  if element == 'CHudChat' then
    return false
  end
end

function flChatbox:ChatboxTextEntered(text)
  if text and text != '' then
    netstream.Start('Chatbox::PlayerSay', text)
  end

  chatbox.Hide()
end

function flChatbox:ChatboxPaintOver(w, h, panel)
  
end

netstream.Hook('Chatbox::AddMessage', function(messageData)
  if IsValid(chatbox.panel) then
    chatbox.panel:AddMessage(messageData)
  end
end)
