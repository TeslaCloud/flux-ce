CMD.name = 'Tpto'
CMD.description = 'command.tpto.description'
CMD.syntax = 'command.tpto.syntax'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.administration'
CMD.arguments = 1
CMD.player_arg = 1
CMD.alias = 'goto'

function CMD:on_run(player, targets)
  local target = targets[1]

  if IsValid(target) then
    player:teleport(target:GetPos())
  end

  self:notify_staff('command.tpto.message', {
    player = get_player_name(player),
    target = util.player_list_to_string({ target })
  })
end
