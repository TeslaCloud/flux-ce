--- Access lists and owner text of owned doors, serverside.
-- The owner of a door gives other characters access to it at two levels, `DOOR_ACCESS_USE`
-- and `DOOR_ACCESS_MANAGE`, and puts a text on it. `Doors:change_access` and
-- `Doors:change_text` are what the door menu of a player asks for, with every rule checked,
-- and save the doors; `Doors:set_access` and `Doors:set_text` change the state without
-- asking, for staff tools and other plugins, and leave the saving to the caller.

--- Returns the access level of a character to a door.
-- @param entity [Entity the door]
-- @param character_id [Number ID of the character]
-- @return [Number DOOR_ACCESS_OWNER, DOOR_ACCESS_MANAGE, DOOR_ACCESS_USE or
--   DOOR_ACCESS_NONE]
function Doors:get_character_access(entity, character_id)
  local state = entity.door_state
  local owner = state and state.owner

  if !owner or !character_id then return DOOR_ACCESS_NONE end
  if owner.id == character_id then return DOOR_ACCESS_OWNER end

  local entry = state.access and state.access[character_id]

  return entry and entry.level or DOOR_ACCESS_NONE
end

--- Returns the access level of the active character of a player to a door.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @return [Number DOOR_ACCESS_OWNER, DOOR_ACCESS_MANAGE, DOOR_ACCESS_USE or
--   DOOR_ACCESS_NONE]
function Doors:get_access_level(actor, entity)
  return self:get_character_access(entity, self:get_character_id(actor))
end

--- Checks whether the active character of a player owns a door or has been given access
-- to it.
-- ```
-- if Doors:has_access(actor, entity, DOOR_ACCESS_MANAGE) then
--   Doors:set_text(entity, 'Closed')
-- end
-- ```
-- @param actor [Player]
-- @param entity [Entity the door]
-- @param level=DOOR_ACCESS_USE [Number the least access level that counts]
-- @return [Boolean]
function Doors:has_access(actor, entity, level)
  return self:get_access_level(actor, entity) >= (level or DOOR_ACCESS_USE)
end

--- Gives a character access to an owned door and to the doors linked with it, changes the
-- access it has or takes it away. Nothing is checked here; `Doors:change_access` is what
-- players go through.
-- @param entity [Entity the door]
-- @param character_id [Number ID of the character, which may not be the owner]
-- @param level [Number DOOR_ACCESS_USE or DOOR_ACCESS_MANAGE; DOOR_ACCESS_NONE takes the
--   access away]
-- @param name=nil [String name to list the character under; the name it is already listed
--   under is kept if omitted]
-- @return [Boolean false if the door has no owner, the character is its owner or an
--   argument is not valid]
function Doors:set_access(entity, character_id, level, name)
  character_id = tonumber(character_id)
  level = tonumber(level)

  local root = self:get_root(entity)
  local state = self:get_state(root)
  local owner = state.owner

  if !owner or !character_id or !level or owner.id == character_id then return false end

  level = math.Clamp(math.floor(level), DOOR_ACCESS_NONE, DOOR_ACCESS_MANAGE)
  state.access = state.access or {}

  local entry = state.access[character_id]
  local old_level = entry and entry.level or DOOR_ACCESS_NONE

  if level == old_level then return true end

  if level == DOOR_ACCESS_NONE then
    state.access[character_id] = nil
  else
    state.access[character_id] = {
      level = level,
      name = isstring(name) and name or entry and entry.name or ''
    }
  end

  --- Called on the server after the access of a character to an owned door has changed.
  -- Not called when the whole access list goes because the door changes hands.
  -- @param entity [Entity the door, or the main door of its group]
  -- @param character_id [Number ID of the character]
  -- @param level [Number the new level: DOOR_ACCESS_NONE, DOOR_ACCESS_USE or
  --   DOOR_ACCESS_MANAGE]
  -- @param old_level [Number the level the character had]
  hook.Run('DoorAccessChanged', root, character_id, level, old_level)

  return true
end

--- Sets the text of the owner on a door and on the doors linked with it. The text is not
-- checked here; `Doors:change_text` is what players go through.
-- @param entity [Entity the door]
-- @param text=nil [String the text; nil or an empty string removes it]
function Doors:set_text(entity, text)
  local root = self:get_root(entity)

  self:get_state(root).text = isstring(text) and text != '' and text or nil

  self:sync(root)
end

