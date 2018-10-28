local COMMAND = Command.new('static')
COMMAND.name = 'Static'
COMMAND.description = t'static.description'
COMMAND.category = 'misc'
COMMAND.aliases = { 'staticadd', 'staticpropadd' }

function COMMAND:on_run(player)
  plugin.call('PlayerMakeStatic', player, true)
end

COMMAND:register()
