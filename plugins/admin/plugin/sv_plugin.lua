--- Server side of the admin plugin: removal of temporary permissions, and the network
-- receivers behind the admin panel, which set a player's role, permissions and temporary
-- permissions, remove temporary permissions, change and reset config values, and disable
-- and enable plugins. Every receiver checks the sender's own permission and the values it
-- was sent; the ones that edit a player also check the sender's immunity against that
-- player, the way the SetGroup and Demote commands do.
--
-- The receivers of the ban list and of the staff page are in sv_bans.lua and sv_staff.lua.

--- Returns the name of a plugin the loader knows of, loaded or not, for the notifications
-- of the plugin manager.
-- @param id [String normalized plugin ID]
-- @return [String the name from `Plugin.known`, or the ID when no plugin has it]
local function known_plugin_name(id)
  for k, v in ipairs(Plugin.known()) do
    if v.id == id then
      return v.name
    end
  end

  return id
end

--- Checks a request of the admin panel to edit a player's role or permissions. The sender
-- needs the 'manage_permissions' permission and a role with a higher immunity than the
-- target's; an equal immunity is not enough, as for the SetGroup and Demote commands. Senders
-- may always edit themselves, and root players anyone. A sender who fails the immunity check
-- is notified.
-- @param actor [Player the player who sent the request]
-- @param target [Any the value received as the player to edit]
-- @return [Boolean true if target is a player with a loaded record whom the sender may edit]
local function can_manage_player(actor, target)
  if !actor:can('manage_permissions') then return false end
  if !isentity(target) or !IsValid(target) or !target:IsPlayer() or !target.record then return false end

  if !Bolt:check_immunity(actor, target) then
    actor:notify('error.command.higher_immunity', { target = get_player_name(target) })

    return false
  end

  return true
end

--- Checks that a value received from a client is one of the three permission values.
-- @param value [Any]
-- @return [Boolean true for PERM_ALLOW, PERM_NO and PERM_NEVER]
local function is_permission_value(value)
  return value == PERM_ALLOW or value == PERM_NO or value == PERM_NEVER
end

--- Checks that a value received from a client can be a permission ID. The ID does not have
-- to be registered on the server, because a permission may only exist on the client (such as
-- 'admin_esp').
-- @param perm_id [Any]
-- @return [Boolean true for a non-empty string]
local function is_permission_id(perm_id)
  return isstring(perm_id) and perm_id != ''
end

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
end

--- Finds the permission that an argument of the Grant, Revoke or ResetPermission command
-- names, as Bolt:find_permission does, and tells the caller if there is none.
-- @param actor [Player the caller, or an invalid entity for the server console]
-- @param text [String permission ID, command name or command alias]
-- @return [Map permission data, or nil if there is no such permission]
function Bolt:find_command_permission(actor, text)
  local permission = self:find_permission(text)

  if !permission then
    Flux.Player:notify(actor, 'error.permission_not_valid', { permission = tostring(text) })
  end

  return permission
end

--- Reads the optional duration of the Grant and Revoke commands, which makes the permission
-- they set a temporary one. The caller is told if the text is not a duration.
-- @param actor [Player the caller, or an invalid entity for the server console]
-- @param text [String duration as read by Bolt:interpret_ban_time, or an empty string]
-- @return [Boolean false if the text is neither empty nor a duration, Number duration in
--   seconds; nil if the text is empty]
function Bolt:read_permission_duration(actor, text)
  if text == '' then
    return true
  end

  local duration = self:interpret_ban_time(text)

  if !isnumber(duration) or duration != duration or duration <= 0 or duration == math.huge then
    Flux.Player:notify(actor, 'error.invalid_time', { time = text })

    return false
  end

  return true, duration
end

Cable.receive('fl_bolt_set_role', function(actor, target, role_id)
  if !can_manage_player(actor, target) then return end
  if !isstring(role_id) or !Bolt:group_exists(role_id) then return end

  target:SetUserGroup(role_id)

  Command:notify_staff('command.setgroup.message', {
    player = get_player_name(actor),
    target = target:steam_name(true),
    group = role_id
  })
end)

