CMD.name = 'UnStatic'
CMD.description = 'command.unstatic.description'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.level_design'
CMD.aliases = { 'staticpropremove', 'staticremove' }

function CMD:on_run(player)
  Plugin.call('PlayerMakeStatic', player, false)
end
