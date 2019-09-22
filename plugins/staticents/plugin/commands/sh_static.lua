CMD.name = 'Static'
CMD.description = 'command.static.description'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.level_design'
CMD.aliases = { 'staticadd', 'staticpropadd' }

function CMD:on_run(player)
  Plugin.call('PlayerMakeStatic', player, true)
end
