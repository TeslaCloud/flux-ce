function flChatbox:OnThemeLoaded(current_theme)
  local scrw, scrh = ScrW(), ScrH()

  font.Create('flChatFont', {
    font = 'Arial',
    size = 16,
    weight = 1000
  })

  current_theme:set_font('chatbox_normal', 'flChatFont', font.Scale(20))
  current_theme:set_font('chatbox_bold', 'flRobotoCondensedBold', font.Scale(20))
  current_theme:set_font('chatbox_italic', 'flRobotoCondensedItalic', font.Scale(20))
  current_theme:set_font('chatbox_italic_bold', 'flRobotoCondensedItalicBold', font.Scale(20))
  current_theme:set_font('chatbox_syntax', 'flRobotoCondensed', font.Scale(24))

  current_theme:set_option('chatbox_width', scrw / 2.25)
  current_theme:set_option('chatbox_height', scrh / 2.25)
  current_theme:set_option('chatbox_x', font.Scale(8))
  current_theme:set_option('chatbox_y', scrh - current_theme:get_option('chatbox_height') - font.Scale(32))
end

function flChatbox:OnResolutionChanged(newW, newH)
  theme.set_option('chatbox_width', newW / 2.25)
  theme.set_option('chatbox_height', newH / 2.25)
  theme.set_option('chatbox_x', font.Scale(8))
  theme.set_option('chatbox_y', newH - theme.get_option('chatbox_height') - font.Scale(32))

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

    chatbox.show()

    return true
  end
end

function flChatbox:GUIMousePressed(mouseCode, aimVector)
  if IsValid(chatbox.panel) then
    chatbox.hide()
  end
end

function flChatbox:HUDShouldDraw(element)
  if element == 'CHudChat' then
    return false
  end
end

function flChatbox:ChatboxTextEntered(text)
  if text and text != '' then
    netstream.Start('chat_player_say', text)
  end

  chatbox.hide()
end

netstream.Hook('chat_add_message', function(message_data)
  if IsValid(chatbox.panel) then
    chatbox.panel:add_message(message_data)

    chat.PlaySound()
  end
end)
