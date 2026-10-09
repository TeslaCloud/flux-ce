--- The Permissions command tells its caller which permissions a player has of their own, on
-- top of what their role allows: the ones that were granted or revoked for them
-- individually, and their temporary permissions with the time each has left. By default
-- only administrators can use it.

CMD.name = 'Permissions'
CMD.description = 'command.permissions.description'
CMD.syntax = 'command.permissions.syntax'
CMD.permission = 'admin'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 1
CMD.player_arg = 1
CMD.aliases = { 'perms', 'plypermissions', 'listaccess' }

--- Sends the caller the role of the targeted player and the permissions set for that player
-- individually, as one notification per kind of permission. Only the first of several
-- matched players is listed.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> matched players; only the first one is used]
function CMD:on_run(actor, targets)
  local target = targets[1]

  if !IsValid(target) then return end

  local name = get_player_name(target)
  local allowed, denied = {}, {}
  local temporary = 0

  for k, v in SortedPairs(target:get_permissions()) do
    if v == PERM_ALLOW then
      table.insert(allowed, k)
    elseif v == PERM_NEVER then
      table.insert(denied, k)
    end
  end

  Flux.Player:notify(actor, 'command.permissions.role', {
    target = name,
    role = target:GetUserGroup()
  })

  if #allowed > 0 then
    Flux.Player:notify(actor, 'command.permissions.allowed', {
      target = name,
      permissions = table.concat(allowed, ', ')
    })
  end

  if #denied > 0 then
    Flux.Player:notify(actor, 'command.permissions.denied', {
      target = name,
      permissions = table.concat(denied, ', ')
    })
  end

  for k, v in SortedPairs(target:get_temp_permissions()) do
    local time_left = (tonumber(v.expires) or 0) - os.time()

    if time_left > 0 and (v.value == PERM_ALLOW or v.value == PERM_NEVER) then
      temporary = temporary + 1

      Flux.Player:notify(
        actor,
        v.value == PERM_ALLOW and 'command.permissions.temporary_allowed' or 'command.permissions.temporary_denied',
        { target = name, permission = k, time = Flux.Lang:duration(time_left) }
      )
    end
  end

  if #allowed == 0 and #denied == 0 and temporary == 0 then
    Flux.Player:notify(actor, 'command.permissions.none', { target = name })
  end
end
