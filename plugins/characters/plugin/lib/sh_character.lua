--- Player extensions of the Characters plugin: the characters of a player and the active one.
-- A player owns a list of characters and has at most one active character at a time. The
-- player methods return these characters (`Player:get_all_characters`, `Player:get_character`)
-- and the fields of the active one; on the server they are `Character` records, on the client
-- the networked tables that the server sends to the owner of the characters. Server-side
-- methods select the active character, set its fields and save it.
--
-- This file also holds the `Characters` functions that create, save, delete and edit
-- characters, and the network handlers behind the character menus.
-- @module [Player]

if !Characters then
  PLUGIN:set_global('Characters')
end

CHAR_GENDER_MALE    = 0    -- Guys.
CHAR_GENDER_FEMALE  = 1    -- Gals.
CHAR_GENDER_NONE    = 2    -- Gender-less characters such as vorts.

local translate_gender = {
  [CHAR_GENDER_MALE] = 'male',
  [CHAR_GENDER_FEMALE] = 'female',
  [CHAR_GENDER_NONE] = 'no_gender'
}

--- Creates a character for a player unless a PlayerCreateCharacter hook rejects the data.
-- On the server the character is then saved and sent to its owner.
-- ```
-- local status = Characters.create(target, {
--   name = 'John Doe',
--   phys_desc = 'A tall man in a worn coat.',
--   gender = CHAR_GENDER_MALE,
--   model = 'models/humans/group01/male_02.mdl',
--   skin = 0
-- })
--
-- if status != CHAR_SUCCESS then
--   -- status is one of the CHAR_ERR_* codes
-- end
-- ```
-- @param target [Player owner of the new character]
-- @param data [Map creation data: name, phys_desc, gender, model and optionally skin]
-- @return [Number CHAR_SUCCESS, or the CHAR_ERR_* code returned by the hook]
function Characters.create(target, data)
  --- Validates the data of a character that is about to be created. Called by
  -- `Characters.create`, which the plugin runs on the server, before the character record is
  -- built.
  -- @param owner [Player the player the character is created for]
  -- @param data [Map creation data: name, phys_desc, gender, model, skin and the fields that
  --   other plugins add]
  -- @return [Number return a CHAR_ERR_* code to refuse the character; it becomes the result of
  --   Characters.create and is sent to the client. Return nothing to accept the data]
  local hook_result = hook.Run('PlayerCreateCharacter', target, data)

  if hook_result then
    return hook_result
  end

  local char = Character.new()
    char.steam_id = target:SteamID()
    char.name = data.name
    char.model = data.model or ''
    char.skin = data.skin or 0
    char.gender = data.gender
    char.phys_desc = data.phys_desc or ''
    char.health = 100
    char.user = target.record
  table.insert(target.record.characters, char)

  if SERVER then
    --- Called on the server when a character has been built and added to the record of its
    -- owner, before it is saved and sent to the owner. Handlers copy their own fields from the
    -- creation data to the character.
    -- @param owner [Player]
    -- @param char [Character the new character, not saved yet]
    -- @param char_data [Map creation data the character was built from]
    hook.Run('PostCreateCharacter', target, char, data)

    Characters.save(target, char)

    Cable.send(target, 'fl_create_character', Characters.to_networkable(target, char))
  end

  return CHAR_SUCCESS
end

