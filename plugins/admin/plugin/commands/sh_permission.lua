--- The Permission command manages the permissions that players have of their own, on top of
-- what their role allows. Every subcommand needs the `permission` permission.
-- `/permission grant <target> <permission> [duration]` allows a permission for the targeted
-- players whatever their role says: it sets the permission to `PERM_ALLOW`, as the Allow
-- button of the permission editor does. `/permission revoke <target> <permission> [duration]`
-- denies it the same way with `PERM_NEVER`, as the Revoke button does. With a duration the
-- permission is set temporarily. `/permission reset <target> <permission>` removes what was set
-- for the targeted players, for good or temporarily, so that their role decides again: it sets
-- the permission to `PERM_NO`, as the middle button does. `/permission list <target>` tells
-- the caller the role of a player, the permissions set for them individually and those that
-- their loaded character decides.
--
-- A permission is named by its ID or by the ID or an alias of the command it belongs to,
-- exactly but in any case.

CMD.name = 'Permission'
CMD.description = 'command.permission.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'perm', 'perms', 'permissions' }

--- Sets a permission of the targeted players, for good or temporarily, notifies them and
-- staff. Callers can only set what they may do themselves; the server console can set
-- anything.
-- @param cmd [Command the subcommand that runs]
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose permission is set]
-- @param permission_id [String permission ID, command ID or command alias]
-- @param duration_text [String duration as read by Bolt:interpret_ban_time, empty or a
--   permanent word such as 'perma' to set it for good]
-- @param value [Number PERM_ALLOW or PERM_NEVER]
local function set_permission(cmd, actor, targets, permission_id, duration_text, value)
  local permission = Bolt:find_command_permission(actor, permission_id)

  if !permission then return end

  if IsValid(actor) and !actor:can(permission.id) then
    actor:notify('error.permission_not_yours', { permission = permission.id })

    return
  end

  local valid, duration = Bolt:read_permission_duration(actor, duration_text)

  if !valid then return end

  local granted = value == PERM_ALLOW
  local affected = {}

  for _, target in ipairs(targets) do
    if target.record then
      if duration then
        target:set_temp_permission(permission.id, value, duration)
      else
        target:set_permission(permission.id, value)
      end

      target:notify(granted ? 'notification.permission.granted' : 'notification.permission.revoked', {
        permission = permission.id
      })

      table.insert(affected, target)
    end
  end

  if #affected == 0 then return end

  local phrase = 'command.permission.'..(granted ? 'grant' : 'revoke')..'.message'

  cmd:notify_staff(duration and phrase..'_temporary' or phrase, {
    player = get_player_name(actor),
    target = util.player_list_to_string(affected),
    permission = permission.id,
    time = duration and Flux.Lang:duration(duration) or nil
  })
end

local grant = CMD:subcommand('grant')
grant.description = 'command.permission.grant.description'
grant.syntax = 'command.permission.grant.syntax'
grant.arguments = 2
grant.arg_types = { 'player', 'permission', 'duration' }
grant.immunity = true

--- Allows the permission for the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to grant the permission to]
-- @param permission_id [String permission ID, command ID or command alias]
-- @param ... [Vararg words of an optional duration as read by Bolt:interpret_ban_time, e.g.
--   '2 hours'; the permission is granted for good without one]
function grant:on_run(actor, targets, permission_id, ...)
  set_permission(self, actor, targets, permission_id, table.concat({ ... }, ' '), PERM_ALLOW)
end

local revoke = CMD:subcommand('revoke')
revoke.description = 'command.permission.revoke.description'
revoke.syntax = 'command.permission.revoke.syntax'
revoke.arguments = 2
revoke.arg_types = { 'player', 'permission', 'duration' }
revoke.immunity = true

--- Denies the permission to the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to deny the permission to]
-- @param permission_id [String permission ID, command ID or command alias]
-- @param ... [Vararg words of an optional duration as read by Bolt:interpret_ban_time, e.g.
--   '2 hours'; the permission is denied for good without one]
function revoke:on_run(actor, targets, permission_id, ...)
  set_permission(self, actor, targets, permission_id, table.concat({ ... }, ' '), PERM_NEVER)
end

local reset = CMD:subcommand('reset')
reset.description = 'command.permission.reset.description'
reset.syntax = 'command.permission.reset.syntax'
reset.arguments = 2
reset.arg_types = { 'player', 'permission' }
reset.immunity = true

