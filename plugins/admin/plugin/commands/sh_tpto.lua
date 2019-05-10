local COMMAND = Command.new('tpto')
COMMAND.name = 'Tpto'
COMMAND.description = 'tptocmd.description'
COMMAND.syntax = 'tptocmd.syntax'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.administration'
COMMAND.arguments = 1
COMMAND.immunity = true
COMMAND.aliases = { 'goto' }

function COMMAND:on_run(player, targets)
  local target = targets[1]

  if IsValid(target) then
    player:teleport(target:GetPos())
  end

  player:notify('tptocmd.notify', target:name())
end

COMMAND:register()
