--- The Role command sets and removes the roles of players. Both subcommands need the `role`
-- permission. `/role set <target> <role>` sets the role of the targeted players to a role,
-- named by its ID or its name, exactly but in any case. `/role remove <target or SteamID>` sets
-- the role of the targeted players back to `user`; given a SteamID that belongs to nobody on
-- the server, it changes the role that is stored for that SteamID instead, so that staff
-- members can be demoted while they are away.
--
-- `role remove` finds its targets itself instead of setting `immunity`, because the command
-- interpreter only knows the players who are on the server.

CMD.name = 'Role'
CMD.description = 'command.role.description'
CMD.category = 'permission.categories.player_management'
CMD.aliases = { 'group', 'usergroup' }

local set = CMD:subcommand('set')
set.description = 'command.role.set.description'
set.syntax = 'command.role.set.syntax'
set.arguments = 2
set.arg_types = { 'player', 'role' }
set.immunity = true

--- Returns the translated description of the subcommand with the list of existing role IDs
-- filled in.
-- @return [String]
function set:get_description()
  local ids = {}

  for id in SortedPairs(Bolt:get_roles()) do
    table.insert(ids, id)
  end

  return t(self.description, { groups = table.concat(ids, ', ') })
end

--- Sets the role of the targeted players and notifies them and staff, or tells the caller that
-- the role does not exist.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players whose role is set]
-- @param role_name [String role ID or role name]
function set:on_run(actor, targets, role_name)
  local role = Bolt:find_role(role_name)

  if !role then
    Flux.Player:notify(actor, 'error.group_not_valid', { group = tostring(role_name) })

    return
  end

  for _, v in ipairs(targets) do
    v:notify('notification.setgroup', {
      group = role.id
    })
    v:SetUserGroup(role.id)
  end

  self:notify_staff('command.role.set.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    group = role.id
  })
end

local remove = CMD:subcommand('remove')
remove.description = 'command.role.remove.description'
remove.syntax = 'command.role.remove.syntax'
remove.arguments = 1
remove.arg_types = { 'player' }
remove.player_arg = false

--- Demotes the targeted players, or the owner of a SteamID who is not on the server, to the
-- 'user' role and notifies them and staff. The caller needs a higher immunity than every
-- target; for a SteamID that goes by the role stored for it.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param target [String exact player name, target selector or SteamID]
function remove:on_run(actor, target)
  local targets, steam_id = Bolt:find_command_targets(actor, target)

  if targets then
    for _, v in ipairs(targets) do
      v:notify('notification.demote', {
        group = v:GetUserGroup()
      })
      v:SetUserGroup('user')
    end

    self:notify_staff('command.role.remove.message', {
      player = get_player_name(actor),
      target = util.player_list_to_string(targets)
    })
  elseif steam_id then
    Bolt:demote_steam_id(actor, steam_id, function(name)
      self:notify_staff('command.role.remove.message', {
        player = get_player_name(actor),
        target = name
      })
    end)
  end
end