Cable.receive('fl_bolt_set_permission', function(actor, target, perm_id, value)
  if !can_manage_player(actor, target) then return end
  if !is_permission_id(perm_id) or !is_permission_value(value) then return end

  target:set_permission(perm_id, value)
end)

Cable.receive('fl_temp_permission', function(actor, target, perm_id, value, duration)
  if !can_manage_player(actor, target) then return end
  if !is_permission_id(perm_id) or !is_permission_value(value) then return end
  if !isnumber(duration) or duration != duration or duration <= 0 or duration == math.huge then return end

  target:set_temp_permission(perm_id, value, duration)
end)

Cable.receive('fl_delete_temp_permission', function(actor, target, perm_id)
  if !can_manage_player(actor, target) or !is_permission_id(perm_id) then return end

  Bolt:delete_temp_permission(target, perm_id)
end)

--- Checks whether two config values are the same. Lists are compared by their contents.
-- @param first [Any]
-- @param second [Any]
-- @return [Boolean]
local function config_values_equal(first, second)
  return first == second or (istable(first) and istable(second) and table.equal(first, second))
end

--- Finds the config that a request of the config editor is about, if its sender may edit
-- it: they need the permission to edit configs, and the config has to exist and must not
-- be hidden, since the editor never lists hidden configs.
-- @param actor [Player the player who sent the request]
-- @param key [Any the value received as the config key]
-- @return [Map the stored config, or nil if the request is to be ignored]
local function editable_config(actor, key)
  if !Config.can_manage(actor) or !isstring(key) then return end

  local entry = Config.find(key)

  if entry and !entry.hidden then
    return entry
  end
end

--- Tells staff that a player has changed a config. The value is shown the way
-- Config.display_value writes it, which masks private configs, and a change that waits for
-- a restart is announced as such. Percent signs in the value are doubled: it is a phrase
-- argument, and `t` would read a single one as the start of a capture reference.
-- @param actor [Player the player who made the change]
-- @param key [String config key]
-- @param value [Any the value as it was stored]
-- @param pending [Boolean true if the value only takes effect after a restart]
local function announce_config_change(actor, key, value, pending)
  local definition = Config.get_definition(key)

  Command:notify_staff(pending and 'notification.config_changed_restart' or 'notification.config_changed', {
    player = get_player_name(actor),
    config = definition and definition.name or key,
    value = Config.display_value(key, value)
  })
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

Cable.receive('fl_config_change', function(actor, key, value)
  if !editable_config(actor, key) then return end

  local old_value = Config.get(key)
  local had_pending = Config.get_pending(key)
  local success, result, pending = Config.change(key, value)

  if !success then
    actor:notify(result)

    return
  end

  if pending or had_pending or !config_values_equal(old_value, result) then
    announce_config_change(actor, key, result, pending)
  end
end)

Cable.receive('fl_config_reset', function(actor, key)
  if !editable_config(actor, key) then return end

  local old_value = Config.get(key)
  local had_pending = Config.get_pending(key)
  local success, result, pending = Config.reset(key)

  if !success then
    actor:notify(result)

    return
  end

  if pending or had_pending or !config_values_equal(old_value, result) then
    announce_config_change(actor, key, result, pending)
  end
end)

Cable.receive('fl_bolt_plugin_set_disabled', function(actor, id, disabled, force)
  if !actor:can('manage_plugins') then return end
  if !isstring(id) or !isbool(disabled) then return end

  id = Plugin.normalize_id(id)

  if !id then return end

  if disabled and id == Plugin.normalize_id(Bolt:get_path()) then
    actor:notify('error.plugin.admin')

    return
  end

  if Plugin.disabled_on_restart(id) == disabled then return end

  local name = known_plugin_name(id)
  local success, phrase, dependents = Plugin.set_disabled(id, disabled, force == true)

  if !success then
    actor:notify(phrase, { plugins = table.concat(dependents or {}, ', ') })

    return
  end

  Command:notify_staff(disabled and 'notification.plugin_disabled' or 'notification.plugin_enabled', {
    player = get_player_name(actor),
    plugin = name
  })
end)
