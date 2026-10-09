--- Server side of the Characters plugin: keeps players without a character or with a banned
-- one out of the world, sends the character list to players who join, applies a character to
-- its player when it is loaded, saves characters together with the health, armor and ammo of
-- their players, validates character creation data and remembers which names are taken.

--- Reads the names of all characters from the database, so that `Characters.is_name_taken`
-- also knows the characters of players who are not connected.
function Characters:ActiveRecordReady()
  local query = ActiveRecord.Database:select('characters')
    query:select('name')
    query:callback(function(result)
      Characters.taken_names = {}

      if istable(result) then
        for k, v in ipairs(result) do
          Characters.remember_name(v.name)
        end
      end
    end)
  query:execute()
end

--- Hides, locks and silently kills players who spawn without an active character or with a
-- banned one.
-- @param actor [Player]
function Characters:PostPlayerSpawn(actor)
  if !actor:is_character_loaded() or actor:is_character_banned() then
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

--- Keeps a player whose active character is banned from respawning.
-- @param actor [Player]
-- @return [Boolean false while the active character is banned, otherwise nil]
function Characters:PlayerDeathThink(actor)
  if actor:is_character_banned() then
    return false
  end
end

--- Saves the character of a player who died.
-- @param victim [Player]
-- @param inflictor [Entity]
-- @param attacker [Entity]
function Characters:PlayerDeath(victim, inflictor, attacker)
  victim:save_character()
end

--- Refuses to let a player switch characters while they are dead or ragdolled.
-- @param actor [Player]
-- @param character [Character the character the player wants to load]
-- @param current [Character the active character of the player]
-- @return [Boolean false and String the reason when the switch is refused, otherwise nil]
function Characters:PlayerCanSwitchCharacter(actor, character, current)
  if !actor:Alive() then
    return false, 'error.character.switch_dead'
  end

  if isfunction(actor.is_ragdolled) and actor:is_ragdolled() then
    return false, 'error.character.switch_ragdolled'
  end
end

--- Writes the health, armor and reserve ammo of the player into their active character
-- before it is saved. Nothing is written for a banned character, whose player stays dead,
-- or before the saved values have been given to the player.
-- @param owner [Player]
-- @param character [Character the character that is being saved]
function Characters:SaveCharacterData(owner, character)
  if owner:IsBot() or !owner.vitals_restored or tobool(character.banned) then return end

  if owner:get_character() == character then
    Characters.store_vitals(owner, character)
  end
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

      --- Called on the server after the character list has been sent to a player who has
      -- joined, which happens once their record is restored and they have initialized.
      -- @param actor [Player]
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

--- Spawns the player and applies the character's model, skin, health, armor and ammo, then
-- runs the PostCharacterLoaded hook.
-- @param owner [Player]
-- @param character [Character]
function Characters:OnActiveCharacterSet(owner, character)
  owner:Spawn()
  owner:SetModel(character.model or 'models/humans/group01/male_02.mdl')
  owner:SetSkin(character.skin or 1)
  owner:ScreenFade(SCREENFADE.IN, Color('white'), 2, 1)

  Characters.restore_vitals(owner, character)

  --- Called on the server once a loaded character has been applied to its player: the player
  -- has been spawned and given the model, skin, health, armor and ammo of the character. The
  -- Characters plugin forwards the hook to the client of the owner, where handlers receive
  -- only the ID of the character.
  -- @param owner [Player]
  -- @param character [Character]
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

--- Validates character creation data: the presence of the player's database record, the
-- character limit, name and description length, gender, model and, unless the name was
-- generated, that no other character has the name.
-- @param actor [Player]
-- @param data [Map character creation data]
-- @return [Number CHAR_ERR_* code when the data is rejected, otherwise nil]
function Characters:PlayerCreateCharacter(actor, data)
  if !istable(actor.record) then
    return CHAR_ERR_RECORD
  end

  if Characters.limit_reached(actor) then
    return CHAR_ERR_LIMIT
  end

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

  if !data.name_generated and Characters.is_name_taken(data.name) then
    return CHAR_ERR_EXISTS
  end
end
