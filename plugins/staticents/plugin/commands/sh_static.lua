local COMMAND = Command.new('static')
COMMAND.name = 'Static'
COMMAND.description = 'command.static.description'
COMMAND.permission = 'assistant'
COMMAND.category = 'perm.categories.level_design'
COMMAND.aliases = { 'staticadd', 'staticpropadd' }

function COMMAND:on_run(player)
  Plugin.call('PlayerMakeStatic', player, true)
end

COMMAND:register()
