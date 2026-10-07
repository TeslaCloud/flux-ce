CMD.name = 'UnStatic'
CMD.description = 'command.unstatic.description'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.level_design'
CMD.aliases = { 'staticpropremove', 'staticremove' }

--- Removes the static status of the entity the caller is looking at.
-- @param actor [Player the caller]
function CMD:on_run(actor)
  Plugin.call('PlayerMakeStatic', actor, false)
end
