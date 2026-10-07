class 'Command'

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
-- command has immunity or player_arg set, the target argument is an Array<Player> instead.
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
-- function CMD:on_run(player, targets)
--   for k, v in ipairs(targets) do
--     v:Freeze(true)
--   end
--
--   self:notify_staff('command.freeze.message', {
--     player = get_player_name(player),
--     target = util.player_list_to_string(targets)
--   })
-- end
-- ```
function Command:on_run() end

--- Sends a notification to a group of players.
-- @param permision [String/Array<Player>/Player permission the recipients must have, a list
--   of recipients or a single recipient; everyone is notified if nil]
-- @param message [String text or language phrase]
-- @param arguments=nil [Hash values to substitute into the phrase]
-- @param color=nil [Color]
function Command:notify(permision, message, arguments, color)
  local player_list

  if isstring(permission) then
    player_list = table.map(player.all(), function(v) if v:can(permission) then return v end end)
  elseif istable(permission) then
    player_list = permission
  elseif IsValid(permission) then
    player_list = { permission }
  else
    player_list = player.all()
  end

  for k, v in ipairs(player_list) do
    v:notify(message, arguments, color)
  end
end

--- Sends a light red notification to a group of players.
-- @param permision [String/Array<Player>/Player permission the recipients must have, a list
--   of recipients or a single recipient; everyone is notified if nil]
-- @param message [String text or language phrase]
-- @param arguments=nil [Hash values to substitute into the phrase]
-- @see [Command#notify]
function Command:notify_admin(permision, message, arguments)
  self:notify(permission, message, arguments, Color(255, 128, 128))
end

--- Sends a light blue notification meant for the players with the 'staff' permission.
-- ```
-- self:notify_staff('command.changelevel.message', {
--   player = get_player_name(player),
--   map = map,
--   delay = delay
-- })
-- ```
-- @param message [String text or language phrase]
-- @param arguments=nil [Hash values to substitute into the phrase]
-- @see [Command#notify]
function Command:notify_staff(message, arguments)
  self:notify('staff', message, arguments, Color(150, 150, 255))
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
