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
-- A permission is named by its ID or by the ID or an alias of the command it belongs to,
-- exactly but in any case.

CMD.name = 'CharPermission'
CMD.description = 'command.charpermission.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'charperm', 'charperms', 'charpermissions' }

--- Returns the targeted players who have a character loaded, with their characters, and
-- tells the caller when none of them has.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player>]
-- @return [List<Map> tables with the player (target), the character (character) and the
--   name of the character followed by the Steam name of the player (label)]
local function loaded_characters(actor, targets)
  local result = {}

  for _, target in ipairs(targets) do
    local character = Bolt:get_active_character(target)

    if character then
      table.insert(result, {
        target = target,
        character = character,
        label = Bolt:get_character_label(target, character)
      })
    end
  end

  if #result == 0 then
    Flux.Player:notify(actor, 'error.character_permission.no_character')
  end

  return result
end

--- Sets a permission of the active characters of the targeted players, for good or
-- temporarily, notifies the players and staff. Callers can only set what they may do
-- themselves; the server console can set anything.
-- @param cmd [Command the subcommand that runs]
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose characters' permission is set]
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

  for _, entry in ipairs(loaded_characters(actor, targets)) do
    local success

    if duration then
      success = Bolt:set_character_temp_permission(entry.character, permission.id, value, duration)
    else
      success = Bolt:set_character_permission(entry.character, permission.id, value)
    end

    if success then
      entry.target:notify(granted ? 'notification.character_permission.granted' :
        'notification.character_permission.revoked', { permission = permission.id })

      table.insert(affected, entry.label)
    end
  end

  if #affected == 0 then return end

  local phrase = 'command.charpermission.'..(granted ? 'grant' : 'revoke')..'.message'

  cmd:notify_staff(duration and phrase..'_temporary' or phrase, {
    player = get_player_name(actor),
    character = table.concat(affected, ', '),
    permission = permission.id,
    time = duration and Flux.Lang:duration(duration) or nil
  })
end

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
  set_permission(self, actor, targets, permission_id, table.concat({ ... }, ' '), PERM_ALLOW)
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
  set_permission(self, actor, targets, permission_id, table.concat({ ... }, ' '), PERM_NEVER)
end

local reset = CMD:subcommand('reset')
reset.description = 'command.charpermission.reset.description'
reset.syntax = 'command.charpermission.reset.syntax'
reset.arguments = 2
reset.arg_types = { 'player', 'permission' }
reset.immunity = true

--- Resets the permission of the active characters of the targeted players and notifies them
-- and staff. An ID that is not registered on the server is accepted as well if one of the
-- characters has a value set for it.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose characters' permission is reset]
-- @param permission_id [String permission ID, command ID or command alias]
function reset:on_run(actor, targets, permission_id)
  local permission = Bolt:find_permission(permission_id)
  local id = permission and permission.id or tostring(permission_id)
  local affected = {}
  local characters = loaded_characters(actor, targets)

  if #characters == 0 then return end

  for _, entry in ipairs(characters) do
    local character = entry.character
    local has_value = Bolt:get_character_permissions(character)[id] != nil or
      Bolt:get_character_temp_permissions(character)[id] != nil

    if has_value then
      Bolt:set_character_permission(character, id, PERM_NO)
      Bolt:delete_character_temp_permission(character, id)

      entry.target:notify('notification.character_permission.reset', { permission = id })

      table.insert(affected, entry.label)
    end
  end

  if #affected == 0 then
    Flux.Player:notify(actor, permission ? 'error.character_permission.not_set' : 'error.permission_not_valid', {
      permission = id
    })

    return
  end

  self:notify_staff('command.charpermission.reset.message', {
    player = get_player_name(actor),
    character = table.concat(affected, ', '),
    permission = id
  })
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
  local entry = loaded_characters(actor, { targets[1] })[1]

  if !entry then return end

  local name = entry.label
  local character = entry.character
  local allowed, denied = {}, {}
  local temporary = 0

  for perm_id, value in SortedPairs(Bolt:get_character_permissions(character)) do
    if value == PERM_ALLOW then
      table.insert(allowed, perm_id)
    elseif value == PERM_NEVER then
      table.insert(denied, perm_id)
    end
  end

  if #allowed > 0 then
    Flux.Player:notify(actor, 'command.charpermission.list.allowed', {
      character = name,
      permissions = table.concat(allowed, ', ')
    })
  end

  if #denied > 0 then
    Flux.Player:notify(actor, 'command.charpermission.list.denied', {
      character = name,
      permissions = table.concat(denied, ', ')
    })
  end

  for perm_id, temp_entry in SortedPairs(Bolt:get_character_temp_permissions(character)) do
    local time_left = (tonumber(temp_entry.expires) or 0) - os.time()

    if time_left > 0 and (temp_entry.value == PERM_ALLOW or temp_entry.value == PERM_NEVER) then
      temporary += 1

      local phrase = temp_entry.value == PERM_ALLOW ? 'temporary_allowed' : 'temporary_denied'

      Flux.Player:notify(actor, 'command.charpermission.list.'..phrase, {
        character = name,
        permission = perm_id,
        time = Flux.Lang:duration(time_left)
      })
    end
  end

  if #allowed == 0 and #denied == 0 and temporary == 0 then
    Flux.Player:notify(actor, 'command.charpermission.list.none', { character = name })
  end
end
