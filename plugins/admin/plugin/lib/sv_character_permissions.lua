--- Server side of the character permissions of the admin plugin: permissions that are set on
-- a character instead of on the player who owns it. While a character is loaded, its
-- permissions are consulted together with those of its player before the player's role, see
-- `Bolt:get_permission_layer`; the player's other characters do not have them. They belong
-- to the character and apply to whoever has it loaded, such as a gamemaster who plays a
-- character that several players share.
--
-- A character has lasting permissions (`CharacterPermission` records) and temporary ones
-- (`CharacterTempPermission` records), with the same values as those of players: `PERM_ALLOW`,
-- `PERM_NEVER`, or `PERM_NO` for not set. They are loaded with the character, written to the
-- database as soon as they change and deleted when a player deletes the character. Where the
-- Characters plugin was present when the migrations ran, the tables have foreign keys to
-- `characters` with ON DELETE CASCADE, which delete them with a character however it is
-- deleted, e.g. along with its user.
--
-- When a character is loaded, switched or dropped, and whenever the permissions of a loaded
-- character change, the permissions of the active character are networked to every client
-- (`Player:get_character_permissions`) and the `PlayerPermissionChanged` hook is run for each
-- permission whose character value has changed, which gives or strips the tool gun and the
-- physgun.

if !Bolt then
  PLUGIN:set_global('Bolt')
end

local IsValid = IsValid
local istable = istable
local isstring = isstring
local tonumber = tonumber
local os_time = os.time

local function is_character(character)
  return istable(character) and tonumber(character.id) != nil
end

local function get_records(character, field)
  local records = character[field]

  if !istable(records) then
    records = {}
    character[field] = records
  end

  return records
end

--- Writes a permission record to the database. A record whose insert has not returned yet is
-- saved again as soon as it has been inserted, with the values it has by then.
-- @param record [CharacterPermission/CharacterTempPermission]
local function save_record(record)
  if record.id or !record.fetched then
    record:save()
  else
    record.save_on_create = true
  end
end

--- Deletes a permission record from the database. A record whose insert has not returned yet
-- is deleted as soon as it has been inserted.
-- @param record [CharacterPermission/CharacterTempPermission]
local function destroy_record(record)
  if record.id then
    record:destroy()
  elseif record.fetched then
    record.destroy_on_create = true
  end
end

--- Returns the active character of a player, if it is a saved character record.
-- @param target [Player]
-- @return [Character the active character, nil if none is loaded]
function Bolt:get_active_character(target)
  if !IsValid(target) then return end

  local character = target.current_character

  if is_character(character) then
    return character
  end
end

--- Returns the name of a player's character followed by the player's Steam name, as the
-- notifications of character permissions name it.
-- @param target [Player]
-- @param character [Character]
-- @return [String]
function Bolt:get_character_label(target, character)
  return tostring(character.name)..' ('..target:steam_name()..')'
end

--- Returns the connected player whose active character a character is.
-- @param character [Character]
-- @return [Player the player, nil if nobody has the character loaded]
function Bolt:get_character_holder(character)
  if !is_character(character) then return end

  local holder = character.bolt_holder

  if IsValid(holder) and holder.current_character == character then
    return holder
  end

  for _, client in player.Iterator() do
    if client.current_character == character then
      return client
    end
  end
end

--- Returns the lasting permissions of a character.
-- @param character [Character]
-- @return [Map PERM_ALLOW or PERM_NEVER keyed by permission ID; empty for anything that is
--   not a saved character]
function Bolt:get_character_permissions(character)
  local perm_table = {}

  if !is_character(character) then return perm_table end

  for _, record in ipairs(get_records(character, 'character_permissions')) do
    local value = tonumber(record.object)

    if isstring(record.permission_id) and (value == PERM_ALLOW or value == PERM_NEVER) then
      perm_table[record.permission_id] = value
    end
  end

  return perm_table
end

--- Returns the temporary permissions of a character, expired ones included until they are
-- removed. `Bolt:get_permission_layer` ignores the expired ones.
-- @param character [Character]
-- @return [Map tables with value (PERM_ value) and expires (unix timestamp) fields, keyed by
--   permission ID; empty for anything that is not a saved character]
function Bolt:get_character_temp_permissions(character)
  local perm_table = {}

  if !is_character(character) then return perm_table end

  for _, record in ipairs(get_records(character, 'character_temp_permissions')) do
    if isstring(record.permission_id) then
      perm_table[record.permission_id] = {
        value = tonumber(record.object),
        expires = time_from_timestamp(record.expires) or 0
      }
    end
  end

  return perm_table
end

--- Sets one of the lasting permissions of a character and writes it to the database. The
-- character does not have to be loaded. If it is the active character of a connected player,
-- that player's permissions are brought up to date, see `Bolt:update_character_permissions`.
-- ```
-- -- Lets the active character of a player use the tool gun, whatever the player's role says.
-- Bolt:set_character_permission(Bolt:get_active_character(target), 'toolgun', PERM_ALLOW)
-- ```
-- @param character [Character]
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ALLOW or PERM_NEVER, or PERM_NO to remove the permission]
-- @return [Boolean false if the character is not a saved character, the permission ID is
--   empty or the value is not a PERM_ value; true otherwise]
function Bolt:set_character_permission(character, perm_id, value)
  if !is_character(character) or !isstring(perm_id) or perm_id == '' then return false end
  if value != PERM_ALLOW and value != PERM_NO and value != PERM_NEVER then return false end

  local records = get_records(character, 'character_permissions')
  local found = false

  for index = #records, 1, -1 do
    local record = records[index]

    if record.permission_id == perm_id then
      if found or value == PERM_NO then
        destroy_record(record)

        table.remove(records, index)
      else
        found = true

        if tonumber(record.object) != value then
          record.object = value

          save_record(record)
        end
      end
    end
  end

  if !found and value != PERM_NO then
    local record = CharacterPermission.new()
      record.permission_id = perm_id
      record.object = value
      record.character_id = character.id
    record:save()

    table.insert(records, record)
  end

  self:update_character_permissions(character)

  return true
