--- The Tp command teleports the targeted players to the spot the caller is looking at.

CMD.name = 'Tp'
CMD.description = 'command.tp.description'
CMD.syntax = 'command.tp.syntax'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.arg_types = { 'player' }
CMD.immunity = true
CMD.no_console = true
CMD.aliases = { 'teleport', 'plytp', 'bring' }

--- Teleports the targeted players to the spot the caller is looking at and notifies them and
-- staff.
-- @param actor [Player the caller]
-- @param targets [List<Player> players to teleport]
function CMD:on_run(actor, targets)
  local pos = actor:GetEyeTraceNoCursor().HitPos

  for _, client in ipairs(targets) do
    if IsValid(client) then
      client:teleport(pos)
      client:notify('notification.tp')
    end
  end

  self:notify_staff('command.tp.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
