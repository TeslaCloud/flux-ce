function Characters:PostPlayerSpawn(player)
  if !player:is_character_loaded() then
    player:SetNoDraw(true)
    player:SetNotSolid(true)
    player:Lock()

    timer.Simple(0, function()
      if IsValid(player) then
        player:KillSilent()
        player:StripAmmo()
      end
    end)
  end
end

function Characters:PlayerDeath(player, inflictor, attacker)
  player:save_character()
end

function Characters:PlayerDisconnected(player)
  player:save_character()
  player.should_save_data = false
end

function Characters:PlayerRestored(player)
  local timer_name = 'fl_send_characters_to_'..player:SteamID()

  timer.Create(timer_name, 0.25, 0, function()
    if IsValid(player) and player:has_initialized() then
      Characters.send_to_client(player)

      hook.run('PostRestoreCharacters', player)

      timer.Remove(timer_name)
    end

    if !IsValid(player) then
      timer.Remove(timer_name)
    end
  end)
end

function Characters:PostCreateCharacter(player, char, char_data)
  char.phys_desc = char.phys_desc:gsub('\n', ' | ')
end

function Characters:PostCharacterLoaded(player, character)
  hook.run_client(player, 'PostCharacterLoaded', character.id)
end

function Characters:OnActiveCharacterSet(player, character)
  player:Spawn()
  player:SetModel(character.model or 'models/humans/group01/male_02.mdl')
  player:SetSkin(character.skin or 1)
  player:SetHealth(character.health or player:GetMaxHealth())
  player:StripAmmo()
  player:ScreenFade(SCREENFADE.IN, Color('white'), 2, 1)

  if istable(character.ammo) then
    for k, v in pairs(character.ammo) do
      player:SetAmmo(v, k)
    end
  end

  hook.run('PostCharacterLoaded', player, character)
end

function Characters:OnCharacterChange(player, new_char, old_char)
  player:save_character()
end

function Characters:PlayerOneMinute(player)
  player:save_character()
end

function Characters:SaveData()
  for k, v in ipairs(player.all()) do
    v:save_character()
  end
end

function Characters:PlayerCreateCharacter(player, data)
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

  if !istable(player.record) then
    return CHAR_ERR_RECORD
  end
end
