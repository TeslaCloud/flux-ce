library.new 'character'

function character.create(player, data)
  if (!isstring(data.name) or (data.name:utf8len() < config.get('character_min_name_len') or
    data.name:utf8len() > config.get('character_max_name_len'))) then
    return CHAR_ERR_NAME
  end

  if (!isstring(data.phys_desc) or (data.phys_desc:utf8len() < config.get('character_min_desc_len') or
    data.phys_desc:utf8len() > config.get('character_max_desc_len'))) then
    return CHAR_ERR_DESC
  end

  if !isnumber(data.gender) or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE) then
    return CHAR_ERR_GENDER
  end

  if !isstring(data.model) or data.model == '' then
    return CHAR_ERR_MODEL
  end

  local hooked, result = hook.run('PlayerCreateCharacter', player, data)

  if hooked == false then
    return result or CHAR_ERR_UNKNOWN
  end

  local char = Character.new()
    char.id = char.last_id + 1
    char.steam_id = player:SteamID()
    char.name = data.name
    char.user_id = player.record.id
    char.model = data.model or ''
    char.skin = data.skin or 0
    char.gender = data.gender
    char.phys_desc = data.phys_desc or ''
    char.money = data.money or 0
    char.character_id = #player.record.characters + 1
    char.health = 100
    char.user = player.record

  player.record.characters[char.character_id] = char

  if SERVER then
    local char_id = player.record.character_id

    hook.run('PostCreateCharacter', player, char_id, char, data)

    character.save(player, char)

    cable.send(player, 'fl_create_character', char.character_id, character.to_networkable(player, char))
  end

  return CHAR_SUCCESS
end

if SERVER then
  function character.send_to_client(player)
    cable.send(player, 'fl_characters_load', character.all_to_networkable(player))
  end

  function character.all_to_networkable(player)
    local characters = player.record.characters or {}
    local ret = {}

    for k, v in pairs(characters) do
      ret[k] = character.to_networkable(player, v)
    end

    return ret
  end

  function character.to_networkable(player, char)
    if !IsValid(player) or !char then return end

    return {
      steam_id = player:SteamID(),
      name = char.name,
      phys_desc = char.phys_desc or 'This character has no physical description set!',
      model = char.model or 'models/humans/group01/male_02.mdl',
      skin = char.skin or 1,
      gender = char.gender,
      inventory = char.inventory,
      ammo = char.ammo,
      money = char.money,
      data = char.data,
      character_id = char.character_id,
      user_id = char.user_id
    }
  end

  function character.save(player, character)
    if !IsValid(player) or !IsValid(character) or hook.run('PreSaveCharacter', player, character) == false then return end

    hook.run('SaveCharacterData', player, character)
      character:save()
    hook.run('PostSaveCharacter', player, character)
  end

  function character.save_all(player)
    if !IsValid(player) then return end

    for k, v in ipairs(player.record.characters) do
      character.save(player, v)
    end
  end

  function character.set_name(player, char, new_name)
    if char then
      char.name = new_name or char.name

      player:set_nv('name', char.name)

      character.save(player, char)
    end
  end

  function character.set_model(player, char, model)
    if char then
      char.model = model or char.model

      player:set_nv('model', char.model)
      player:SetModel(char.model)

      character.save(player, char)
    end
  end

  cable.receive('fl_create_character', function(player, data)
    data.gender  = (data.gender and data.gender == 'Female' and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
    data.phys_desc = data.description

    local status = character.create(player, data)

    fl.dev_print('Creating character. Status: '..status)

    if status == CHAR_SUCCESS then
      character.send_to_client(player)
      cable.send(player, 'fl_player_created_character', true, status)

      fl.dev_print('Success')
    else
      cable.send(player, 'fl_player_created_character', false, status)

      fl.dev_print('Error')
    end
  end)

  cable.receive('fl_player_select_character', function(player, id)
    fl.dev_print(player:name()..' has loaded character #'..id)

    player:set_active_character(id)
  end)

  cable.receive('fl_player_delete_character', function(player, id)
    fl.dev_print(player:name()..' has deleted character #'..id)

    hook.run('OnCharacterDelete', player, id)

    player.record.characters[id]:destroy()
    table.remove(player.record.characters, id)

    character.send_to_client(player)
  end)
else
  cable.receive('fl_characters_load', function(data)
    fl.client.characters = data
  end)

  cable.receive('fl_create_character', function(idx, data)
    fl.client.characters = fl.client.characters or {}
    fl.client.characters[idx] = data

    if IsValid(fl.intro_panel) then
      fl.intro_panel:safe_remove()
      fl.intro_panel = theme.create_panel('main_menu')
      fl.intro_panel:MakePopup()
    end
  end)
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:get_active_character_id()
    return tonumber(self:get_nv('active_character', nil))
  end

  function player_meta:get_character_key()
    return self:get_nv('key', -1)
  end

  function player_meta:is_character_loaded()
    if self:IsBot() then return true end

    local id = self:get_active_character_id()

    return id and id > 0
  end

  function player_meta:get_phys_desc()
    return self:get_nv('phys_desc', 'This character has no description!')
  end

  do
    local genders = {
      [8] = 'male',
      [9] = 'female'
    }

    function player_meta:get_gender()
      local char = self:get_character()

      if char then
        return genders[char.gender] or 'no_gender'
      end

      return 'no_gender'
    end
  end

  function player_meta:get_character_var(id, default)
    if SERVER then
      return self:get_character()[id] or default
    else
      return self:get_nv(id, default)
    end
  end

  function player_meta:get_character_data(key, default)
    return self:get_character_var('data', {})[key] or default
  end

  function player_meta:get_character()
    if SERVER and self.current_character then
      return self.current_character
    elseif self:IsBot() then
      self.char_data = self.char_data or {}

      return self.char_data
    end

    local char_id = self:get_active_character_id()

    if char_id then
      return self:get_all_characters()[char_id]
    end
  end

  function player_meta:get_all_characters()
    return SERVER and self.record.characters or self.characters
  end
end