--- Makes a player give a character access to a door, change the access it has or take it
-- away. The player has to manage the door (DOOR_ACCESS_MANAGE); only the owner gives and
-- takes the DOOR_ACCESS_MANAGE level. A character that is not on the access list yet has
-- to be the active character of a player on the server. The PlayerCanChangeDoorAccess
-- hook can refuse the change. Both players are told about a change; a refusal is returned
-- for the caller to tell.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @param character_id [Number ID of the character]
-- @param level [Number DOOR_ACCESS_USE or DOOR_ACCESS_MANAGE; DOOR_ACCESS_NONE takes the
--   access away]
-- @return [Boolean whether the character now has that level, String error phrase if it
--   does not, Map arguments of the phrase]
function Doors:change_access(actor, entity, character_id, level)
  character_id = tonumber(character_id)
  level = tonumber(level)

  if !character_id or !level then return false, 'error.door.invalid_character' end

  level = math.floor(level)

  if level < DOOR_ACCESS_NONE or level > DOOR_ACCESS_MANAGE then
    return false, 'error.door.invalid_character'
  end

  local root = self:get_root(entity)
  local actor_level = self:get_access_level(actor, root)

  if actor_level < DOOR_ACCESS_MANAGE then return false, 'error.door.no_access' end

  local old_level = self:get_character_access(root, character_id)

  if old_level == DOOR_ACCESS_OWNER or character_id == self:get_character_id(actor) then
    return false, 'error.door.invalid_character'
  end

  if actor_level < DOOR_ACCESS_OWNER and (level == DOOR_ACCESS_MANAGE or old_level == DOOR_ACCESS_MANAGE) then
    return false, 'error.door.owner_only'
  end

  if level == old_level then return true end

  local state = self:get_state(root)
  local access = state.access or {}
  local entry = access[character_id]
  local target = self:find_character_player(character_id)
  local name

  if entry then
    name = entry.name
  elseif IsValid(target) then
    if table.Count(access) >= (tonumber(Config.get('door_access_entries')) or 32) then
      return false, 'error.door.access_full'
    end

    --- Lets plugins change the name under which a character is put on the access list of
    -- a door, for example when the player who gives the access does not know the real
    -- name of the character. Called on the server when a character is given access to a
    -- door for the first time.
    -- @param actor [Player the player who gives the access]
    -- @param target [Player the player whose active character receives it]
    -- @param entity [Entity the door, or the main door of its group]
    -- @return [String the name to list the character under; the name of the character is
    --   used when nothing is returned]
    name = hook.Run('GetDoorAccessName', actor, target, root) or target:name(true)
  else
    return false, 'error.door.invalid_character'
  end

  --- Asks whether a player may change the access of a character to a door. Called on the
  -- server once the player is known to have the right to make the change.
  -- @param actor [Player the player who manages the door]
  -- @param entity [Entity the door, or the main door of its group]
  -- @param character_id [Number ID of the character whose access changes]
  -- @param level [Number the level it is about to have: DOOR_ACCESS_NONE, DOOR_ACCESS_USE
  --   or DOOR_ACCESS_MANAGE]
  -- @param old_level [Number the level it has now]
  -- @return [Boolean return false to refuse the change, String error phrase to show the
  --   player, Map arguments of the phrase]
  local allowed, reason, arguments = hook.Run(
    'PlayerCanChangeDoorAccess', actor, root, character_id, level, old_level
  )

  if allowed == false then
    return false, reason or 'error.door.cannot_change_access', arguments
  end

  self:set_access(root, character_id, level, name)
  self:save()

  local suffix = level == DOOR_ACCESS_MANAGE and 'manage' or level == DOOR_ACCESS_USE and 'use' or 'none'

  actor:notify('notification.door.access.'..suffix, { name = name })

  if IsValid(target) then
    target:notify('notification.door.access_received.'..suffix)
  end

  return true
end

--- Makes a player put a text on a door that they manage (DOOR_ACCESS_MANAGE). Line breaks
-- and other control characters become spaces and the text is cut to the length that the
-- door_text_length config allows; an empty text removes the text. A refusal is returned
-- for the caller to tell.
-- @param actor [Player]
-- @param entity [Entity the door]
-- @param text [String]
-- @return [Boolean whether the text was set, String error phrase if it was not]
function Doors:change_text(actor, entity, text)
  if !isstring(text) then return false, 'error.door.invalid_text' end

  if self:get_access_level(actor, entity) < DOOR_ACCESS_MANAGE then
    return false, 'error.door.no_access'
  end

  text = string.Trim((text:gsub('%c+', ' ')))

  local length = utf8.len(text)

  if !isnumber(length) then return false, 'error.door.invalid_text' end

  local max_length = tonumber(Config.get('door_text_length')) or 32

  if length > max_length then
    text = text:utf8sub(1, max_length)
  end

  self:set_text(entity, text)
  self:save()

  return true
end
