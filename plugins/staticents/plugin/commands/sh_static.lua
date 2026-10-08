--- The `static` command: makes the entity the caller is looking at static.

CMD.name = 'Static'
CMD.description = 'command.static.description'
CMD.permission = 'assistant'
CMD.category = 'permission.categories.level_design'
CMD.aliases = { 'staticadd', 'staticpropadd' }

--- Makes the entity the caller is looking at static.
-- @param actor [Player the caller]
function CMD:on_run(actor)
  --- Asks the plugins to make the entity a player is looking at static, or to remove its
  -- static status.
  -- Called on the server by the `static` and `unstatic` commands and by the Static Add/Remove
  -- tool. The plugin's own handler checks the player's permission and the class of the entity,
  -- applies the change and notifies the player.
  -- @param actor [Player The player who makes the request]
  -- @param is_static [Boolean True to make the entity static and false to make it unstatic]
  Plugin.call('PlayerMakeStatic', actor, true)
end
