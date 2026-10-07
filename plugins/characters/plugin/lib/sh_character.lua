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
-- local status = Characters.create(player, {
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
-- @param player [Player owner of the new character]
-- @param data [Hash creation data: name, phys_desc, gender, model and optionally skin]
-- @return [Number CHAR_SUCCESS, or the CHAR_ERR_* code returned by the hook]
function Characters.create(player, data)
  local hook_result = hook.run('PlayerCreateCharacter', player, data)

  if hook_result then
    return hook_result
  end

  local char = Character.new()
    char.steam_id = player:SteamID()
    char.name = data.name
    char.model = data.model or ''
    char.skin = data.skin or 0
    char.gender = data.gender
    char.phys_desc = data.phys_desc or ''
    char.health = 100
    char.user = player.record
  table.insert(player.record.characters, char)

  if SERVER then
    hook.run('PostCreateCharacter', player, char, data)

    Characters.save(player, char)

    Cable.send(player, 'fl_create_character', Characters.to_networkable(player, char))
  end

  return CHAR_SUCCESS
end

if SERVER then
  --- Sends the networkable data of all of a player's characters to that player. Server only.
  -- @param player [Player]
  function Characters.send_to_client(player)
    Cable.send(player, 'fl_characters_load', Characters.all_to_networkable(player))
  end

  --- Returns the networkable data of every character of a player. Server only.
  -- @param player [Player]
  -- @return [Array<Hash> one entry per character, empty when the player has no record]
  -- @see [Characters.to_networkable]
  function Characters.all_to_networkable(player)
    local characters = player.record and player.record.characters or {}
    local ret = {}

    for k, v in pairs(characters) do
      ret[k] = Characters.to_networkable(player, v)
    end

    return ret
  end

  --- Builds the table of character fields that is sent to the owning client: id, user_id,
  -- steam_id, name, gender, phys_desc, model, skin and ammo. Server only.
  -- @param player [Player owner of the character]
  -- @param char [Character]
  -- @return [Hash character data, or nil if the player or the character is not valid]
  function Characters.to_networkable(player, char)
    if !IsValid(player) or !char then return end

    return {
      id = tonumber(char.id),
      user_id = char.user_id,
      steam_id = player:SteamID(),
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
  -- @param player [Player]
  -- @param character [Character]
  function Characters.save(player, character)
    if !IsValid(player) or !istable(character) or hook.run('PreSaveCharacter', player, character) == false then return end

    hook.run('SaveCharacterData', player, character)

    player:save_player()
  end

  --- Destroys one of the player's characters, removes it from their record and resends the
  -- character list to the player. Server only.
  -- @param player [Player]
  -- @param id [Number character ID]
  function Characters.delete(player, id)
    local char = player:get_character_by_id(id)

    if char then
      char:destroy()

      for k, v in pairs(player:get_all_characters()) do
        if tonumber(v.id) == id then
          table.remove(player.record.characters, k)

          break
        end
      end
    end

    Characters.send_to_client(player)
  end

  --- Changes the name of the player's active character, networks it and runs the
  -- CharacterNameChanged hook. Server only.
  -- @param player [Player]
  -- @param new_name [String ignored when it is not a string]
  function Characters.set_name(player, new_name)
    if !new_name or !isstring(new_name) then return end

    local char = player:get_character()
    local old_name = player:get_nv('name')

    if char then
      char.name = new_name or char.name
    end

    player:set_nv('name', new_name)
    hook.run('CharacterNameChanged', player, char, new_name, old_name)

    Characters.send_to_client(player)
  end

  --- Changes the physical description of the player's active character, networks it and runs
  -- the CharacterDescChanged hook. Server only.
  -- @param player [Player]
  -- @param new_desc [String ignored when it is not a string]
  function Characters.set_desc(player, new_desc)
    if !new_desc or !isstring(new_desc) then return end

    local char = player:get_character()
    local old_desc = player:get_nv('phys_desc')

    if char then
      char.phys_desc = new_desc or char.phys_desc
    end

    player:set_nv('phys_desc', new_desc)
    hook.run('CharacterDescChanged', player, char, new_desc, old_desc)

    Characters.send_to_client(player)
  end

  --- Changes the model of the player and of their active character, networks it and runs the
  -- CharacterModelChanged hook. Server only.
  -- @param player [Player]
  -- @param model [String model path; ignored when it is not a string]
  function Characters.set_model(player, model)
    if !model or !isstring(model) then return end

    local char = player:get_character()
    local old_model = player:get_nv('model')

    if char then
      char.model = model or char.model
    end

    player:set_nv('model', model)
    player:SetModel(model)
    hook.run('CharacterModelChanged', player, char, model, old_model)

    Characters.send_to_client(player)
  end

  --- Changes the gender of the player's active character, networks it and runs the
  -- CharacterGenderChanged hook. Server only.
  -- @param player [Player]
  -- @param new_gender [Number/String CHAR_GENDER_* value, or 'male', 'female' or 'no_gender']
  function Characters.set_gender(player, new_gender)
    new_gender = isstring(new_gender) and table.key_from_value(translate_gender, new_gender) or new_gender

    if !new_gender then return end

    local char = player:get_character()
    local old_gender = player:get_nv('gender')

    if char then
      char.gender = new_gender or char.name
    end

    player:set_nv('gender', new_gender)
    hook.run('CharacterGenderChanged', player, char, new_gender, old_gender)

    Characters.send_to_client(player)
  end

  MVC.handler('fl_create_character', function(player, data)
    hook.run('PreCreateCharacter', player, data)

    data.gender = (data.gender and data.gender == 'female' and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
    data.phys_desc = data.description

    local status = Characters.create(player, data)

    Flux.dev_print('Creating character. Status: '..status)

    if status == CHAR_SUCCESS then
      Characters.send_to_client(player)

      respond_to { success = true, status = status }

      Flux.dev_print('Success')
    else
      respond_to { success = false, status = status }

      Flux.dev_print('Error')
    end
  end)

  Cable.receive('fl_player_delete_character', function(player, id)
    Flux.dev_print(player:name()..' has deleted character #'..id)

    hook.run('OnCharacterDelete', player, id)

    Characters.delete(player, id)
  end)

  Cable.receive('fl_player_select_character', function(player, id)
    Flux.dev_print(player:name()..' has loaded character #'..id)

    player:set_active_character(id)
  end)
else
  Cable.receive('fl_characters_load', function(data)
    timer.Create('fl_characters_defer', 0.1, 0, function()
      -- Wait until player is valid.
      if IsValid(PLAYER) then
        PLAYER.characters = data

        timer.Remove('fl_characters_defer')
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
  -- @return [Character/Hash the character record on the server or its networked data on the
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
  -- @return [Character/Hash the character record on the server or its networked data on the
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
  -- @return [Array character records on the server, networked character data on the client]
  function player_meta:get_all_characters()
    if SERVER then
      return self.record.characters
    else
      self.characters = self.characters or {}
      return self.characters
    end
  end
end