if SERVER then
  --- Sends the networkable data of all of a player's characters to that player. Server only.
  -- @param target [Player]
  function Characters.send_to_client(target)
    Cable.send(target, 'fl_characters_load', Characters.all_to_networkable(target))
  end

  --- Returns the networkable data of every character of a player. Server only.
  -- @param target [Player]
  -- @return [List<Map> one entry per character, empty when the player has no record]
  -- @see [Characters.to_networkable]
  function Characters.all_to_networkable(target)
    local characters = target.record and target.record.characters or {}
    local ret = {}

    for k, v in pairs(characters) do
      ret[k] = Characters.to_networkable(target, v)
    end

    return ret
  end

  --- Builds the table of character fields that is sent to the owning client: id, user_id,
  -- steam_id, name, gender, phys_desc, model, skin and ammo. Server only.
  -- @param target [Player owner of the character]
  -- @param char [Character]
  -- @return [Map character data, or nil if the player or the character is not valid]
  function Characters.to_networkable(target, char)
    if !IsValid(target) or !char then return end

    return {
      id = tonumber(char.id),
      user_id = char.user_id,
      steam_id = target:SteamID(),
      name = char.name,
      gender = char.gender,
      phys_desc = char.phys_desc or 'This character has no physical description set!',
      model = char.model or 'models/humans/group01/male_02.mdl',
      skin = char.skin or 1,
      ammo = char.ammo
    }
  end

  --- Runs the SaveCharacterData hook and saves the player's record to the database, unless a
  -- PreSaveCharacter hook returns false. Server only.
  -- @param target [Player]
  -- @param character [Character]
  function Characters.save(target, character)
    if !IsValid(target) or !istable(character) or
       --- Lets plugins prepare for or prevent the saving of a character. Called on the
       -- server by `Characters.save`, before the SaveCharacterData hook.
       -- @param owner [Player]
       -- @param character [Character the character that is about to be saved]
       -- @return [Boolean return false to cancel the save]
       hook.Run('PreSaveCharacter', target, character) == false then return end

    --- Called on the server right before the record of a player is saved together with a
    -- character. Handlers write the data they keep for the character into its fields.
    -- @param owner [Player]
    -- @param character [Character the character that is being saved]
    hook.Run('SaveCharacterData', target, character)

    target:save_player()
  end

  --- Destroys one of the player's characters, removes it from their record and resends the
  -- character list to the player. Server only.
  -- @param target [Player]
  -- @param id [Number character ID]
  function Characters.delete(target, id)
    local char = target:get_character_by_id(id)

    if char then
      char:destroy()

      for k, v in pairs(target:get_all_characters()) do
        if tonumber(v.id) == id then
          table.remove(target.record.characters, k)

          break
        end
      end
    end

    Characters.send_to_client(target)
  end

  --- Changes the name of the player's active character, networks it and runs the
  -- CharacterNameChanged hook. Server only.
  -- @param target [Player]
  -- @param new_name [String ignored when it is not a string]
  function Characters.set_name(target, new_name)
    if !new_name or !isstring(new_name) then return end

    local char = target:get_character()
    local old_name = target:get_nv('name')

    if char then
      char.name = new_name or char.name
    end

    target:set_nv('name', new_name)
    --- Called on the server after `Characters.set_name` has changed the name of a player's
    -- active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param new_name [String]
    -- @param old_name [String the name that was networked before the change]
    hook.Run('CharacterNameChanged', target, char, new_name, old_name)

    Characters.send_to_client(target)
  end

  --- Changes the physical description of the player's active character, networks it and runs
  -- the CharacterDescChanged hook. Server only.
  -- @param target [Player]
  -- @param new_desc [String ignored when it is not a string]
  function Characters.set_desc(target, new_desc)
    if !new_desc or !isstring(new_desc) then return end

    local char = target:get_character()
    local old_desc = target:get_nv('phys_desc')

    if char then
      char.phys_desc = new_desc or char.phys_desc
    end

    target:set_nv('phys_desc', new_desc)
    --- Called on the server after `Characters.set_desc` has changed the physical description
    -- of a player's active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param new_desc [String]
    -- @param old_desc [String the description that was networked before the change]
    hook.Run('CharacterDescChanged', target, char, new_desc, old_desc)

    Characters.send_to_client(target)
  end

  --- Changes the model of the player and of their active character, networks it and runs the
  -- CharacterModelChanged hook. Server only.
  -- @param target [Player]
  -- @param model [String model path; ignored when it is not a string]
  function Characters.set_model(target, model)
    if !model or !isstring(model) then return end

    local char = target:get_character()
    local old_model = target:get_nv('model')

    if char then
      char.model = model or char.model
    end

    target:set_nv('model', model)
    target:SetModel(model)
    --- Called on the server after `Characters.set_model` has changed the model of a player and
    -- of their active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param model [String the new model path]
    -- @param old_model [String the model that was networked before the change]
    hook.Run('CharacterModelChanged', target, char, model, old_model)

    Characters.send_to_client(target)
  end

  --- Changes the gender of the player's active character, networks it and runs the
  -- CharacterGenderChanged hook. Server only.
  -- @param target [Player]
  -- @param new_gender [Number/String CHAR_GENDER_* value, or 'male', 'female' or 'no_gender']
  function Characters.set_gender(target, new_gender)
    new_gender = isstring(new_gender) and table.KeyFromValue(translate_gender, new_gender) or new_gender

    if !new_gender then return end

    local char = target:get_character()
    local old_gender = target:get_nv('gender')

    if char then
      char.gender = new_gender or char.gender
    end

    target:set_nv('gender', new_gender)
    --- Called on the server after `Characters.set_gender` has changed the gender of a player's
    -- active character and networked it.
    -- @param owner [Player]
    -- @param char [Character the active character, nil if the player has none]
    -- @param new_gender [Number CHAR_GENDER_* value]
    -- @param old_gender [Number the CHAR_GENDER_* value that was networked before the change]
    hook.Run('CharacterGenderChanged', target, char, new_gender, old_gender)

    Characters.send_to_client(target)
  end

  MVC.handler('fl_create_character', function(actor, data)
    --- Called on the server when the request of a client to create a character arrives, before
    -- the data is converted and passed to `Characters.create`. Handlers can fill in or change
    -- the data in place.
    -- @param actor [Player the player who sent the request]
    -- @param data [Map data collected by the creation menu: name, description, gender ('male',
    --   'female' or 'universal'), model, skin and the fields that other stages add]
    hook.Run('PreCreateCharacter', actor, data)

    data.gender = (data.gender == 'female' and CHAR_GENDER_FEMALE) or
      (data.gender == 'universal' and CHAR_GENDER_NONE) or CHAR_GENDER_MALE
    data.phys_desc = data.description

    local status = Characters.create(actor, data)

    Flux.dev_print('Creating character. Status: '..status)

    if status == CHAR_SUCCESS then
      Characters.send_to_client(actor)

      respond_to { success = true, status = status }

      Flux.dev_print('Success')
    else
      respond_to { success = false, status = status }

      Flux.dev_print('Error')
    end
  end)

  Cable.receive('fl_player_delete_character', function(actor, id)
    Flux.dev_print(actor:name()..' has deleted character #'..id)

    --- Called on the server when a player has asked to delete one of their characters, right
    -- before it is deleted.
    -- @param actor [Player]
    -- @param id [Number character ID as sent by the client; at this point it has not been
    --   checked that the player has such a character]
    hook.Run('OnCharacterDelete', actor, id)

    Characters.delete(actor, id)
  end)

  Cable.receive('fl_player_select_character', function(actor, id)
    Flux.dev_print(actor:name()..' has loaded character #'..id)

    actor:set_active_character(id)
  end)
