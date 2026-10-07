CMD.name = 'Static'
CMD.description = 'command.static.description'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.level_design'
CMD.aliases = { 'staticadd', 'staticpropadd' }

--- Makes the entity the caller is looking at static.
-- @param player [Player the caller]
function CMD:on_run(player)
  Plugin.call('PlayerMakeStatic', player, true)
end
