library.new 'character'

function character.Create(player, data)
  if (!isstring(data.name) or (data.name:utf8len() < config.get('character_min_name_len')
    or data.name:utf8len() > config.get('character_max_name_len'))) then
    return CHAR_ERR_NAME
  end

  if (!isstring(data.phys_desc) or (data.phys_desc:utf8len() < config.get('character_min_desc_len')
    or data.phys_desc:utf8len() > config.get('character_max_desc_len'))) then
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

  player.record.characters = player.record.characters or {}

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
  char.health = player:Health() or 100
  char.user = player.record

  player.record.characters[char.character_id] = char

  if SERVER then
    local char_id = player.record.character_id

    hook.run('PostCreateCharacter', player, char_id, char, data)

    character.Save(player, char)

    netstream.Start('fl_create_character', char.character_id, character.to_networkable(player, char))
  end

  return CHAR_SUCCESS
end

if SERVER then
  function character.SendToClient(player)
    netstream.Start(player, 'fl_loadcharacters', character.all_to_networkable(player))
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

  function character.Save(player, character)
    if !IsValid(player) or !IsValid(character) or hook.run('PreSaveCharacter', player, character) == false then return end

    hook.run('SaveCharacterData', player, character)
      character:save()
    hook.run('PostSaveCharacter', player, character)
  end

  function character.SaveAll(player)
    if !IsValid(player) then return end

    for k, v in ipairs(player.record.characters) do
      character.Save(player, v)
    end
  end

  function character.set_name(player, char, new_name)
    if char then
      char.name = new_name or char.name

      player:set_nv('name', char.name)

      character.Save(player, char)
    end
  end

  function character.SetModel(player, char, model)
    if char then
      char.model = model or char.model

      player:set_nv('model', char.model)
      player:SetModel(char.model)

      character.Save(player, char)
    end
  end
else
  netstream.Hook('fl_loadcharacters', function(data)
    fl.client.characters = data
  end)

  netstream.Hook('fl_create_character', function(idx, data)
    fl.client.characters = fl.client.characters or {}
    fl.client.characters[idx] = data

    if IsValid(fl.intro_panel) then
      fl.intro_panel:safe_remove()
      fl.intro_panel = theme.create_panel('main_menu')
      fl.intro_panel:MakePopup()
    end
  end)
end

if SERVER then
  netstream.Hook('CreateCharacter', function(player, data)
    data.gender  = (data.gender and data.gender == 'Female' and CHAR_GENDER_FEMALE) or CHAR_GENDER_MALE
    data.phys_desc = data.description

    local status = character.Create(player, data)

    fl.dev_print('Creating character. Status: '..status)

    if status == CHAR_SUCCESS then
      character.SendToClient(player)
      netstream.Start(player, 'PlayerCreatedCharacter', true, status)

      fl.dev_print('Success')
    else
      netstream.Start(player, 'PlayerCreatedCharacter', false, status)

      fl.dev_print('Error')
    end
  end)

  netstream.Hook('PlayerSelectCharacter', function(player, id)
    fl.dev_print(player:Name()..' has loaded character #'..id)

    player:SetActiveCharacter(id)
  end)

  netstream.Hook('PlayerDeleteCharacter', function(player, id)
    fl.dev_print(player:Name()..' has deleted character #'..id)

    hook.run('OnCharacterDelete', player, id)

    player.record.characters[id]:destroy()
    table.remove(player.record.characters, id)

    character.SendToClient(player)
  end)
end

do
  local player_meta = FindMetaTable('Player')

  function player_meta:GetActiveCharacterID()
    return tonumber(self:get_nv('active_character', nil))
  end

  function player_meta:GetCharacterKey()
    return self:get_nv('key', -1)
  end

  function player_meta:CharacterLoaded()
    if self:IsBot() then return true end

    local id = self:GetActiveCharacterID()
  
    return id and id > 0
  end

  function player_meta:GetPhysDesc()
    return self:get_nv('phys_desc', 'This character has no description!')
  end

  do
    local genders = {
      [8] = 'male',
      [9] = 'female'
    }

    function player_meta:get_gender()
      local char = self:GetCharacter()

      if char then
        return genders[char.gender] or 'no_gender'
      end

      return 'no_gender'
    end
  end

  function player_meta:GetCharacterVar(id, default)
    if SERVER then
      return self:GetCharacter()[id] or default
    else
      return self:get_nv(id, default)
    end
  end

  function player_meta:GetCharacterData(key, default)
    return self:GetCharacterVar('data', {})[key] or default
  end

  function player_meta:GetCharacter()
    if SERVER and self.current_character then
      return self.current_character
    elseif self:IsBot() then
      self.char_data = self.char_data or {}

      return self.char_data
    end
  
    local char_id = self:GetActiveCharacterID()

    if char_id then
      return self:GetAllCharacters()[char_id]
    end
  end

  function player_meta:GetAllCharacters()
    return SERVER and self.record.characters or self.characters
  end
end
