CMD.name = 'Return'
CMD.description = 'command.return.description'
CMD.syntax = 'command.return.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.immunity = true
CMD.aliases = { 'return', 'back' }

function CMD:on_run(player, targets)
  for k, v in ipairs(targets) do
    if IsValid(v) and v.prev_pos then
      v:notify('notification.return')
      v:teleport(v.prev_pos)
      v.prev_pos = nil
    end
  end

  self:notify_staff('command.return.message', {
    player = get_player_name(player),
    target = util.player_list_to_string(targets)
  })
end
