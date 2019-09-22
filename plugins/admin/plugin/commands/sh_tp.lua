CMD.name = 'Tp'
CMD.description = 'command.tp.description'
CMD.syntax = 'command.tp.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'teleport', 'plytp', 'bring' }

function CMD:on_run(player, targets)
  local pos = player:GetEyeTraceNoCursor().HitPos

  for k, v in pairs(targets) do
    if IsValid(v) then
      v:teleport(pos)
      v:notify('notification.tp')
    end
  end

  self:notify_staff('command.tp.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
