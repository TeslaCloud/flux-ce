local COMMAND = Command.new('static')
COMMAND.name = 'Static'
COMMAND.description = 'static.description'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.level_design'
COMMAND.aliases = { 'staticadd', 'staticpropadd' }

function COMMAND:on_run(player)
  Plugin.call('PlayerMakeStatic', player, true)
end

COMMAND:register()
