--- The SetArmor command: `/setarmor <target> <value>` sets the armor of the targeted players
-- to a whole number of at least 0.

CMD.name = 'SetArmor'
CMD.description = 'command.setarmor.description'
CMD.syntax = 'command.setarmor.syntax'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.arg_types = { 'player', 'number' }
CMD.immunity = true
CMD.aliases = { 'plysetarmor', 'armor' }

--- Sets the armor of the targeted players and notifies them and staff. The caller is told
-- when the value is not a number of at least 0.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to set the armor of]
-- @param text [String the armor, rounded down]
function CMD:on_run(actor, targets, text)
  local value = math.floor(tonumber(text) or -1)

  if !(value >= 0 and value < math.huge) then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  for _, client in ipairs(targets) do
    client:SetArmor(value)
    client:notify('notification.setarmor', { armor = value })
  end

  self:notify_staff('command.setarmor.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    armor = value
  })
end
