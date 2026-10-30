--- Server hooks of the Gamemastery plugin: load the pool, put gamemasters into gamemaster
-- mode and take them out of it, keep track of who plays which pool character, send pool
-- characters that are being created to the pool, and keep players of the `gamemaster` role
-- from owning characters.

--- Loads the pool of gamemaster characters once the database is ready.
function Gamemastery:ActiveRecordReady()
  Gamemastery.load_pool()
end

--- Puts a gamemaster who spawns without an active character into gamemaster mode.
-- @param actor [Player]
function Gamemastery:PostPlayerSpawn(actor)
  if Gamemastery.should_be_in_mode(actor) then
    Gamemastery.enter_mode(actor)
  end
end

--- Takes a player out of gamemaster mode once a character has become their active one.
-- @param owner [Player]
-- @param _character [Character]
function Gamemastery:ActiveCharacterSet(owner, _character)
  Gamemastery.exit_mode(owner)
end

--- Moves a player who has possessed a pool character back to where they possessed it.
-- @param owner [Player]
-- @param _character [Character]
function Gamemastery:PostLoadCharacter(owner, _character)
  if owner.gm_transform then
    Gamemastery.apply_transform(owner)
  end
end

--- Keeps the Spawn Saver plugin from moving a player who is about to be put where they
-- possessed a pool character.
-- @param target [Player]
-- @param _character [Character]
-- @param _spawn_point [Map]
-- @return [Boolean false while a position is kept for the player, otherwise nil]
function Gamemastery:ShouldRestorePlayerSpawn(target, _character, _spawn_point)
  if target.gm_transform then
    return false
  end
end

--- Forgets who played a pool character that its player switches away from.
-- @param owner [Player]
-- @param _new_char [Character the character that is about to become active]
-- @param old_char [Character the character that is still active]
function Gamemastery:PreSwitchCharacter(owner, _new_char, old_char)
  if istable(old_char) and old_char.possessed_by == owner then
    old_char.possessed_by = nil

    Gamemastery.send_pool()
  end
end

--- Forgets who played a pool character that its player drops.
-- @param owner [Player]
-- @param character [Character the character that is being dropped]
function Gamemastery:ActiveCharacterCleared(owner, character)
  if character.possessed_by == owner then
    character.possessed_by = nil

    Gamemastery.send_pool()
  end
end

--- Frees the pool character of a player who leaves. The Characters plugin has saved it by
-- then; the pool is sent once the player is gone.
-- @param actor [Player]
function Gamemastery:PlayerDisconnected(actor)
  local character = actor.current_character

  if istable(character) and character.possessed_by == actor then
    character.possessed_by = nil

    timer.Simple(0, function()
      Gamemastery.send_pool()
    end)
  end
end

--- Brings a player whose role has changed in line with their permission.
-- @param target [Player]
-- @param _group [Role]
-- @param _old_group [Role]
function Gamemastery:PlayerUserGroupChanged(target, _group, _old_group)
  Gamemastery.refresh(target)
end

--- Brings a player whose 'gamemastery' permission has been set individually in line with it.
-- @param target [Player]
-- @param perm_id [String]
-- @param _value [Number]
function Gamemastery:PlayerPermissionChanged(target, perm_id, _value)
  if perm_id == 'gamemastery' then
    Gamemastery.refresh(target)
  end
end

--- Puts a gamemaster who has just joined into gamemaster mode and sends them the pool.
-- @param actor [Player]
function Gamemastery:PostRestoreCharacters(actor)
  Gamemastery.refresh(actor)
end

--- Adds the user record of the pool to the records whose characters are searched by name, so
-- that commands such as `/charban remove` work on the pool characters that are in memory.
-- @param records [List<User> added to in place]
function Gamemastery:AdjustLoadedUserRecords(records)
  local record = Gamemastery.get_pool_record()

  if istable(record) then
    records[#records + 1] = record
  end
end

--- Decides whether a character that is being created goes into the pool: always for players
-- of the `gamemaster` role, when the client asks for it only for gamemasters, never for
-- anybody else.
-- @param actor [Player]
-- @param data [Map creation data, changed in place]
function Gamemastery:PreCreateCharacter(actor, data)
  if Gamemastery.has_gamemaster_role(actor) then
    data.gamemaster = true
  elseif data.gamemaster != true or !Gamemastery.is_gamemaster(actor) then
    data.gamemaster = nil
  end

  actor.gm_pool_creation = data.gamemaster == true
end

--- Refuses a pool character while the pool is not ready to take it.
-- @param _actor [Player]
-- @param data [Map creation data]
-- @return [Number CHAR_ERR_RECORD when the pool cannot take the character, otherwise nil]
function Gamemastery:PlayerCreateCharacter(_actor, data)
  if data.gamemaster and !Gamemastery.is_pool_ready() then
    return CHAR_ERR_RECORD
  end
end

--- Gives a character that is created for the pool to the user record of the pool.
-- @param target [Player]
-- @param data [Map creation data]
-- @return [User the pool record for a pool character, otherwise nil]
function Gamemastery:GetCharacterOwner(target, data)
  target.gm_pool_creation = nil

  if data.gamemaster and Gamemastery.is_pool_ready() then
    return Gamemastery.get_pool_record()
  end
end

--- Sends the pool to the gamemasters once a new pool character has been saved for the first
-- time and has its ID.
-- @param _owner [Player]
-- @param char [Character]
-- @param _char_data [Map]
function Gamemastery:PostCreateCharacter(_owner, char, _char_data)
  if !Gamemastery.is_pool_character(char) then return end

  --- Sends the pool once the new pool character has been inserted into the database.
  function char:after_create()
    Gamemastery.send_pool()
  end
end

--- Refuses characters of their own to players of the `gamemaster` role.
-- @param actor [Player]
-- @param character [Character]
-- @return [Boolean false and String the reason for a character that is not in the pool,
--   otherwise nil]
function Gamemastery:PlayerCanUseCharacter(actor, character)
  if Gamemastery.has_gamemaster_role(actor) and !Gamemastery.is_pool_character(character) then
    return false, 'error.gamemastery.own_character'
  end
end

--- Lets gamemasters play pool characters of factions that are full.
-- @param actor [Player]
-- @param _faction_table [Faction]
-- @param _rank_table [Map]
-- @param character [Character]
-- @return [Boolean true for a gamemaster and a pool character, otherwise nil]
function Gamemastery:PlayerCanBypassFactionLimit(actor, _faction_table, _rank_table, character)
  if Gamemastery.is_pool_character(character) and Gamemastery.is_gamemaster(actor) then
    return true
  end
end

--- Forgets a world entity of a pool character that has been removed and sends the pool.
-- @param entity [Entity]
function Gamemastery:EntityRemoved(entity)
  if entity:GetClass() != 'fl_gm_character' then return end

  local id = entity.gm_character_id

  if id and Gamemastery.world_entities[id] == entity then
    Gamemastery.world_entities[id] = nil

    Gamemastery.send_pool()
  end
end
