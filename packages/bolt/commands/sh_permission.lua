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
-- Callers can only grant, revoke or reset a permission they have themselves, and only root
-- players can change their own permissions; the server console can change anything.
--
-- A permission is named by its ID or by the ID or an alias of the command it belongs to,
-- exactly but in any case.

CMD.name = 'Permission'
CMD.description = 'command.permission.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'perm', 'perms', 'permissions' }

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
  Bolt:set_command_permission(self, 'user', actor, targets, permission_id, table.concat({ ... }, ' '), PERM_ALLOW)
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
  Bolt:set_command_permission(self, 'user', actor, targets, permission_id, table.concat({ ... }, ' '), PERM_NEVER)
end

local reset = CMD:subcommand('reset')
reset.description = 'command.permission.reset.description'
reset.syntax = 'command.permission.reset.syntax'
reset.arguments = 2
reset.arg_types = { 'player', 'permission' }
reset.immunity = true

--- Resets the permission of the targeted players and notifies them and staff, see
-- `Bolt:reset_command_permission`.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose permission is reset]
-- @param permission_id [String permission ID, command ID or command alias]
function reset:on_run(actor, targets, permission_id)
  Bolt:reset_command_permission(self, 'user', actor, targets, permission_id)
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

  Flux.Player:notify(actor, 'command.permission.list.role', {
    target = name,
    role = target:get_role()
  })

  local listed = Bolt:list_permission_values(actor, 'command.permission.list', 'target', name,
    target:get_permissions())

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

  listed += Bolt:list_temp_permission_values(actor, 'command.permission.list', 'target', name,
    target:get_temp_permissions())

  if listed == 0 then
    Flux.Player:notify(actor, 'command.permission.list.none', { target = name })
  end
end
