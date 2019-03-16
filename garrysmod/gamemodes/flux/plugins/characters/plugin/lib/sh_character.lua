if !Characters then
  PLUGIN:set_global('Characters')
end

function Characters.create(player, data)
  if (!isstring(data.name) or (utf8.len(data.name) < Config.get('character_min_name_len') or
    utf8.len(data.name) > Config.get('character_max_name_len'))) then
    return CHAR_ERR_NAME
  end

  if (!isstring(data.phys_desc) or (utf8.len(data.phys_desc) < Config.get('character_min_desc_len') or
    utf8.len(data.phys_desc) > Config.get('character_max_desc_len'))) then
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

  if !istable(player.record) then
    return CHAR_ERR_RECORD
  end

  local char = Character.new()
    char.steam_id = player:SteamID()
    char.name = data.name
    char.model = data.model or ''
    char.skin = data.skin or 0
    char.gender = data.gender
    char.phys_desc = data.phys_desc or ''
    char.money = data.money or 0
    char.character_id = #player.record.characters + 1
    char.health = 100
    char.user = player.record
  table.insert(player.record.characters, char)

  if SERVER then
    local char_id = player.record.character_id

    hook.run('PostCreateCharacter', player, char_id, char, data)

    Characters.save(player, char)

    Cable.send(player, 'fl_create_character', char.character_id, Characters.to_networkable(player, char))
  end

  return CHAR_SUCCESS
end

if SERVER then
  function Characters.send_to_client(player)
    print("Sending characters to client...")
    local nwkbl = Characters.all_to_networkable(player)
    print("Networkable table:")
    PrintTable(nwkbl)
    print("sending cable stream")
    Cable.send(player, 'fl_characters_load', nwkbl)
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

  function Characters.save(player, character)
    if !IsValid(player) or !istable(character) or hook.run('PreSaveCharacter', player, character) == false then return end

    hook.run('SaveCharacterData', player, character)
      player.record:save()
    hook.run('PostSaveCharacter', player, character)
  end

  function Characters.set_name(player, char, new_name)
    if char then
      char.name = new_name or char.name

      player:set_nv('name', char.name)

      Characters.save(player, char)
    end
  end

  function Characters.set_model(player, char, model)
    if char then
      char.model = model or char.model

      player:set_nv('model', char.model)
      player:SetModel(char.model)

      Characters.save(player, char)
    end
  end

  Cable.receive('fl_create_character', function(player, data)
    data.gender  = (data.gender and data.gender == 'Female' and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
    data.phys_desc = data.description

    local status = Characters.create(player, data)

    Flux.dev_print('Creating character. Status: '..status)

    if status == CHAR_SUCCESS then
      Characters.send_to_client(player)
      Cable.send(player, 'fl_player_created_character', true, status)

      Flux.dev_print('Success')
    else
      Cable.send(player, 'fl_player_created_character', false, status)

      Flux.dev_print('Error')
    end
  end)

  Cable.receive('fl_player_select_character', function(player, id)
    Flux.dev_print(player:name()..' has loaded character #'..id)

    player:set_active_character(id)
  end)

  Cable.receive('fl_player_delete_character', function(player, id)
    Flux.dev_print(player:name()..' has deleted character #'..id)

    hook.run('OnCharacterDelete', player, id)

    player.record.characters[id]:destroy()
    table.remove(player.record.characters, id)

    Characters.send_to_client(player)
  end)
else
  Cable.receive('fl_characters_load', function(data)
    print("hey we received some characters")
    if !PLAYER then
      PLAYER = LocalPlayer()
    end

    PLAYER.characters = data

    print("PLAYER.characters set!")
    PrintTable(PLAYER.characters)
  end)

  Cable.receive('fl_create_character', function(idx, data)
    if !PLAYER then
      PLAYER = LocalPlayer()
    end

    PLAYER.characters = PLAYER.characters or {}
    PLAYER.characters[idx] = data

    if IsValid(Flux.intro_panel) then
      Flux.intro_panel:safe_remove()
      Flux.intro_panel = Theme.create_panel('main_menu')
      Flux.intro_panel:MakePopup()
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
    return self:get_character_var('phys_desc', 'This character has no description!')
  end

  do
    local genders = {
      [8] = 'male',
      [9] = 'female'
    }

    function player_meta:get_gender()
      return self:get_character_var('gender', 'no_gender')
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
