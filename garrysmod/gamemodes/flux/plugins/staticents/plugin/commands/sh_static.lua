local COMMAND = Command.new('static')
COMMAND.name = 'Static'
COMMAND.description = "Makes the entity you're looking at static."
COMMAND.syntax = '[none]'
COMMAND.category = 'misc'
COMMAND.aliases = { 'staticadd', 'staticpropadd' }

function COMMAND:on_run(player)
  plugin.call('PlayerMakeStatic', player, true)
end

COMMAND:register()
