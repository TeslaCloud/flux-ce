--- Server side of the permissions of Bolt: writing permission records to the database,
-- removal of temporary permissions, the rule that keeps players from changing their own
-- permissions, the subcommands of the `permission` and `charpermission` commands, which share
-- everything but the layer they change, with the reading of their permission and duration
-- arguments, and sending the config again to a player whose right to edit configs has
-- changed.

--- Writes a permission record of a player or of a character to the database. A record whose
-- insert has not returned yet is saved again as soon as it has been inserted, with the values
-- it has by then.
-- @param record [Permission/TempPermission/CharacterPermission/CharacterTempPermission]
function Bolt:save_permission_record(record)
  if record.id or !record.fetched then
    record:save()
  else
    record.save_on_create = true
  end
end

--- Deletes a permission record of a player or of a character from the database. A record
-- whose insert has not returned yet is deleted as soon as it has been inserted, and a record
-- that was never saved is left alone.
-- @param record [Permission/TempPermission/CharacterPermission/CharacterTempPermission]
function Bolt:destroy_permission_record(record)
  if record.id then
    record:destroy()
  elseif record.fetched then
    record.destroy_on_create = true
  end
end

--- Finishes a permission record whose insert has returned: a record that was deleted while
-- it was being inserted is deleted, and one that was changed is saved again with its current
-- values. The `after_create` callback of the permission models.
-- @param record [Permission/TempPermission/CharacterPermission/CharacterTempPermission]
function Bolt:permission_record_created(record)
  if record.destroy_on_create then
    record:destroy()
  elseif record.save_on_create then
    record.save_on_create = nil

    record:save()
  end
end

--- Writes a permission record of a player to the database right away, as a row of their
-- user record. Nothing is written while the user record has no ID: a record that is being
-- inserted saves its permissions once it has its ID, and the blank record of a bot is never
-- saved.
-- @param target [Player]
-- @param record [Permission/TempPermission]
function Bolt:save_user_permission(target, record)
  local user_id = target.record.id

  if !user_id then return end

  record.user_id = user_id

  self:save_permission_record(record)
end

--- Checks whether a player may change the permissions of a target, in any layer: their own
-- and temporary ones, and those of their active character. Nobody may change their own
-- permissions except root players; the server console may change anybody's. A player who is
-- refused is notified.
-- @param actor [Player the player making the change, an invalid entity for the server console]
-- @param target [Player the player whose permissions are changed]
-- @return [Boolean]
function Bolt:check_permission_target(actor, target)
  if !IsValid(actor) or actor != target or actor:is_root() then return true end

  actor:notify('error.permission_own')

  return false
end

