--- A chat and console command. A file in a `commands` folder receives a new instance as `CMD`
-- and describes the command through its fields: `name`, `description` and `syntax` (texts or
-- language phrases), `permission` (the ID of the role that may run it by default, 'user' if
-- not set; the admin plugin registers a permission named after the command's ID and allows
-- it for that role), `arguments` (the minimum amount of arguments), `aliases` (the names it
-- can be called by) and `no_console` (the command cannot be run from the server console).
-- Setting `immunity` or `player_arg` turns one argument into a list of target players: the
-- first argument, or the one at the position that `player_arg` gives. With `immunity` the
-- caller must also pass the immunity check (the `CommandCheckImmunity` hook) against every
-- target; with the admin plugin that means a role with a higher immunity than the target's,
-- or the same one if `can_equal` is set, while callers always pass against themselves and
-- root players against anyone. What the command does goes into `Command:on_run`, and the
-- `notify` helpers tell players about the outcome. Registered commands are kept and run by
-- the `Flux.Command` library.

class 'Command'

local admin_color = Color(255, 128, 128)
local staff_color = Color(150, 150, 255)

Command.id = 'undefined'
Command.name = 'Unknown'
Command.description = 'An undescribed command.'
Command.syntax = '[-]'
Command.immunity = false
Command.player_arg = nil
Command.arguments = 0
Command.no_console = false

--- Converts the command to a string for printing.
-- @return [String]
function Command:__tostring()
  return '#<Command:'..self.id..'>'
end

--- Creates a new command.
-- @param id [String unique command ID]
function Command:init(id)
  self.id = id
end

--- Called on the server when the command is run. Does nothing by default, override it
-- in the command file. It receives the player who has run the command (an invalid entity
-- if it was run from the server console) followed by the arguments as strings. If the
-- command has immunity or player_arg set, the target argument is a List<Player> instead.
-- ```
-- -- plugin/commands/sh_freeze.lua
-- CMD.name = 'Freeze'
-- CMD.description = 'command.freeze.description'
-- CMD.syntax = 'command.freeze.syntax'
-- CMD.permission = 'assistant'
-- CMD.arguments = 1
-- CMD.immunity = true
-- CMD.aliases = { 'freeze', 'plyfreeze' }
--
-- function CMD:on_run(actor, targets)
--   for k, v in ipairs(targets) do
--     v:Freeze(true)
--   end
--
--   self:notify_staff('command.freeze.message', {
--     player = get_player_name(actor),
--     target = util.player_list_to_string(targets)
--   })
-- end
-- ```
function Command:on_run() end

--- Sends a notification to a group of players.
-- @param permission [String/List<Player>/Player permission the recipients must have, a list
--   of recipients or a single recipient; everyone is notified if nil]
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
-- @param color=nil [Color]
function Command:notify(permission, message, arguments, color)
  local player_list

  if isstring(permission) then
    player_list = table.map(player.GetAll(), function(v) if v:can(permission) then return v end end)
  elseif istable(permission) then
    player_list = permission
  elseif IsValid(permission) then
    player_list = { permission }
  else
    player_list = player.GetAll()
  end

  for i = 1, #player_list do
    player_list[i]:notify(message, arguments, color)
  end
end

--- Sends a light red notification to a group of players.
-- @param permission [String/List<Player>/Player permission the recipients must have, a list
--   of recipients or a single recipient; everyone is notified if nil]
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
-- @see [Command#notify]
function Command:notify_admin(permission, message, arguments)
  self:notify(permission, message, arguments, admin_color)
end

--- Sends a light blue notification meant for the players with the 'staff' permission.
-- ```
-- self:notify_staff('command.changelevel.message', {
--   player = get_player_name(actor),
--   map = map,
--   delay = delay
-- })
-- ```
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
-- @see [Command#notify]
function Command:notify_staff(message, arguments)
  self:notify('staff', message, arguments, staff_color)
end

--- Returns the description of the command. Can be overridden to build it dynamically.
-- @return [String description or its language phrase]
function Command:get_description()
  return self.description
end

--- Registers this command with Flux.Command#create.
function Command:register()
  Flux.Command:create(self.id, self)
end
