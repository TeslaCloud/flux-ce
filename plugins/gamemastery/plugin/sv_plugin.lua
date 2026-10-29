--- Server side of the Gamemastery plugin: the pool of gamemaster characters and its user
-- record, gamemaster mode, possessing and releasing pool characters, placing them in the
-- world and deleting them, and the network handlers behind the gamemaster panel.
--
-- The pool is the `characters` relation of a `User` record whose SteamID is
-- `Gamemastery.pool_steam_id`. It is loaded, or created on the first run, when the database
-- is ready. Every player with the 'gamemastery' permission receives the list of pool
-- characters when they join, when their role or permissions change and whenever the pool
-- changes.

local IsValid = IsValid
local ipairs = ipairs
local isnumber = isnumber
local isstring = isstring
local istable = istable
local isvector = isvector
local tobool = tobool
local tonumber = tonumber
local cable_send = Cable.send
local math_abs = math.abs
local math_huge = math.huge
local string_trim = string.Trim

local default_model = 'models/humans/group01/male_02.mdl'
local request_delay = 1
local spawn_distance = 4096
local floor_normal_z = 0.7
local wall_offset = 20

Gamemastery.world_entities = Gamemastery.world_entities or {}

Cable.check_networked_string('fl_gm_pool')

--- Brings a character name to the form in which names are compared: lower case, without
-- surrounding whitespace and with every run of whitespace turned into a single space.
-- @param name [String]
-- @return [String]
local function normalize_name(name)
  return (string_trim(name):gsub('%s+', ' ')):utf8lower()
end

--- Checks whether a number is neither NaN nor infinite.
-- @param number [Number]
-- @return [Boolean]
local function is_finite(number)
  return isnumber(number) and number == number and math_abs(number) != math_huge
end

--- Checks whether the player has sent a gamemaster request of a kind less than a second ago,
-- and starts the wait for the next one when they have not.
-- @param actor [Player]
-- @param kind [String 'pool' for pool requests, 'action' for everything else]
-- @return [Boolean true when the request has to be refused]
local function is_throttled(actor, kind)
  local cur_time = CurTime()
  local next_requests = actor.gm_next_request or {}

  actor.gm_next_request = next_requests

  if next_requests[kind] and next_requests[kind] > cur_time then
    return true
  end

  next_requests[kind] = cur_time + request_delay

  return false
end

--- Loads the user record that owns the pool characters, together with the characters, or
-- creates and saves it when it does not exist yet. The pool is sent to the gamemasters once
-- it has been loaded.
function Gamemastery.load_pool()
  User:where('steam_id', Gamemastery.pool_steam_id):expect(function(record)
    record.characters = record.characters or {}

    Gamemastery.pool_record = record
    Gamemastery.send_pool()
  end):rescue(function(record)
    record.steam_id = Gamemastery.pool_steam_id
    record.name = Gamemastery.pool_name
    record.role = 'user'
    record.characters = {}

    Gamemastery.pool_record = record

    record:save()
  end)
end

--- Returns the user record that owns the pool characters.
-- @return [User the record, nil until it has been loaded]
function Gamemastery.get_pool_record()
  return Gamemastery.pool_record
end

--- Checks whether the pool can take new characters, which it can once its user record has
-- been saved to the database.
-- @return [Boolean]
function Gamemastery.is_pool_ready()
  local record = Gamemastery.pool_record

  return istable(record) and record.id != nil
end

--- Returns the pool characters.
-- @return [List<Character> empty until the pool has been loaded]
function Gamemastery.get_pool()
  local record = Gamemastery.pool_record

  if istable(record) and istable(record.characters) then
    return record.characters
  end

  return {}
end

--- Checks whether a character belongs to the pool.
-- @param character [Character]
-- @return [Boolean]
function Gamemastery.is_pool_character(character)
  local record = Gamemastery.pool_record

  return istable(character) and record != nil and character.user == record
end

--- Finds a pool character by its ID.
-- @param id [Number character ID]
-- @return [Character the character, nil if the pool has none with the ID]
function Gamemastery.find_character(id)
  id = tonumber(id)

  if !id then return end

  for _, char_data in ipairs(Gamemastery.get_pool()) do
    if tonumber(char_data.id) == id then
      return char_data
    end
  end
end

