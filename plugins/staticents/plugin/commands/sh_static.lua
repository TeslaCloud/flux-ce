--- The `static` staff command, which acts on the entity the caller is looking at:
-- `/static add` makes it static and `/static remove` removes its static status.

CMD.name = 'Static'
CMD.description = 'command.static.description'
CMD.category = 'permission.categories.level_design'
CMD.no_console = true

local add = CMD:subcommand('add')
add.description = 'command.static.add.description'

--- Makes the entity the caller is looking at static.
-- @param actor [Player the caller]
function add:on_run(actor)
  --- Makes the entity a player is looking at static, or removes its static status.
  -- Called on the server by the `static add` and `static remove` commands and by the Static
  -- Add/Remove tool. The plugin's own handler checks the player's permission and the class of
  -- the entity, applies the change and notifies the player; a handler that runs before it
  -- and returns a value takes the request over. Gamemode (`GM`) handlers are not called.
  -- @param actor [Player The player who makes the request]
  -- @param is_static [Boolean True to make the entity static and false to make it unstatic]
  Plugin.call('PlayerSetEntityStatic', actor, true)
end

local remove = CMD:subcommand('remove')
remove.description = 'command.static.remove.description'

--- Removes the static status of the entity the caller is looking at.
-- @param actor [Player the caller]
function remove:on_run(actor)
  Plugin.call('PlayerSetEntityStatic', actor, false)
end