local function has_own_value(target, permission_id)
  return target:get_permission(permission_id) != PERM_NO or target:get_temp_permission(permission_id) != nil
end

--- Resets the permission of the targeted players and notifies them and staff. An ID that is
-- not registered on the server is accepted as well if one of the targets has a value set for
-- it, which is the case for the permissions that only exist on the client, such as
-- 'admin_esp', once they were set in the permission editor.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose permission is reset]
-- @param permission_id [String permission ID, command ID or command alias]
function reset:on_run(actor, targets, permission_id)
  local permission = Bolt:find_permission(permission_id)
  local id = permission and permission.id or tostring(permission_id)
  local affected = {}

  for _, client in ipairs(targets) do
    if client.record and has_own_value(client, id) then
      client:set_permission(id, PERM_NO)

      Bolt:delete_temp_permission(client, id)

      client:notify('notification.permission.reset', { permission = id })

      table.insert(affected, client)
    end
  end

  if #affected == 0 then
    Flux.Player:notify(actor, permission ? 'error.permission_not_set' : 'error.permission_not_valid', {
      permission = id
    })

    return
  end

  self:notify_staff('command.permission.reset.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(affected),
    permission = id
  })
end

local list_cmd = CMD:subcommand('list')
list_cmd.description = 'command.permission.list.description'
list_cmd.syntax = 'command.permission.list.syntax'
list_cmd.arguments = 1
list_cmd.arg_types = { 'player' }

--- Sends the caller the role of the targeted player and the permissions set for that player
-- individually, as one notification per kind of permission, and one for every temporary
-- permission with the time it has left. The permissions that the loaded character of the
-- player decides, see `Bolt:get_permission_layer`, are listed as well. Only the first of
-- several targeted players is listed.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> targeted players; only the first one is used]
function list_cmd:on_run(actor, targets)
  local target = targets[1]

  if !IsValid(target) then return end

  local name = get_player_name(target)
  local allowed, denied = {}, {}
  local temporary = 0

  for perm_id, value in SortedPairs(target:get_permissions()) do
    if value == PERM_ALLOW then
      table.insert(allowed, perm_id)
    elseif value == PERM_NEVER then
      table.insert(denied, perm_id)
    end
  end

  Flux.Player:notify(actor, 'command.permission.list.role', {
    target = name,
    role = target:GetUserGroup()
  })

  if #allowed > 0 then
    Flux.Player:notify(actor, 'command.permission.list.allowed', {
      target = name,
      permissions = table.concat(allowed, ', ')
    })
  end

  if #denied > 0 then
    Flux.Player:notify(actor, 'command.permission.list.denied', {
      target = name,
      permissions = table.concat(denied, ', ')
    })
  end

  local character = Bolt:get_active_character(target)

  if character then
    local label = Bolt:get_character_label(target, character)
    local character_ids = {}
    local char_allowed, char_denied = {}, {}

    for _, perm_table in ipairs({ target:get_character_permissions(), target:get_character_temp_permissions() }) do
      for perm_id in pairs(perm_table) do
        character_ids[perm_id] = true
      end
    end

    for perm_id in SortedPairs(character_ids) do
      local is_allowed, layer = Bolt:get_permission_layer(target, perm_id)

      if layer == 'character' or layer == 'character_temporary' then
        table.insert(is_allowed and char_allowed or char_denied, perm_id)
      end
    end

    if #char_allowed > 0 then
      Flux.Player:notify(actor, 'command.permission.list.character_allowed', {
        character = label,
        permissions = table.concat(char_allowed, ', ')
      })
    end

    if #char_denied > 0 then
      Flux.Player:notify(actor, 'command.permission.list.character_denied', {
        character = label,
        permissions = table.concat(char_denied, ', ')
      })
    end
  end

  for perm_id, entry in SortedPairs(target:get_temp_permissions()) do
    local time_left = (tonumber(entry.expires) or 0) - os.time()

    if time_left > 0 and (entry.value == PERM_ALLOW or entry.value == PERM_NEVER) then
      temporary += 1

      local phrase = entry.value == PERM_ALLOW ? 'temporary_allowed' : 'temporary_denied'

      Flux.Player:notify(actor, 'command.permission.list.'..phrase, {
        target = name,
        permission = perm_id,
        time = Flux.Lang:duration(time_left)
      })
    end
  end

  if #allowed == 0 and #denied == 0 and temporary == 0 then
    Flux.Player:notify(actor, 'command.permission.list.none', { target = name })
  end
end
