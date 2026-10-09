--- The ResetPermission command removes what was set for the targeted players individually
-- for a permission, be it for good or temporarily, so that their role decides again: it
-- sets the permission to `PERM_NO`, as the middle button of the permission editor does. It
-- undoes both Grant and Revoke. By default only administrators can use it.

CMD.name = 'ResetPermission'
CMD.description = 'command.resetpermission.description'
CMD.syntax = 'command.resetpermission.syntax'
CMD.permission = 'admin'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'permreset', 'unsetpermission', 'plyresetpermission' }

--- Checks whether a player has a value of their own for a permission, lasting or temporary.
-- @param target [Player]
-- @param permission_id [String permission ID]
-- @return [Boolean]
local function has_own_value(target, permission_id)
  return target:get_permission(permission_id) != PERM_NO or target:get_temp_permission(permission_id) != nil
end

--- Resets the permission of the targeted players and notifies them and staff. The permission
-- is named by its ID or by the name or an alias of the command it belongs to. An ID that is
-- not registered on the server is accepted as well if one of the targets has a value set
-- for it, which is the case for the permissions that only exist on the client, such as
-- 'admin_esp', once they were set in the permission editor.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose permission is reset]
-- @param permission_id [String permission ID, command name or command alias]
function CMD:on_run(actor, targets, permission_id)
  local permission = Bolt:find_permission(permission_id)
  local id = permission and permission.id or tostring(permission_id)
  local affected = {}

  for k, v in ipairs(targets) do
    if v.record and has_own_value(v, id) then
      v:set_permission(id, PERM_NO)

      Bolt:delete_temp_permission(v, id)

      v:notify('notification.permission.reset', { permission = id })

      table.insert(affected, v)
    end
  end

  if #affected == 0 then
    Flux.Player:notify(actor, permission and 'error.permission_not_set' or 'error.permission_not_valid', {
      permission = id
    })

    return
  end

  self:notify_staff('command.resetpermission.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(affected),
    permission = id
  })
end
