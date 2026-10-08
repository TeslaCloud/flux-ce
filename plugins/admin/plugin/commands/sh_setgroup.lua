--- The SetGroup command sets the role of the targeted players to the role with the given
-- ID. By default only administrators can use it.

CMD.name = 'SetGroup'
CMD.description = 'command.setgroup.description'
CMD.syntax = 'command.setgroup.syntax'
CMD.permission = 'administrator'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.immunity = true
CMD.aliases = { 'plysetgroup', 'setusergroup', 'plysetusergroup' }

--- Returns the translated command description with the list of existing role IDs filled in.
-- @return [String]
function CMD:get_description()
  local groups = {}

  for k, v in pairs(Bolt:get_roles()) do
    table.insert(groups, k)
  end

  return t(self.description, { groups = table.concat(groups, ', ') })
end

--- Sets the role of the targeted players and notifies them and staff, or tells the caller that
-- the role does not exist.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose role is set]
-- @param role [String role ID]
function CMD:on_run(actor, targets, role)
  if Bolt:group_exists(role) then
    for k, v in ipairs(targets) do
      v:notify('notification.setgroup', {
        group = role
      })
      v:SetUserGroup(role)
    end

    self:notify_staff('command.setgroup.message', {
      player = get_player_name(actor),
      target = util.player_list_to_string(targets),
      group = role
    })
  else
    actor:notify('error.group_not_valid', { group = role })
  end
end
