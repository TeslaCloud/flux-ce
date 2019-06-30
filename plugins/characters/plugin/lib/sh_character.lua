if !Characters then
  PLUGIN:set_global('Characters')
end

CHAR_GENDER_MALE    = 0    -- Guys.
CHAR_GENDER_FEMALE  = 1    -- Gals.
CHAR_GENDER_NONE    = 2    -- Gender-less characters such as vorts.

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
  function Characters.send_to_client(player)
    Cable.send(player, 'fl_characters_load', Characters.all_to_networkable(player))
  end

  function Characters.all_to_networkable(player)
    local characters = player.record and player.record.characters or {}
    local ret = {}

    for k, v in pairs(characters) do
      ret[k] = Characters.to_networkable(player, v)
    end

    return ret
  end

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

  function Characters.save(player, character)
    if !IsValid(player) or !istable(character) or hook.run('PreSaveCharacter', player, character) == false then return end

    hook.run('SaveCharacterData', player, character)

    player:save_player()
  end

  function Characters.delete(player, id)
    player:get_character_by_id(id):destroy()

    for k, v in pairs(player:get_all_characters()) do
      if tonumber(v.id) == id then
        table.remove(player.record.characters, k)
        break
      end
    end

    Characters.send_to_client(player)
  end

  function Characters.set_name(player, char, new_name)
    if char then
      char.name = new_name or char.name

      player:set_nv('name', char.name)
    end
  end

  function Characters.set_desc(player, char, new_desc)
    if char then
      char.phys_desc = new_desc or char.phys_desc

      player:set_nv('phys_desc', char.phys_desc)
    end
  end

  function Characters.set_model(player, char, model)
    if char then
      char.model = model or char.model

      player:set_nv('model', char.model)
      player:SetModel(char.model)
    end
  end

  function Characters.set_gender(player, char, new_gender)
    if char then
      char.gender = new_gender or char.gender

      player:set_nv('gender', char.gender)
    end
  end

  MVC.handler('fl_create_character', function(player, data)
    data.gender  = (data.gender and data.gender == 'female' and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
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

  MVC.handler('fl_delete_character', function(player, id)
    Flux.dev_print(player:name()..' has deleted character #'..id)

    hook.run('OnCharacterDelete', player, id)

    Characters.delete(player, id)

    respond_to()
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

  function player_meta:get_character_by_id(id)
    for k, v in ipairs(self:get_all_characters()) do
      if id == tonumber(v.id) then
        return v
      end
    end
  end

  function player_meta:get_active_character_id()
    return self:get_nv('active_character')
  end

  function player_meta:get_character()
    if SERVER and self.current_character then
      return self.current_character
    elseif self:IsBot() then
      self.char_data = self.char_data or {}

      return self.char_data
    end

    return self:get_character_by_id(self:get_active_character_id())
  end

  function player_meta:is_character_loaded()
    if self:IsBot() then return true end

    local id = self:get_active_character_id()

    return id and id > 0
  end

  function player_meta:get_character_var(id, default)
    if SERVER then
      return self:get_character()[id] or default
    else
      return self:get_nv(id, default)
    end
  end

  function player_meta:get_phys_desc()
    return self:get_character_var('phys_desc', 'This character has no description!')
  end

  local genders = {
    [CHAR_GENDER_MALE] = 'male',
    [CHAR_GENDER_FEMALE] = 'female',
    [CHAR_GENDER_NONE] = 'no_gender'
  }

  function player_meta:get_gender()
    return genders[self:get_character_var('gender', CHAR_GENDER_NONE)]
  end

  function player_meta:get_all_characters()
    return SERVER and self.record.characters or self.characters
  end
end