end

--- Gives a character a temporary permission value that takes precedence over its lasting
-- permissions until it expires, and writes it to the database. Giving the value the character
-- already has temporarily adds the duration to the time that is left; any other value starts
-- counting from now. A permission never lasts longer than `Bolt.max_temp_duration` from now.
-- If the character is the active character of a connected player, that player's permissions
-- are brought up to date.
-- @param character [Character]
-- @param perm_id [String permission ID]
-- @param value [Number PERM_ALLOW or PERM_NEVER]
-- @param duration [Number seconds until the permission expires, see Bolt#is_temp_duration]
-- @return [Boolean false if any of the arguments is not valid, true otherwise]
function Bolt:set_character_temp_permission(character, perm_id, value, duration)
  if !is_character(character) or !isstring(perm_id) or perm_id == '' then return false end
  if value != PERM_ALLOW and value != PERM_NEVER then return false end
  if !self:is_temp_duration(duration) then return false end

  local now = os_time()
  local expires = now + duration
  local records = get_records(character, 'character_temp_permissions')
  local found = false

  for index = #records, 1, -1 do
    local record = records[index]

    if record.permission_id == perm_id then
      if found then
        destroy_record(record)

        table.remove(records, index)
      else
        found = true

        if tonumber(record.object) == value then
          expires = math.min(math.max(time_from_timestamp(record.expires) or 0, now) + duration,
            now + self.max_temp_duration)
        else
          record.object = value
        end

        record.expires = to_datetime(expires)

        save_record(record)
      end
    end
  end

  if !found then
    local record = CharacterTempPermission.new()
      record.permission_id = perm_id
      record.object = value
      record.character_id = character.id
      record.expires = to_datetime(expires)
    record:save()

    table.insert(records, record)
  end

  self:update_character_permissions(character)

  return true
end

--- Removes a temporary permission from a character, deleting its database record. If the
-- character is the active character of a connected player, that player's permissions are
-- brought up to date.
-- @param character [Character]
-- @param perm_id [String permission ID]
-- @return [Boolean true if the character had the temporary permission]
function Bolt:delete_character_temp_permission(character, perm_id)
  if !is_character(character) then return false end

  local records = get_records(character, 'character_temp_permissions')
  local removed = false

  for index = #records, 1, -1 do
    if records[index].permission_id == perm_id then
      destroy_record(records[index])

      table.remove(records, index)

      removed = true
    end
  end

  if removed then
    self:update_character_permissions(character)
  end

  return removed
end

--- Deletes the expired temporary permissions of a character.
-- @param character [Character]
-- @return [Boolean true if anything was deleted]
function Bolt:remove_expired_character_permissions(character)
  if !is_character(character) then return false end

  local records = get_records(character, 'character_temp_permissions')
  local now = os_time()
  local removed = false

  for index = #records, 1, -1 do
    local record = records[index]

    if (time_from_timestamp(record.expires) or 0) <= now then
      destroy_record(record)

      table.remove(records, index)

      removed = true
    end
  end

  return removed
end

--- Brings the permissions of the player who has a character loaded up to date with the
-- character's records. Does nothing when nobody has the character loaded.
-- @param character [Character]
-- @see [Bolt#apply_character_permissions]
function Bolt:update_character_permissions(character)
  local holder = self:get_character_holder(character)

  if holder then
    self:apply_character_permissions(holder, holder.current_character)
  end
end

--- Networks the permissions of the character that a player has loaded, or takes them away
-- when character is nil, and runs the `PlayerPermissionChanged` hook for every permission
-- whose character value has changed. Called when a character is loaded, switched or dropped,
-- and whenever the permissions of a loaded character change.
-- @param target [Player]
-- @param character=nil [Character the active character of the player, nil when the player
--   is left without one]
function Bolt:apply_character_permissions(target, character)
  if !IsValid(target) then return end

  if is_character(character) then
    character.bolt_holder = target
  end

  local old_perms = target:get_character_permissions()
  local old_temp = target:get_character_temp_permissions()
  local new_perms, new_temp = {}, {}

  if is_character(character) then
    new_perms = self:get_character_permissions(character)
    new_temp = self:get_character_temp_permissions(character)
  end

  target:set_nv('character_permissions', next(new_perms) != nil and new_perms or nil)
  target:set_nv('character_temp_permissions', next(new_temp) != nil and new_temp or nil)

  local now = os_time()
  local changed = {}

  for _, perm_table in ipairs({ old_perms, old_temp, new_perms, new_temp }) do
    for perm_id in pairs(perm_table) do
      if changed[perm_id] == nil then
        local old_value = self:get_layer_value(old_temp[perm_id], old_perms[perm_id], now)
        local new_value = self:get_layer_value(new_temp[perm_id], new_perms[perm_id], now)

        changed[perm_id] = old_value != new_value and (new_value or PERM_NO) or false
      end
    end
  end

  for perm_id, value in SortedPairs(changed) do
    if value then
      hook.Run('PlayerPermissionChanged', target, perm_id, value)
    end
  end
end

--- Takes the expired temporary permissions off a player's active character once a minute.
-- @param actor [Player]
function Bolt:expire_character_permissions(actor)
  local character = self:get_active_character(actor)

  if character and self:remove_expired_character_permissions(character) then
    self:apply_character_permissions(actor, character)
  end
end