--- Finds a pool character by its whole name, compared without regard to letter case and
-- repeated or surrounding whitespace.
-- @param name [String]
-- @return [Character the character, nil when none or more than one has the name; Boolean
--   true as the second value when several characters have it]
function Gamemastery.find_character_by_name(name)
  if !isstring(name) or string_trim(name) == '' then return end

  local key = normalize_name(name)
  local found = {}

  for _, char_data in ipairs(Gamemastery.get_pool()) do
    if isstring(char_data.name) and normalize_name(char_data.name) == key then
      found[#found + 1] = char_data
    end
  end

  if #found == 1 then
    return found[1]
  end

  return nil, #found > 1
end

--- Returns the player who is playing a pool character.
-- @param character [Character]
-- @return [Player the player, nil when nobody plays the character]
function Gamemastery.get_possessor(character)
  local possessor = istable(character) and character.possessed_by

  if IsValid(possessor) and possessor.current_character == character then
    return possessor
  end
end

--- Builds the list of pool characters that is sent to the gamemasters: id, name, model, skin,
-- phys_desc, faction (when the character has one), banned, possessed_by (the Steam name of
-- the player who plays the character, nil when nobody does) and in_world (whether the
-- character stands in the world). Characters that have not been saved yet are left out.
-- @return [List<Map>]
function Gamemastery.pool_to_networkable()
  local result = {}
  local world_entities = Gamemastery.world_entities

  for _, char_data in ipairs(Gamemastery.get_pool()) do
    local id = tonumber(char_data.id)

    if !id then continue end

    local possessor = Gamemastery.get_possessor(char_data)

    result[#result + 1] = {
      id = id,
      name = char_data.name,
      model = char_data.model or default_model,
      skin = tonumber(char_data.skin) or 0,
      phys_desc = char_data.phys_desc or '',
      faction = isstring(char_data.faction) and char_data.faction or nil,
      banned = tobool(char_data.banned),
      possessed_by = possessor and possessor:steam_name() or nil,
      in_world = IsValid(world_entities[id])
    }
  end

  return result
end

--- Returns the connected players who receive the pool: everyone with the 'gamemastery'
-- permission whose client has initialized.
-- @return [List<Player>]
function Gamemastery.get_receivers()
  local receivers = {}

  for _, candidate in player.Iterator() do
    if candidate:has_initialized() and Gamemastery.is_gamemaster(candidate) then
      receivers[#receivers + 1] = candidate
    end
  end

  return receivers
end

--- Sends the list of pool characters to a player, or to every gamemaster. A player who has
-- received the pool before and has lost the permission since receives an empty list, which
-- takes the pool from their client.
-- @param target=nil [Player the player to send it to; every gamemaster when nil]
function Gamemastery.send_pool(target)
  if target != nil then
    if !IsValid(target) or target:IsBot() then return end

    if Gamemastery.is_gamemaster(target) then
      target.gm_pool_sent = true

      cable_send(target, 'fl_gm_pool', Gamemastery.pool_to_networkable())
    elseif target.gm_pool_sent then
      target.gm_pool_sent = nil

      cable_send(target, 'fl_gm_pool', {})
    end

    return
  end

  local receivers = Gamemastery.get_receivers()

  if #receivers == 0 then return end

  for _, receiver in ipairs(receivers) do
    receiver.gm_pool_sent = true
  end

  cable_send(receivers, 'fl_gm_pool', Gamemastery.pool_to_networkable())
end

--- Checks whether a player belongs in gamemaster mode: a real player with the
-- 'gamemastery' permission and no active character.
-- @param target [Player]
-- @return [Boolean]
function Gamemastery.should_be_in_mode(target)
  return IsValid(target) and !target:IsBot() and !target:is_character_loaded() and Gamemastery.is_gamemaster(target)
end

--- Moves a player to the position and view angles kept in their gm_transform field on the
-- next tick, once whatever spawned them has placed them, and forgets the field. A player
-- who is not in gamemaster mode is unstuck if the position puts them into something.
-- @param actor [Player]
function Gamemastery.apply_transform(actor)
  local transform = actor.gm_transform

  if !istable(transform) then return end

  timer.Simple(0, function()
    if !IsValid(actor) then return end

    if actor.gm_transform == transform then
      actor.gm_transform = nil
    end

    actor:SetPos(transform.position)
    actor:SetEyeAngles(transform.angles)

    if !Gamemastery.is_in_mode(actor) and actor:stuck() then
      actor:unstuck()
    end
  end)
end

--- Remembers where a player is and where they look, for `Gamemastery.apply_transform`.
-- @param actor [Player]
-- @param position=nil [Vector the position to keep; where the player is when nil]
-- @param angles=nil [Angle the view angles to keep; where the player looks when nil]
function Gamemastery.keep_transform(actor, position, angles)
  actor.gm_transform = {
    position = position or actor:GetPos(),
    angles = angles or actor:EyeAngles()
  }
end

--- Puts a player into gamemaster mode: in noclip, invulnerable and vanished, with the
-- `gamemastering` networked variable set. Observer mode is dropped first, giving the player
-- back the color it saved, since gamemaster mode hides the player in its own way. A kept
-- position is applied.
-- @param actor [Player]
function Gamemastery.enter_mode(actor)
  if actor.observer_data or actor:get_nv('observer') then
    if actor.observer_data then
      actor:SetColor(actor.observer_data.color)
    end

    actor.observer_data = nil
    actor:set_nv('observer', false)
  end

  if actor.is_vanished then
    actor:set_vanished(false)
  end

  actor:set_vanished(true)
  actor:SetMoveType(MOVETYPE_NOCLIP)
  actor:GodEnable()
  actor:set_nv('gamemastering', true)

  Gamemastery.apply_transform(actor)
end

--- Takes a player out of gamemaster mode: they become visible, solid, mortal and walk again.
-- Does nothing for a player who is not in it.
-- @param actor [Player]
function Gamemastery.exit_mode(actor)
  if !Gamemastery.is_in_mode(actor) then return end

  actor:set_nv('gamemastering', false)
  actor:set_vanished(false)
  actor:GodDisable()

  if actor:GetMoveType() == MOVETYPE_NOCLIP then
    actor:SetMoveType(MOVETYPE_WALK)
  end
end

--- Removes the world entity of a pool character, if it has one.
-- @param character [Character]
-- @param silent=false [Boolean do not send the pool to the gamemasters afterward]
function Gamemastery.remove_from_world(character, silent)
  local id = istable(character) and tonumber(character.id)

  if !id then return end

  local entity = Gamemastery.world_entities[id]

  Gamemastery.world_entities[id] = nil

  if IsValid(entity) then
    entity:Remove()

    if !silent then
      Gamemastery.send_pool()
    end
  end
end

--- Turns a gamemaster into a pool character on the spot. They keep the given position and
-- view angles, or their own, and leave gamemaster mode. A character that someone else plays
-- is refused, and so is anything that `Characters.can_use` refuses. The world entity of the
-- character is removed.
-- @param actor [Player]
-- @param character [Character the pool character]
-- @param position=nil [Vector where the player is put; where they are when nil]
-- @param angles=nil [Angle where the player looks; where they look when nil]
-- @return [Boolean true when the character was possessed; otherwise false, String the reason
--   as a language phrase and Map the arguments of the phrase]
function Gamemastery.possess(actor, character, position, angles)
  if !Gamemastery.is_gamemaster(actor) then
    return false, 'error.gamemastery.no_permission'
  end

  if !Gamemastery.is_pool_character(character) or !tonumber(character.id) then
    return false, 'error.gamemastery.invalid_character'
  end

  local possessor = Gamemastery.get_possessor(character)

  if possessor and possessor != actor then
    return false, 'error.gamemastery.possessed', { name = possessor:steam_name() }
  end

  local allowed, reason, arguments = Characters.can_use(actor, character)

  if !allowed then
    return false, reason, arguments
  end

  Gamemastery.keep_transform(actor, position, angles)
  Gamemastery.remove_from_world(character, true)

  character.possessed_by = actor

  Characters.activate(actor, character)
  Gamemastery.send_pool()

  return true
end

--- Takes the active character away from a player where they stand: the character is saved
-- and dropped, and the player is spawned again at the same spot. A gamemaster enters
-- gamemaster mode; anyone else is left without a character as usual and gets the main menu.
-- @param actor [Player]
-- @return [Character the character that was dropped]
function Gamemastery.drop_character(actor)
  local character = actor.current_character

  Gamemastery.keep_transform(actor)

  actor:clear_active_character()
  actor:Spawn()

  if !Gamemastery.is_in_mode(actor) then
    actor.gm_transform = nil

    Characters.open_menu(actor)
  end

  return character
end

--- Makes a player stop playing the pool character they possess and puts them back into
-- gamemaster mode where they stand.
-- @param actor [Player]
-- @return [Boolean true when a character was released; otherwise false and String the
--   reason as a language phrase. Character the released character as the second value on
--   success]
function Gamemastery.release(actor)
  if !Gamemastery.is_pool_character(actor.current_character) then
    return false, 'error.gamemastery.not_possessing'
  end

  return true, Gamemastery.drop_character(actor)
end

--- Places a pool character in the world as an `fl_gm_character` entity, where a trace from
-- the eyes of the gamemaster along a direction hits, at most 4096 units away. A trace that
-- hits a wall puts the character on the floor in front of it. The character faces the
-- gamemaster. A character that already stands in the world is moved; one that somebody
-- plays or that is banned is refused.
-- @param actor [Player]
-- @param character [Character the pool character]
-- @param direction [Vector normalized direction in world space]
-- @return [Boolean true when the character was placed; otherwise false, String the reason as
--   a language phrase and Map the arguments of the phrase]
function Gamemastery.spawn_in_world(actor, character, direction)
  if !Gamemastery.is_gamemaster(actor) then
    return false, 'error.gamemastery.no_permission'
  end

  if !Gamemastery.is_pool_character(character) or !tonumber(character.id) then
    return false, 'error.gamemastery.invalid_character'
  end

  local possessor = Gamemastery.get_possessor(character)

  if possessor then
    return false, 'error.gamemastery.possessed', { name = possessor:steam_name() }
  end

  if tobool(character.banned) then
    return false, 'error.gamemastery.banned'
  end

  local start = actor:EyePos()
  local trace = util.TraceLine({
    start = start,
    endpos = start + direction * spawn_distance,
    filter = actor,
    mask = MASK_PLAYERSOLID
  })

  if !trace.Hit or trace.HitSky then
    return false, 'error.gamemastery.no_spot'
  end

  local position = trace.HitPos

  if trace.HitNormal.z < floor_normal_z then
    local above = trace.HitPos + trace.HitNormal * wall_offset
    local floor_trace = util.TraceLine({
      start = above,
      endpos = above - Vector(0, 0, spawn_distance),
      filter = actor,
      mask = MASK_PLAYERSOLID
    })

    position = floor_trace.Hit and floor_trace.HitPos or above
  end

  if !util.IsInWorld(position) then
    return false, 'error.gamemastery.no_spot'
  end

  local id = tonumber(character.id)
  local entity = Gamemastery.world_entities[id]
  local facing = Angle(0, (actor:GetPos() - position):Angle().y, 0)

  if !IsValid(entity) then
    entity = ents.Create('fl_gm_character')

    if !IsValid(entity) then
      return false, 'error.gamemastery.no_spot'
    end

    entity:set_character(character)
    entity:SetPos(position)
    entity:SetAngles(facing)
    entity:Spawn()
    entity:Activate()
  else
    entity:set_character(character)
    entity:SetPos(position)
    entity:SetAngles(facing)
  end

  Gamemastery.world_entities[id] = entity
  Gamemastery.send_pool()

  return true
end

--- Possesses the pool character of a world entity for a gamemaster who has pressed the use
-- key on it, at the position and yaw of the entity. An entity whose character is gone is
-- removed.
-- @param actor [Player]
-- @param entity [Entity the `fl_gm_character` entity]
function Gamemastery.use_entity(actor, entity)
  if !Gamemastery.is_gamemaster(actor) or is_throttled(actor, 'action') then return end

  local character = Gamemastery.find_character(entity.gm_character_id)

  if !character then
    entity:Remove()

    return
  end

  local success, reason, arguments = Gamemastery.possess(
    actor,
    character,
    entity:GetPos(),
    Angle(0, entity:GetAngles().y, 0)
  )

  if success then
    actor:notify('notification.gamemastery.possessed', { name = character.name })
  else
    actor:notify(reason, arguments)
  end
end

--- Deletes a pool character that nobody plays: removes its world entity, destroys its record,
-- frees its name, sends the pool to the gamemasters and tells the staff.
-- @param actor [Player the gamemaster who deletes the character]
-- @param character [Character the pool character]
-- @return [Boolean true when the character was deleted; otherwise false, String the reason as
--   a language phrase and Map the arguments of the phrase]
function Gamemastery.delete(actor, character)
  if !Gamemastery.is_gamemaster(actor) then
    return false, 'error.gamemastery.no_permission'
  end

  if !Gamemastery.is_pool_character(character) or !tonumber(character.id) then
    return false, 'error.gamemastery.invalid_character'
  end

  if Gamemastery.get_possessor(character) then
    return false, 'error.gamemastery.delete_possessed'
  end

  local name = character.name
  local pool = Gamemastery.get_pool()

  Gamemastery.remove_from_world(character, true)

  character:destroy()

  Characters.forget_name(name)

  for index, char_data in ipairs(pool) do
    if char_data == character then
      table.remove(pool, index)

      break
    end
  end

  Gamemastery.send_pool()

  Command:notify_staff('notification.gamemastery.deleted', {
    player = get_player_name(actor),
    name = name
  })

  return true
end

--- Brings a player in line with their permission: a gamemaster without a character is put
-- into gamemaster mode, one of the `gamemaster` role loses their own active character where
-- they stand, and a player who has lost the permission loses the pool character they play
-- or leaves gamemaster mode and gets the main menu. Sends the pool to the player afterward.
-- Does nothing until the player has initialized.
-- @param target [Player]
function Gamemastery.refresh(target)
  if !IsValid(target) or target:IsBot() or !target:has_initialized() then return end

  local character = target:is_character_loaded() and target.current_character or nil

  if Gamemastery.is_gamemaster(target) then
    if character and Gamemastery.has_gamemaster_role(target) and !Gamemastery.is_pool_character(character) then
      Gamemastery.drop_character(target)
    elseif !character and !Gamemastery.is_in_mode(target) then
      target:Spawn()
    end
  elseif Gamemastery.is_pool_character(character) then
    Gamemastery.drop_character(target)
  elseif Gamemastery.is_in_mode(target) then
    Gamemastery.exit_mode(target)

    target:Spawn()

    Characters.open_menu(target)
  end

  Gamemastery.send_pool(target)
end

local function answer(actor, success, phrase, arguments, reason, reason_arguments)
  if success then
    actor:notify(phrase, arguments)
  elseif isstring(reason) then
    actor:notify(reason, reason_arguments)
  end
end

local function accept_action(actor)
  if !Gamemastery.is_gamemaster(actor) then return false end

  if is_throttled(actor, 'action') then
    actor:notify('error.gamemastery.wait')

    return false
  end

  return true
end

Cable.receive('fl_gm_pool_request', function(actor)
  if !Gamemastery.is_gamemaster(actor) or is_throttled(actor, 'pool') then return end

  Gamemastery.send_pool(actor)
end)

Cable.receive('fl_gm_possess', function(actor, id)
  if !isnumber(id) or !accept_action(actor) then return end

  local character = Gamemastery.find_character(id)
  local success, reason, arguments = Gamemastery.possess(actor, character)

  local name = character and character.name

  answer(actor, success, 'notification.gamemastery.possessed', { name = name }, reason, arguments)
end)

Cable.receive('fl_gm_release', function(actor)
  if !accept_action(actor) then return end

  local success, result = Gamemastery.release(actor)

  if success then
    actor:notify('notification.gamemastery.released', { name = result.name })
  else
    actor:notify(result)
  end
end)

Cable.receive('fl_gm_spawn', function(actor, id, direction)
  if !isnumber(id) or !isvector(direction) then return end
  if !is_finite(direction.x) or !is_finite(direction.y) or !is_finite(direction.z) then return end
  if direction:LengthSqr() == 0 or !accept_action(actor) then return end

  local character = Gamemastery.find_character(id)
  local name = character and character.name
  local success, reason, arguments = Gamemastery.spawn_in_world(actor, character, direction:GetNormalized())

  answer(actor, success, 'notification.gamemastery.placed', { name = name }, reason, arguments)
end)

Cable.receive('fl_gm_delete', function(actor, id)
  if !isnumber(id) or !accept_action(actor) then return end

  local success, reason, arguments = Gamemastery.delete(actor, Gamemastery.find_character(id))

  if !success then
    actor:notify(reason, arguments)
  end
end)
