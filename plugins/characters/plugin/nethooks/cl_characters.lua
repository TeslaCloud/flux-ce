--- Client-side network handlers of the Characters plugin: storing the list of the local
-- player's characters, the character they play for somebody else and its generic data,
-- showing refused requests, opening the main menu and asking for a new physical description.

Cable.receive('fl_characters_load', function(data)
  local function store_characters()
    if !IsValid(PLAYER) then return false end

    PLAYER.characters = data

    timer.Remove('fl_characters_defer')

    --- Called on the client when the list of the local player's characters has arrived
    -- from the server and has been stored in PLAYER.characters. The server sends it when
    -- the player joins and again whenever one of their characters is created, deleted or
    -- changed. The list is stored as soon as it arrives, so the messages that the server
    -- sends after it are handled with the new list in place; only while the local player
    -- does not exist yet is it held back.
    -- @param characters [List<Map> networked data of every character of the local player]
    hook.Run('CharactersReceived', data)

    return true
  end

  if !store_characters() then
    timer.Create('fl_characters_defer', 0.1, 0, store_characters)
  end
end)

Cable.receive('fl_character_borrowed', function(data)
  if IsValid(PLAYER) then
    PLAYER.borrowed_character = istable(data) and data or nil
  end
end)

Cable.receive('fl_character_data', function(character_id, key, value)
  local character = IsValid(PLAYER) and PLAYER:get_character_by_id(character_id)

  if character then
    character.custom_data = character.custom_data or {}
    character.custom_data[key] = value
  end
end)

Cable.receive('fl_character_request_failed', function(action, reason, arguments)
  local text = t(reason, arguments)

  if IsValid(Flux.intro_panel) and isfunction(Flux.intro_panel.notify) then
    Flux.intro_panel:notify(text)
  elseif IsValid(PLAYER) then
    PLAYER:notify(text)
  end

  --- Called on the client when the server has refused a request of the local player to
  -- load or delete one of their characters, after the reason has been shown to them. The
  -- character loading screen uses it to bring back the card of a character that was not
  -- deleted.
  -- @param action [String 'select' or 'delete']
  -- @param text [String the translated reason]
  hook.Run('CharacterRequestFailed', action, text)
end)

Cable.receive('fl_character_menu', function(message, arguments)
  local menu = Flux.intro_panel

  if !IsValid(menu) then
    menu = Theme.create_panel('main_menu')

    Flux.intro_panel = menu
  elseif isfunction(menu.RecreateSidebar) and !IsValid(menu.menu) then
    menu:RecreateSidebar(true)
  end

  if message and IsValid(menu) and isfunction(menu.notify) then
    menu:notify(t(message, arguments))
  end
end)

Cable.receive('fl_character_desc_prompt', function()
  local confirm_text = t'ui.char_desc.confirm'

  Derma_StringRequest(
    t'ui.char_desc.title',
    t('ui.char_desc.message', {
      min = Config.get('characters_min_desc_len'),
      max = Config.get('characters_max_desc_len')
    }),
    PLAYER:get_phys_desc(),
    function(text)
      Cable.send('fl_character_physdesc', text)
    end,
    nil,
    confirm_text
  )
end)
