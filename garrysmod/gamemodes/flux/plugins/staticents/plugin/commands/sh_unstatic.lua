local COMMAND = Command.new('unstatic')
COMMAND.name = 'UnStatic'
COMMAND.description = t'unstatic.description'
COMMAND.category = 'misc'
COMMAND.aliases = { 'staticpropremove', 'staticremove' }

function COMMAND:on_run(player)
  plugin.call('PlayerMakeStatic', player, false)
end

COMMAND:register()
