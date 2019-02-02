local COMMAND = Command.new('static')
COMMAND.name = 'Static'
COMMAND.description = t'static.description'
COMMAND.category = 'categories.level_design'
COMMAND.aliases = { 'staticadd', 'staticpropadd' }

function COMMAND:on_run(player)
  plugin.call('PlayerMakeStatic', player, true)
end

COMMAND:register()
