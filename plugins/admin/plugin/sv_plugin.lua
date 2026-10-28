--- Server side of the admin plugin: removal of temporary permissions, reading the
-- permission and duration arguments of the `permission` and `charpermission` commands, and
-- sending the config again to a player whose right to edit configs has changed.

--- Removes a temporary permission from a player, destroying its database record, taking it
-- off the player's record and updating the networked table. The config is sent to the player
-- again if that has changed their right to edit configs.
-- @param target [Player]
-- @param perm_id [String permission ID]
function Bolt:delete_temp_permission(target, perm_id)
  local records = target.record.temp_permissions

  if records then
    for i = #records, 1, -1 do
      if records[i].permission_id == perm_id then
        records[i]:destroy()

        table.remove(records, i)
      end
    end
  end

  local perm_table = target:get_temp_permissions()

  perm_table[perm_id] = nil

  target:set_temp_permissions(perm_table)

  self:update_config_access(target)
  target:update_hidden_players()
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
