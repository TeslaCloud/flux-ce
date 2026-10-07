CMD.name = 'Tp'
CMD.description = 'command.tp.description'
CMD.syntax = 'command.tp.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'teleport', 'plytp', 'bring' }

--- Teleports the targeted players to the spot the caller is looking at and notifies them and
-- staff.
-- @param actor [Player the caller, or an invalid entity when run from the server console]
-- @param targets [List<Player> players to teleport]
function CMD:on_run(actor, targets)
  local pos = actor:GetEyeTraceNoCursor().HitPos

  for k, v in pairs(targets) do
    if IsValid(v) then
      v:teleport(pos)
      v:notify('notification.tp')
    end
  end

  self:notify_staff('command.tp.message', {
    player = get_player_name(actor),
    target = util.player_list_to_string(targets)
  })
end
