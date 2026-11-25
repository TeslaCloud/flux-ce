--- The CharPermission command manages the permissions of the characters that players have
-- loaded. While a character is loaded, its permissions apply together with those of its
-- player, before the player's role, see `Bolt:get_permission_layer`; the player's other
-- characters do not have them. Every subcommand needs the `charpermission` permission and
-- works on the active character of each targeted player.
-- `/charpermission grant <target> <permission> [duration]` allows a permission for the
-- character whatever the player's role says, unless the player is denied it: it sets the
-- permission to `PERM_ALLOW`. `/charpermission revoke <target> <permission> [duration]` denies
-- it to the character whatever the player and their role say, with `PERM_NEVER`. With a
-- duration the permission is set temporarily, for at most `Bolt.max_temp_duration`.
-- `/charpermission reset <target> <permission>` removes what was set for the character, for
-- good or temporarily, so that the player's own permissions and role decide again.
-- `/charpermission list <target>` tells the caller the permissions set for the character.
--
-- Callers can only grant, revoke or reset a permission they have themselves, and only root
-- players can change the permissions of their own character; the server console can change
-- anything.
--
-- A permission is named by its ID or by the ID or an alias of the command it belongs to,
-- exactly but in any case.

CMD.name = 'CharPermission'
CMD.description = 'command.charpermission.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'charperm', 'charperms', 'charpermissions' }

local grant = CMD:subcommand('grant')
grant.description = 'command.charpermission.grant.description'
grant.syntax = 'command.charpermission.grant.syntax'
grant.arguments = 2
grant.arg_types = { 'player', 'permission', 'duration' }
grant.immunity = true

--- Allows the permission for the active characters of the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose characters get the permission]
-- @param permission_id [String permission ID, command ID or command alias]
-- @param ... [Vararg words of an optional duration as read by Bolt:interpret_ban_time, e.g.
--   '2 hours'; the permission is granted for good without one]
function grant:on_run(actor, targets, permission_id, ...)
  Bolt:set_command_permission(self, 'character', actor, targets, permission_id, table.concat({ ... }, ' '), PERM_ALLOW)
end

local revoke = CMD:subcommand('revoke')
revoke.description = 'command.charpermission.revoke.description'
revoke.syntax = 'command.charpermission.revoke.syntax'
revoke.arguments = 2
revoke.arg_types = { 'player', 'permission', 'duration' }
revoke.immunity = true

--- Denies the permission to the active characters of the targeted players.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose characters are denied the permission]
-- @param permission_id [String permission ID, command ID or command alias]
-- @param ... [Vararg words of an optional duration as read by Bolt:interpret_ban_time, e.g.
--   '2 hours'; the permission is denied for good without one]
function revoke:on_run(actor, targets, permission_id, ...)
  Bolt:set_command_permission(self, 'character', actor, targets, permission_id, table.concat({ ... }, ' '), PERM_NEVER)
end

local reset = CMD:subcommand('reset')
reset.description = 'command.charpermission.reset.description'
reset.syntax = 'command.charpermission.reset.syntax'
reset.arguments = 2
reset.arg_types = { 'player', 'permission' }
reset.immunity = true

--- Resets the permission of the active characters of the targeted players and notifies them
-- and staff, see `Bolt:reset_command_permission`.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose characters' permission is reset]
-- @param permission_id [String permission ID, command ID or command alias]
function reset:on_run(actor, targets, permission_id)
  Bolt:reset_command_permission(self, 'character', actor, targets, permission_id)
end

local list_cmd = CMD:subcommand('list')
list_cmd.description = 'command.charpermission.list.description'
list_cmd.syntax = 'command.charpermission.list.syntax'
list_cmd.arguments = 1
list_cmd.arg_types = { 'player' }

--- Sends the caller the permissions set for the active character of the targeted player, as
-- one notification per kind of permission, and one for every temporary permission with the
-- time it has left. Only the first of several targeted players is listed.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> targeted players; only the first one is used]
function list_cmd:on_run(actor, targets)
  local entry = Bolt:get_loaded_characters(actor, { targets[1] })[1]

  if !entry then return end

  local name = entry.label
  local character = entry.character
  local listed = Bolt:list_permission_values(actor, 'command.charpermission.list', 'character', name,
    Bolt:get_character_permissions(character))

  listed += Bolt:list_temp_permission_values(actor, 'command.charpermission.list', 'character', name,
    Bolt:get_character_temp_permissions(character))

  if listed == 0 then
    Flux.Player:notify(actor, 'command.charpermission.list.none', { character = name })
  end
end
