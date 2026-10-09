--- The Revoke command denies a permission to the targeted players individually, whatever
-- their role says: it sets the permission to `PERM_NEVER`, as the Revoke button of the
-- permission editor does. With a duration the permission is denied temporarily. Use
-- ResetPermission to let the role of a player decide again. By default only administrators
-- can use it.

CMD.name = 'Revoke'
CMD.description = 'command.revoke.description'
CMD.syntax = 'command.revoke.syntax'
CMD.permission = 'admin'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'plyrevoke', 'takeaccess', 'plytakeaccess' }

--- Denies the permission to the targeted players and notifies them and staff. The permission
-- is named by its ID or by the name or an alias of the command it belongs to.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to deny the permission to]
-- @param permission_id [String permission ID, command name or command alias]
-- @param ... [Vararg words of an optional duration as read by Bolt:interpret_ban_time, e.g.
--   '2 hours'; the permission is denied for good without one]
function CMD:on_run(actor, targets, permission_id, ...)
  local permission = Bolt:find_command_permission(actor, permission_id)

  if !permission then return end

  local valid, duration = Bolt:read_permission_duration(actor, table.concat({ ... }, ' '))

  if !valid then return end

  local affected = {}

  for k, v in ipairs(targets) do
    if v.record then
      if duration then
        v:set_temp_permission(permission.id, PERM_NEVER, duration)
      else
        v:set_permission(permission.id, PERM_NEVER)
      end

      v:notify('notification.permission.revoked', { permission = permission.id })

      table.insert(affected, v)
    end
  end

  if #affected == 0 then return end

  self:notify_staff(duration and 'command.revoke.message_temporary' or 'command.revoke.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(affected),
    permission = permission.id,
    time = duration and Flux.Lang:duration(duration) or nil
  })
end
