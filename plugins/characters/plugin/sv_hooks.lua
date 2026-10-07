--- Hides, locks and silently kills players who spawn without an active character.
-- @param player [Player]
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

--- Saves the character of a player who died.
-- @param player [Player]
-- @param inflictor [Entity]
-- @param attacker [Entity]
function Characters:PlayerDeath(player, inflictor, attacker)
  player:save_character()
end

--- Saves the disconnecting player's character and stops any further saving of their data.
-- @param player [Player]
function Characters:PlayerDisconnected(player)
  player:save_character()
  player.should_save_data = false
end

--- Sends the character list to the player as soon as they have initialized, then runs the
-- PostRestoreCharacters hook.
-- @param player [Player]
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

--- Replaces line breaks in the new character's physical description with ' | '.
-- @param player [Player]
-- @param char [Character the character being created]
-- @param char_data [Hash character creation data]
function Characters:PostCreateCharacter(player, char, char_data)
  char.phys_desc = char.phys_desc:gsub('\n', ' | ')
end

--- Forwards the PostCharacterLoaded hook to the player's client, passing the character ID.
-- @param player [Player]
-- @param character [Character]
function Characters:PostCharacterLoaded(player, character)
  hook.run_client(player, 'PostCharacterLoaded', character.id)
end

--- Spawns the player and applies the character's model, skin, health and ammo, then runs the
-- PostCharacterLoaded hook.
-- @param player [Player]
-- @param character [Character]
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

--- Saves the player's current character before they switch to another one.
-- @param player [Player]
-- @param new_char [Character]
-- @param old_char [Character]
function Characters:OnCharacterChange(player, new_char, old_char)
  player:save_character()
end

--- Saves the player's character; called once a minute for every player.
-- @param player [Player]
function Characters:PlayerOneMinute(player)
  player:save_character()
end

--- Saves the active character of every connected player.
function Characters:SaveData()
  for k, v in ipairs(player.all()) do
    v:save_character()
  end
end

--- Validates character creation data: name and description length, gender, model and the
-- presence of the player's database record.
-- @param player [Player]
-- @param data [Hash character creation data]
-- @return [Number CHAR_ERR_* code when the data is rejected, otherwise nil]
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
