--- Hides, locks and silently kills players who spawn without an active character.
-- @param actor [Player]
function Characters:PostPlayerSpawn(actor)
  if !actor:is_character_loaded() then
    actor:SetNoDraw(true)
    actor:SetNotSolid(true)
    actor:Lock()

    timer.Simple(0, function()
      if IsValid(actor) then
        actor:KillSilent()
        actor:StripAmmo()
      end
    end)
  end
end

--- Saves the character of a player who died.
-- @param victim [Player]
-- @param inflictor [Entity]
-- @param attacker [Entity]
function Characters:PlayerDeath(victim, inflictor, attacker)
  victim:save_character()
end

--- Saves the disconnecting player's character and stops any further saving of their data.
-- @param actor [Player]
function Characters:PlayerDisconnected(actor)
  actor:save_character()
  actor.should_save_data = false
end

--- Sends the character list to the player as soon as they have initialized, then runs the
-- PostRestoreCharacters hook.
-- @param actor [Player]
function Characters:PlayerRestored(actor)
  local timer_name = 'fl_send_characters_to_'..actor:SteamID()

  timer.Create(timer_name, 0.25, 0, function()
    if IsValid(actor) and actor:has_initialized() then
      Characters.send_to_client(actor)

      hook.Run('PostRestoreCharacters', actor)

      timer.Remove(timer_name)
    end

    if !IsValid(actor) then
      timer.Remove(timer_name)
    end
  end)
end

--- Replaces line breaks in the new character's physical description with ' | '.
-- @param owner [Player]
-- @param char [Character the character being created]
-- @param char_data [Map character creation data]
function Characters:PostCreateCharacter(owner, char, char_data)
  char.phys_desc = char.phys_desc:gsub('\n', ' | ')
end

--- Forwards the PostCharacterLoaded hook to the player's client, passing the character ID.
-- @param owner [Player]
-- @param character [Character]
function Characters:PostCharacterLoaded(owner, character)
  hook.run_client(owner, 'PostCharacterLoaded', character.id)
end

--- Spawns the player and applies the character's model, skin, health and ammo, then runs the
-- PostCharacterLoaded hook.
-- @param owner [Player]
-- @param character [Character]
function Characters:OnActiveCharacterSet(owner, character)
  owner:Spawn()
  owner:SetModel(character.model or 'models/humans/group01/male_02.mdl')
  owner:SetSkin(character.skin or 1)
  owner:SetHealth(character.health or owner:GetMaxHealth())
  owner:StripAmmo()
  owner:ScreenFade(SCREENFADE.IN, Color('white'), 2, 1)

  if istable(character.ammo) then
    for k, v in pairs(character.ammo) do
      owner:SetAmmo(v, k)
    end
  end

  hook.Run('PostCharacterLoaded', owner, character)
end

--- Saves the player's current character before they switch to another one.
-- @param owner [Player]
-- @param new_char [Character]
-- @param old_char [Character]
function Characters:OnCharacterChange(owner, new_char, old_char)
  owner:save_character()
end

--- Saves the player's character; called once a minute for every player.
-- @param actor [Player]
function Characters:PlayerOneMinute(actor)
  actor:save_character()
end

--- Saves the active character of every connected player.
function Characters:SaveData()
  for k, v in player.Iterator() do
    v:save_character()
  end
end

--- Validates character creation data: name and description length, gender, model and the
-- presence of the player's database record.
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_* code when the data is rejected, otherwise nil]
function Characters:PlayerCreateCharacter(actor, data)
  if !isstring(data.name) or (utf8.len(data.name) < Config.get('character_min_name_len') or
    utf8.len(data.name) > Config.get('character_max_name_len')) then
    return CHAR_ERR_NAME
  end

  if !isstring(data.phys_desc) or (utf8.len(data.phys_desc) < Config.get('character_min_desc_len') or
    utf8.len(data.phys_desc) > Config.get('character_max_desc_len')) then
    return CHAR_ERR_DESC
  end

  if !isnumber(data.gender) or (data.gender < CHAR_GENDER_MALE or data.gender > CHAR_GENDER_NONE) then
    return CHAR_ERR_GENDER
  end

  if !isstring(data.model) or data.model == '' then
    return CHAR_ERR_MODEL
  end

  if !istable(actor.record) then
    return CHAR_ERR_RECORD
  end
end