else
  Cable.receive('fl_characters_load', function(data)
    timer.Create('fl_characters_defer', 0.1, 0, function()
      -- Wait until the player is valid.
      if IsValid(PLAYER) then
        PLAYER.characters = data

        timer.Remove('fl_characters_defer')

        --- Called on the client when the list of the local player's characters has arrived
        -- from the server and has been stored in PLAYER.characters. The server sends it when
        -- the player joins and again whenever one of their characters is created, deleted or
        -- changed.
        -- @param characters [List<Map> networked data of every character of the local player]
        hook.Run('OnCharactersReceived', data)
      end
    end)
  end)

  Cable.receive('fl_create_character', function(data)
    PLAYER.characters = PLAYER.characters or {}
    table.insert(PLAYER.characters, data)
  end)
end

do
  local player_meta = FindMetaTable('Player')

  --- Finds one of the player's own characters by its ID.
  -- @param id [Number character ID]
  -- @return [Character/Map the character record on the server or its networked data on the
  --   client, nil if the player has no such character]
  function player_meta:get_character_by_id(id)
    for k, v in ipairs(self:get_all_characters()) do
      if id == tonumber(v.id) then
        return v
      end
    end
  end

  --- Returns the networked ID of the player's active character.
  -- @return [Number character ID, or nil if no character has been selected]
  function player_meta:get_character_id()
    return self:get_nv('active_character')
  end

  --- Returns the player's active character. Bots get a plain table that is created on demand.
  -- @return [Character/Map the character record on the server or its networked data on the
  --   client, nil if no character is active]
  function player_meta:get_character()
    if SERVER and self.current_character then
      return self.current_character
    elseif self:IsBot() then
      self.char_data = self.char_data or {}

      return self.char_data
    end

    return self:get_character_by_id(self:get_character_id())
  end

  --- Checks whether the player has an active character. Always true for bots.
  -- @return [Boolean true if a character is active, false or nil otherwise]
  function player_meta:is_character_loaded()
    if self:IsBot() then return true end

    local id = self:get_character_id()

    return id and id > 0
  end

  --- Returns a field of the player's active character. On the client the value is read from
  -- the player's networked variable of the same name instead.
  -- @param id [String field name]
  -- @param default=nil [Any value to return when the field is not set]
  -- @return [Any]
  function player_meta:get_character_var(id, default)
    if SERVER then
      return self:get_character()[id] or default
    else
      return self:get_nv(id, default)
    end
  end

  --- Returns the physical description of the player's character.
  -- @return [String the description, or a placeholder text if none is set]
  function player_meta:get_phys_desc()
    return self:get_character_var('phys_desc', 'This character has no description!')
  end

  --- Returns the gender of the player's character as a string.
  -- @return [String 'male', 'female' or 'no_gender']
  function player_meta:get_gender()
    return translate_gender[self:get_character_var('gender', CHAR_GENDER_NONE)]
  end

  --- Returns all characters that belong to the player. Clients only know their own characters.
  -- @return [List character records on the server, networked character data on the client]
  function player_meta:get_all_characters()
    if SERVER then
      return self.record.characters
    else
      self.characters = self.characters or {}
      return self.characters
    end
  end
end
