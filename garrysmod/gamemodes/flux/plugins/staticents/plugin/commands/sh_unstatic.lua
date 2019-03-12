local COMMAND = Command.new('unstatic')
COMMAND.name = 'UnStatic'
COMMAND.description = t'unstatic.description'
COMMAND.permission = 'assistant'
COMMAND.category = 'categories.level_design'
COMMAND.aliases = { 'staticpropremove', 'staticremove' }

function COMMAND:on_run(player)
  Plugin.call('PlayerMakeStatic', player, false)
end

COMMAND:register()
