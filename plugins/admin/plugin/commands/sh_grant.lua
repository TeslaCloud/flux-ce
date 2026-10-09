--- The Grant command allows a permission for the targeted players individually, whatever
-- their role says: it sets the permission to `PERM_ALLOW`, as the Allow button of the
-- permission editor does. With a duration the permission is granted temporarily. By default
-- only administrators can use it.

CMD.name = 'Grant'
CMD.description = 'command.grant.description'
CMD.syntax = 'command.grant.syntax'
CMD.permission = 'admin'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'plygrant', 'giveaccess', 'plygiveaccess' }

--- Grants the permission to the targeted players and notifies them and staff. The permission
-- is named by its ID or by the name or an alias of the command it belongs to. Callers can
-- only grant what they may do themselves; the server console can grant anything.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to grant the permission to]
-- @param permission_id [String permission ID, command name or command alias]
-- @param ... [Vararg words of an optional duration as read by Bolt:interpret_ban_time, e.g.
--   '2 hours'; the permission is granted for good without one]
function CMD:on_run(actor, targets, permission_id, ...)
  local permission = Bolt:find_command_permission(actor, permission_id)

  if !permission then return end

  if IsValid(actor) and !actor:can(permission.id) then
    actor:notify('error.permission_not_yours', { permission = permission.id })

    return
  end

  local valid, duration = Bolt:read_permission_duration(actor, table.concat({ ... }, ' '))

  if !valid then return end

  local affected = {}

  for k, v in ipairs(targets) do
    if v.record then
      if duration then
        v:set_temp_permission(permission.id, PERM_ALLOW, duration)
      else
        v:set_permission(permission.id, PERM_ALLOW)
      end

      v:notify('notification.permission.granted', { permission = permission.id })

      table.insert(affected, v)
    end
  end

  if #affected == 0 then return end

  self:notify_staff(duration and 'command.grant.message_temporary' or 'command.grant.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(affected),
    permission = permission.id,
    time = duration and Flux.Lang:duration(duration) or nil
  })
end