--- Returns the targets of a command whose permissions the caller may change, see
-- `Bolt:check_permission_target`.
-- @param actor [Player the caller, an invalid entity for the server console]
-- @param targets [List<Player>]
-- @return [List<Player>]
function Bolt:get_permission_targets(actor, targets)
  local result = {}

  for _, target in ipairs(targets) do
    if self:check_permission_target(actor, target) then
      result[#result + 1] = target
    end
  end

  return result
end

--- Checks whether the caller of a command may change a permission of somebody else: only a
-- permission that the caller has can be allowed, denied, unset or have its temporary value
-- removed, so that lifting a denial takes the same right as granting. The server console may
-- change any. A caller who may not is notified.
-- @param actor [Player the caller, an invalid entity for the server console]
-- @param perm_id [String permission ID]
-- @return [Boolean]
function Bolt:check_permission_value(actor, perm_id)
  if !IsValid(actor) or actor:can(perm_id) then return true end

  actor:notify('error.permission_not_yours', { permission = perm_id })

  return false
end

--- Removes a temporary permission from a player, destroying its database record, taking it
-- off the player's record and updating the networked table. The config is sent to the player
-- again if that has changed their right to edit configs, and the PlayerTempPermissionChanged
-- hook runs. Does nothing when the player has no such temporary permission.
-- @param target [Player]
-- @param perm_id [String permission ID]
function Bolt:delete_temp_permission(target, perm_id)
  local records = target.record and target.record.temp_permissions
  local perm_table = target:get_temp_permissions()
  local removed = perm_table[perm_id] != nil

  if records then
    for i = #records, 1, -1 do
      if records[i].permission_id == perm_id then
        self:destroy_permission_record(records[i])

        table.remove(records, i)

        removed = true
      end
    end
  end

  if !removed then return end

  perm_table[perm_id] = nil

  target:set_temp_permissions(perm_table)

  self:update_config_access(target)

  hook.Run('PlayerTempPermissionChanged', target, perm_id, PERM_NO)
end

--- Returns the targeted players of a `charpermission` subcommand who have a character loaded,
-- with their characters, and tells the caller when none of them has.
-- @param actor [Player the caller, an invalid entity for the server console]
-- @param targets [List<Player>]
-- @return [List<Map> tables with the player (target), the character (character) and the
--   name of the character followed by the Steam name of the player (label)]
function Bolt:get_loaded_characters(actor, targets)
  local result = {}

  for _, target in ipairs(targets) do
    local character = self:get_active_character(target)

    if character then
      result[#result + 1] = {
        target = target,
        character = character,
        label = self:get_character_label(target, character)
      }
    end
  end

  if #result == 0 then
    Flux.Player:notify(actor, 'error.character_permission.no_character')
  end

  return result
end

--- The layers of permissions that the `permission` and `charpermission` commands change, by
-- layer: the phrases of each command (`command.<command>.*`, `notification.<notification>.*`
-- and the error of a permission that is set for none of the targets), the placeholder that
-- names the targets in the messages to staff, and how the layer finds its entries (one per
-- target, with the player in `target`), names them, sets, resets and reads their values.
local command_layers = {
  user = {
    command = 'permission',
    notification = 'permission',
    not_set = 'error.permission_not_set',
    subject = 'target',
    entries = function(_actor, targets)
      local result = {}

      for _, target in ipairs(targets) do
        if target.record then
          result[#result + 1] = { target = target }
        end
      end

      return result
    end,
    join = entries -> util.player_list_to_string(table.map(entries, entry -> entry.target)),
    set = function(entry, perm_id, value, duration)
      if duration then
        entry.target:set_temp_permission(perm_id, value, duration)
      else
        entry.target:set_permission(perm_id, value)
      end

      return true
    end,
    has_value = function(entry, perm_id)
      local target = entry.target

      return target:get_permission(perm_id) != PERM_NO or target:get_temp_permission(perm_id) != nil
    end,
    reset = function(entry, perm_id)
      entry.target:set_permission(perm_id, PERM_NO)

      Bolt:delete_temp_permission(entry.target, perm_id)
    end
  },
  character = {
    command = 'charpermission',
    notification = 'character_permission',
    not_set = 'error.character_permission.not_set',
    subject = 'character',
    entries = |actor, targets| -> Bolt:get_loaded_characters(actor, targets),
    join = entries -> table.concat(table.map(entries, entry -> entry.label), ', '),
    set = function(entry, perm_id, value, duration)
      if duration then
        return Bolt:set_character_temp_permission(entry.character, perm_id, value, duration)
      end

      return Bolt:set_character_permission(entry.character, perm_id, value)
    end,
    has_value = function(entry, perm_id)
      local character = entry.character

      return Bolt:get_character_permissions(character)[perm_id] != nil or
        Bolt:get_character_temp_permissions(character)[perm_id] != nil
    end,
    reset = function(entry, perm_id)
      Bolt:set_character_permission(entry.character, perm_id, PERM_NO)
      Bolt:delete_character_temp_permission(entry.character, perm_id)
    end
  }
}

--- Runs the `grant` and `revoke` subcommands of the `permission` (layer 'user') and
-- `charpermission` (layer 'character') commands: sets a permission of the targeted players or
-- of their active characters, for good or temporarily, and notifies the players and staff.
-- Callers can only set what they may do themselves, and only root players their own
-- permissions, see `Bolt:check_permission_value` and `Bolt:check_permission_target`; the
-- server console can set anything.
-- @param cmd [Command the subcommand that runs]
-- @param layer_id [String 'user' or 'character']
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose permission, or whose characters' permission, is
--   set]
-- @param permission_id [String permission ID, command ID or command alias]
-- @param duration_text [String duration as read by Bolt:interpret_ban_time, empty or a
--   permanent word such as 'perma' to set it for good]
-- @param value [Number PERM_ALLOW or PERM_NEVER]
function Bolt:set_command_permission(cmd, layer_id, actor, targets, permission_id, duration_text, value)
  local layer = command_layers[layer_id]
  local permission = self:find_command_permission(actor, permission_id)

  if !permission or !self:check_permission_value(actor, permission.id) then return end

  targets = self:get_permission_targets(actor, targets)

  if #targets == 0 then return end

  local valid, duration = self:read_permission_duration(actor, duration_text)

  if !valid then return end

  local granted = value == PERM_ALLOW
  local notification = 'notification.'..layer.notification..(granted ? '.granted' : '.revoked')
  local affected = {}

  for _, entry in ipairs(layer.entries(actor, targets)) do
    if layer.set(entry, permission.id, value, duration) then
      entry.target:notify(notification, { permission = permission.id })

      affected[#affected + 1] = entry
    end
  end

  if #affected == 0 then return end

  local phrase = 'command.'..layer.command..(granted ? '.grant' : '.revoke')..'.message'

  cmd:notify_staff(duration and phrase..'_temporary' or phrase, {
    player = get_player_name(actor),
    [layer.subject] = layer.join(affected),
    permission = permission.id,
    time = duration and Flux.Lang:duration(duration) or nil
  })
end

--- Runs the `reset` subcommands of the `permission` (layer 'user') and `charpermission`
-- (layer 'character') commands: removes what was set for a permission of the targeted players
-- or of their active characters, for good or temporarily, and notifies the players and
-- staff. An ID that is not registered on the server is accepted as well if one of them has a
-- value set for it, which is the case for a permission of a plugin that is not loaded on the
-- server. As with granting, callers can only reset a permission they have, and only root
-- players their own permissions.
-- @param cmd [Command the subcommand that runs]
-- @param layer_id [String 'user' or 'character']
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose permission, or whose characters' permission, is
--   reset]
-- @param permission_id [String permission ID, command ID or command alias]
function Bolt:reset_command_permission(cmd, layer_id, actor, targets, permission_id)
  local layer = command_layers[layer_id]
  local permission = self:find_permission(permission_id)
  local id = permission and permission.id or tostring(permission_id)

  if !self:check_permission_value(actor, id) then return end

  targets = self:get_permission_targets(actor, targets)

  if #targets == 0 then return end

  local entries = layer.entries(actor, targets)

  if #entries == 0 then return end

  local notification = 'notification.'..layer.notification..'.reset'
  local affected = {}

  for _, entry in ipairs(entries) do
    if layer.has_value(entry, id) then
      layer.reset(entry, id)

      entry.target:notify(notification, { permission = id })

      affected[#affected + 1] = entry
    end
  end

  if #affected == 0 then
    Flux.Player:notify(actor, permission ? layer.not_set : 'error.permission_not_valid', { permission = id })

    return
  end

  cmd:notify_staff('command.'..layer.command..'.reset.message', {
    player = get_player_name(actor),
    [layer.subject] = layer.join(affected),
    permission = id
  })
end

--- Tells the caller of a `list` subcommand of the `permission` and `charpermission` commands
-- which permissions a layer allows and denies for good, with one notification each, using the
-- `<prefix>.allowed` and `<prefix>.denied` phrases.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param prefix [String phrase prefix, such as 'command.permission.list']
-- @param subject [String placeholder that names the player or the character]
-- @param name [String name of the player or the character]
-- @param perm_table [Map PERM_ values keyed by permission ID]
-- @return [Number how many permissions were listed]
function Bolt:list_permission_values(actor, prefix, subject, name, perm_table)
  local allowed, denied = {}, {}

  for perm_id, value in SortedPairs(perm_table) do
    if value == PERM_ALLOW then
      allowed[#allowed + 1] = perm_id
    elseif value == PERM_NEVER then
      denied[#denied + 1] = perm_id
    end
  end

  if #allowed > 0 then
    Flux.Player:notify(actor, prefix..'.allowed', { [subject] = name, permissions = table.concat(allowed, ', ') })
  end

  if #denied > 0 then
    Flux.Player:notify(actor, prefix..'.denied', { [subject] = name, permissions = table.concat(denied, ', ') })
  end

  return #allowed + #denied
end

--- Tells the caller of a `list` subcommand of the `permission` and `charpermission` commands
-- every unexpired temporary permission of a layer with the time it has left, with one
-- notification each, using the `<prefix>.temporary_allowed` and `<prefix>.temporary_denied`
-- phrases.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param prefix [String phrase prefix, such as 'command.permission.list']
-- @param subject [String placeholder that names the player or the character]
-- @param name [String name of the player or the character]
-- @param temp_table [Map tables with value and expires (unix timestamp) fields, keyed by
--   permission ID]
-- @return [Number how many permissions were listed]
function Bolt:list_temp_permission_values(actor, prefix, subject, name, temp_table)
  local now = os.time()
  local count = 0

  for perm_id, entry in SortedPairs(temp_table) do
    local time_left = (tonumber(entry.expires) or 0) - now

    if time_left > 0 and (entry.value == PERM_ALLOW or entry.value == PERM_NEVER) then
      count += 1

      Flux.Player:notify(actor, prefix..(entry.value == PERM_ALLOW ? '.temporary_allowed' : '.temporary_denied'), {
        [subject] = name,
        permission = perm_id,
        time = Flux.Lang:duration(time_left)
      })
    end
  end

  return count
end

--- Finds the permission that an argument of the `grant` and `revoke` subcommands of the
-- `permission` and `charpermission` commands names, as Bolt:find_permission does, and tells
-- the caller if there is none.
-- @param actor [Player the caller, or an invalid entity for the server console]
-- @param text [String permission ID, command ID or command alias]
-- @return [Map permission data, or nil if there is no such permission]
function Bolt:find_command_permission(actor, text)
  local permission = self:find_permission(text)

  if !permission then
    Flux.Player:notify(actor, 'error.permission_not_valid', { permission = tostring(text) })
  end

  return permission
end

--- Reads the optional duration of the `grant` and `revoke` subcommands of the `permission`
-- and `charpermission` commands, which makes the permission they set a temporary one. An
-- empty text or a word for a permanent duration, such as 'perma', sets it for good. The
-- caller is told if the text is not a duration.
-- @param actor [Player the caller, or an invalid entity for the server console]
-- @param text [String duration as read by Bolt:interpret_ban_time, or an empty string]
-- @return [Boolean false if the text is neither empty nor a duration, true otherwise,
--   Number duration in seconds; nil if the permission is set for good]
function Bolt:read_permission_duration(actor, text)
  if text == '' or self:is_permanent_time(text) then
    return true
  end

  local duration = self:interpret_ban_time(text)

  if !self:is_temp_duration(duration) then
    Flux.Player:notify(actor, 'error.invalid_time', { time = text })

    return false
  end

  return true, duration
end

--- Brings what a player knows about the configs in line with what they may see: sends them
-- the config again if their right to edit configs has changed since it was last sent, so
-- that private and pending values reach a new editor and are forgotten by a former one.
-- Called whenever the role or a permission of a player changes. Does nothing before the
-- player has received the config for the first time.
-- @param target [Player]
function Bolt:update_config_access(target)
  if !IsValid(target) or !target.fl_has_sent_config then return end

  local can_manage = Config.can_manage(target)

  if target.bolt_config_access != can_manage then
    target.bolt_config_access = can_manage

    target:send_config()
  end
end
