local COMMAND = Command.new('return')
COMMAND.name = 'Return'
COMMAND.description = 'command.return.description'
COMMAND.syntax = 'command.return.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.administration'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'return', 'back' }

function COMMAND:on_run(player, targets)
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

COMMAND:register()
