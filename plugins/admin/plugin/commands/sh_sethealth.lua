--- The SetHealth command: `/sethealth <target> <value>` sets the health of the targeted
-- players to a whole number of at least 1.

CMD.name = 'SetHealth'
CMD.description = 'command.sethealth.description'
CMD.syntax = 'command.sethealth.syntax'
CMD.category = 'permission.categories.player_management'
CMD.arguments = 2
CMD.arg_types = { 'player', 'number' }
CMD.immunity = true
CMD.aliases = { 'plysethealth', 'hp' }

--- Sets the health of the targeted players and notifies them and staff. The caller is told
-- when the value is not a number of at least 1.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to set the health of]
-- @param text [String the health, rounded down]
function CMD:on_run(actor, targets, text)
  local value = math.floor(tonumber(text) or 0)

  if !(value >= 1 and value < math.huge) then
    Flux.Player:notify(actor, 'error.invalid_value')

    return
  end

  for _, client in ipairs(targets) do
    client:SetHealth(value)
    client:notify('notification.sethealth', { health = value })
  end

  self:notify_staff('command.sethealth.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets),
    health = value
  })
end
