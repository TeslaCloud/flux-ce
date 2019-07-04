local COMMAND = Command.new('unstatic')
COMMAND.name = 'UnStatic'
COMMAND.description = 'command.unstatic.description'
COMMAND.permission = 'assistant'
COMMAND.category = 'permission.categories.level_design'
COMMAND.aliases = { 'staticpropremove', 'staticremove' }

function COMMAND:on_run(player)
  Plugin.call('PlayerMakeStatic', player, false)
end

COMMAND:register()
