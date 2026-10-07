--- Recalculates the size and position options of the chatbox for the new resolution
-- and removes the chatbox panel so that it gets recreated.
-- @param new_width [Number new screen width]
-- @param new_height [Number new screen height]
function Chatbox:OnResolutionChanged(new_width, new_height)
  Theme.set_option('chatbox_width', new_width * 0.375)
  Theme.set_option('chatbox_height', new_height * 0.45)
  Theme.set_option('chatbox_x', math.scale(8))
  Theme.set_option('chatbox_y', new_height - Theme.get_option('chatbox_height') - math.scale(64))
  local entry_height = Theme.set_option('chatbox_text_entry_height', math.scale(38)) or math.scale(38)
  Theme.set_option('chatbox_text_entry_text_size', entry_height * 0.9)

  if Chatbox.panel then
    Chatbox.panel:Remove()
    Chatbox.panel = nil
  end
end

--- Opens the chatbox instead of the default chat when a chat bind is pressed,
-- remembering whether team chat was requested.
-- @param client [Player]
-- @param bind [String the bind that was pressed]
-- @param pressed [Boolean whether the bind was pressed rather than released]
-- @return [Boolean true to block the bind if the chatbox was opened, nil otherwise]
function Chatbox:PlayerBindPress(client, bind, pressed)
  if IsValid(PLAYER) and PLAYER:has_initialized() and (string.find(bind, 'messagemode') or string.find(bind, 'messagemode2')) and pressed then
    if string.find(bind, 'messagemode2') then
      PLAYER.typing_team_chat = true
    else
      PLAYER.typing_team_chat = false
    end

    Chatbox.show()

    return true
  end
end

--- Closes the chatbox when the player clicks on the game world.
-- @param mouseCode [Number mouse button code]
-- @param aim_vector [Vector direction of the click]
function Chatbox:GUIMousePressed(mouseCode, aim_vector)
  if IsValid(Chatbox.panel) then
    Chatbox.hide()
  end
end

--- Hides the default chat HUD element.
-- @param element [String name of the HUD element]
-- @return [Boolean false for 'CHudChat', nil otherwise]
function Chatbox:HUDShouldDraw(element)
  if element == 'CHudChat' then
    return false
  end
end

--- Creates the normal, bold, italic and bold italic fonts of the chatbox.
function Chatbox:CreateFonts()
  Font.create('chat_font', {
    font    = 'Montserrat Medium',
    size    = 16
  })

  Font.create('chat_font_bold', {
    font    = 'Montserrat ExtraBold',
    size    = 16
  })

  Font.create('chat_font_italic', {
    font    = 'Montserrat Medium',
    size    = 16,
    italic = true
  })

  Font.create('chat_font_italic_bold', {
    font    = 'Montserrat ExtraBold',
    size    = 16,
    italic  = true
  })
end

--- Sets the options, fonts and colors of the chatbox on the theme that was loaded.
-- @param current_theme [ThemeBase]
function Chatbox:OnThemeLoaded(current_theme)
  local scrw, scrh = ScrW(), ScrH()

  current_theme:set_option('chatbox_text_small_size', math.scale(Config.get('small_font_size')))
  current_theme:set_option('chatbox_text_normal_size', math.scale(Config.get('default_font_size')))
  current_theme:set_option('chatbox_text_big_size', math.scale(Config.get('big_font_size')))
  current_theme:set_option('chatbox_width', scrw * 0.375)
  current_theme:set_option('chatbox_height', scrh * 0.45)
  current_theme:set_option('chatbox_x', math.scale(8))
  current_theme:set_option('chatbox_y', scrh - current_theme:get_option('chatbox_height') - math.scale(64))
  current_theme:set_option('chatbox_fix_alignment', true)
  current_theme:set_option('chatbox_padding', math.scale(8))

  local entry_height = current_theme:set_option('chatbox_text_entry_height', math.scale(32))
  local text_size = current_theme:set_option('chatbox_text_entry_text_size', entry_height * 0.75)
  local font_size = current_theme:get_option('chatbox_text_normal_size')

  current_theme:set_font('chatbox_normal',      'chat_font',              font_size)
  current_theme:set_font('chatbox_bold',        'chat_font_bold',         font_size)
  current_theme:set_font('chatbox_italic',      'chat_font_italic',       font_size)
  current_theme:set_font('chatbox_italic_bold', 'chat_font_italic_bold',  font_size)
  current_theme:set_font('chatbox_syntax',      'flRobotoCondensed',      math.scale(24))
  current_theme:set_font('chatbox_text_entry',  'chat_font',              text_size)

  current_theme:set_color('chat_text_entry_background', Color(0, 0, 0, 215))
end

--- Sends the entered text to the server, unless it is empty, and closes the chatbox.
-- @param text [String the text that was entered]
function Chatbox:ChatboxTextEntered(text)
  if text and text != '' then
    Cable.send('fl_chat_player_say', text)
  end

  Chatbox.hide()
end

--- Prints the texts and colors of a compiled chat message to the console.
-- @param compiled [Map compiled message, as returned by Chatbox.compile]
function Chatbox:ChatboxMessageCompiled(compiled)
  local to_print = {}

  for k, v in pairs(compiled) do
    if istable(v) and v.text or IsColor(v) then
      table.insert(to_print, IsColor(v) and v or v.text)
    end
  end

  table.insert(to_print, '\n')

  MsgC(unpack(to_print))
end

Cable.receive('fl_chat_message_add', function(message_data)
  if !IsValid(Chatbox.panel) then
    if Theme.initialized() then
      Chatbox.create()
    else
      return
    end
  end

  Chatbox.panel:add_message(message_data)

  chat.PlaySound()
end)
