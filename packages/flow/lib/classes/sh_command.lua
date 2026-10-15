--- A chat and console command. A file in a `commands` folder receives a new instance as `CMD`
-- and describes the command through its fields: `name`, `description` and `syntax` (texts or
-- language phrases), `arguments` (the minimum amount of arguments), `arg_types` (what each
-- argument is, for completion and checking), `aliases` (the names it can be called by) and
-- `no_console` (the command cannot be run from the server console).
-- The admin plugin registers a permission named after the command's ID, which the role files
-- allow to roles with `can`. `permission` names the role the command is allowed to, along
-- with the roles based on it, unless a role file decides the command itself; this is the way
-- for a plugin that adds a single command, while a plugin with several commands allows them
-- in role files. A command allowed by neither is denied to every player.
-- Setting `immunity` or `player_arg` turns one argument into a list of target players: the
-- first argument, or the one at the position that `player_arg` gives. With `immunity` the
-- caller must also pass the immunity check (the `CommandCheckImmunity` hook) against every
-- target; with the admin plugin that means a role with a higher immunity than the target's,
-- or the same one if `can_equal` is set, while callers always pass against themselves and
-- root players against anyone. When `player_arg` is not set, the first 'player' entry of
-- `arg_types` decides the position; `player_arg = false` keeps every argument a string, for
-- commands that look their targets up themselves.
--
-- `arg_types` lists one entry per argument position: the ID of an argument type with a
-- completer (see `Flux.Command:add_completer`), such as 'player', or a list of the exact
-- words the argument may be, such as `{ 'on', 'off' }`. The server only accepts one of those
-- words, in any case, and passes it on as it is written in the list. The last entry applies
-- to the arguments after it as well if it is 'text', free text that nothing is suggested for
-- and that `on_run` receives as one string, exactly as it was typed.
--
-- A command can be split into subcommands with `Command:subcommand`: `/whitelist add` and
-- `/whitelist remove` are two subcommands of the Whitelist command. Each one is a `Command`
-- of its own with the same fields and its own `on_run`. What the command does goes into
-- `Command:on_run`, and the `notify` helpers tell players about the outcome. Registered
-- commands are kept and run by the `Flux.Command` library.

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
Command.permission = nil
Command.permission_id = nil
Command.arg_types = nil

--- Converts the command to a string for printing.
-- @return [String]
function Command:__tostring()
  return '#<Command:'..self:get_full_id()..'>'
end

--- Creates a new command.
-- @param id [String unique command ID]
function Command:init(id)
  self.id = id
end

--- Adds a subcommand: a word that follows the command and picks what it does, such as `add`
-- in `/whitelist add John faction`. The subcommand is a `Command` of its own with the same
-- fields as a command (`name`, which is the ID unless set, `description`, `syntax`,
-- `arguments`, `arg_types`, `immunity`, `player_arg`, `can_equal`, `no_console` and
-- `aliases`) and its own `on_run`, which receives the arguments after the subcommand word.
-- Its `parent` field is the command it belongs to. It uses the permission of that command,
-- unless it names its own permission ID in `permission_id`; the admin plugin registers that
-- permission, and `permission` may then name the role it is allowed to.
--
-- The subcommand word has to match the ID or one of the aliases exactly, in any case. Without
-- a subcommand word the command runs its own `on_run` if the file defines one, and tells the
-- player which subcommands there are otherwise. A command that also sets `arguments` or
-- `arg_types` for itself takes any other first word as its own argument.
-- ```
-- -- plugins/factions/plugin/commands/sh_whitelist.lua
-- CMD.name = 'Whitelist'
-- CMD.description = 'command.whitelist.description'
-- CMD.category = 'permission.categories.player_management'
-- CMD.aliases = { 'plywhitelist' }
--
-- local add = CMD:subcommand('add')
-- add.description = 'command.whitelist.add.description'
-- add.syntax = 'command.whitelist.add.syntax'
-- add.arguments = 2
-- add.arg_types = { 'player', 'faction' }
--
-- function add:on_run(actor, targets, faction_id)
--   for k, v in ipairs(targets) do
--     v:give_whitelist(faction_id)
--   end
-- end
--
-- local wipe = CMD:subcommand('wipe')
-- wipe.description = 'command.whitelist.wipe.description'
-- wipe.syntax = 'command.whitelist.wipe.syntax'
-- wipe.permission_id = 'whitelist_wipe'
-- wipe.permission = 'admin'
-- wipe.arguments = 1
-- wipe.arg_types = { 'faction', { 'confirm' } }
--
-- function wipe:on_run(actor, faction_id)
--   Factions.wipe_whitelist(faction_id)
-- end
-- ```
-- @param id [String the word the subcommand is called by, stored in lower case]
-- @return [Command the new subcommand]
function Command:subcommand(id)
  id = id:utf8lower()

  local sub = Command.new(id)
  sub.name = id
  sub.parent = self

  self.subcommands = self.subcommands or {}
  self.subcommand_list = self.subcommand_list or {}

  if !self.subcommands[id] then
    self.subcommand_list[#self.subcommand_list + 1] = sub
  else
    for k, v in ipairs(self.subcommand_list) do
      if v.id == id then
        self.subcommand_list[k] = sub
      end
    end
  end

  self.subcommands[id] = sub

  return sub
end

--- Returns the subcommands of the command in the order they were added.
-- @return [List<Command> the subcommands, empty if there are none]
function Command:get_subcommands()
  return self.subcommand_list or {}
end

--- Checks whether the command has subcommands.
-- @return [Boolean]
function Command:has_subcommands()
  return self.subcommand_list != nil and #self.subcommand_list > 0
end

--- Finds a subcommand by the word that was typed for it: its ID or one of its aliases,
-- matched exactly but in any case.
-- @param word [String]
-- @return [Command the subcommand, or nil if there is none for this word]
function Command:find_subcommand(word)
  if !isstring(word) or !self.subcommands then return end

  word = word:utf8lower()

  local found = self.subcommands[word]

  if found then return found end

  for _, v in ipairs(self.subcommand_list) do
    for _, v2 in ipairs(v.aliases or {}) do
      if v2:utf8lower() == word then
        return v
      end
    end
  end
end

--- Returns the top-level command a subcommand belongs to, or the command itself.
-- @return [Command]
function Command:get_root()
  local cmd = self

  while cmd.parent do
    cmd = cmd.parent
  end

  return cmd
end

--- Returns the name of the command as it is shown to players, with the name of the command
-- it belongs to in front for a subcommand.
-- ```
-- CMD:get_full_name() -- 'Whitelist'
-- add:get_full_name() -- 'Whitelist add'
-- ```
-- @return [String]
function Command:get_full_name()
  if self.parent then
    return self.parent:get_full_name()..' '..tostring(self.name)
  end

  return tostring(self.name)
end

--- Returns the IDs of the command and the commands it belongs to, separated by spaces, as
-- they are typed: 'whitelist add' for the `add` subcommand of the Whitelist command.
-- @return [String]
function Command:get_full_id()
  if self.parent then
    return self.parent:get_full_id()..' '..tostring(self.id)
  end

  return tostring(self.id)
end

--- Returns the syntax of the command for display. A command with subcommands that does not
-- set a syntax of its own gets one that lists them, such as '<add|remove>'.
-- @return [String language phrase or text; '[-]' if the command takes no arguments]
function Command:get_syntax()
  if (!self.syntax or self.syntax == '[-]') and self:has_subcommands() then
    local ids = {}

    for _, v in ipairs(self.subcommand_list) do
      ids[#ids + 1] = v.id
    end

    return '<'..table.concat(ids, '|')..'>'
  end

  return self.syntax or '[-]'
end

--- Returns the ID of the permission that is checked before the command runs: `permission_id`
-- if the command sets one, else the permission of the command it belongs to, else the ID of
-- the command.
-- @return [String permission ID]
function Command:get_permission()
  if self.permission_id then
    return self.permission_id
  end

  if self.parent then
    return self.parent:get_permission()
  end

  return self.id
end

--- Checks whether the command has a permission of its own rather than the one of the command
-- it belongs to: true for every top-level command and for a subcommand with `permission_id`.
-- @return [Boolean]
function Command:has_own_permission()
  return !self.parent or self.permission_id != nil
end

--- Checks whether someone may run the command. A player needs its permission (see
-- `Command:get_permission`); the server console may run every command unless it, or a
-- command it belongs to, has `no_console` set.
-- @param actor [Player the player, or nil or an invalid entity for the server console]
-- @return [Boolean]
function Command:is_allowed(actor)
  if IsValid(actor) then
    return actor:can(self:get_permission()) and true or false
  end

  local cmd = self

  while cmd do
    if cmd.no_console then
      return false
    end

    cmd = cmd.parent
  end

  return true
end

--- Checks whether the command takes arguments of its own, that is whether it sets
-- `arguments` or `arg_types`. A command with subcommands that does so takes a first word that is
-- not a subcommand as its own argument.
-- @return [Boolean]
function Command:takes_arguments()
  return (self.arguments or 0) > 0 or (istable(self.arg_types) and #self.arg_types > 0)
end

--- Checks whether the command file has given the command an `on_run` callback.
-- @return [Boolean]
function Command:has_callback()
  return isfunction(self.on_run) and self.on_run != Command.on_run
end

--- Returns the type of an argument from `arg_types`. The last entry applies to every
-- argument after it if it is 'text'.
-- @param index [Number position of the argument, 1 for the first one after the command or
--   subcommand word]
-- @return [String/List<String> type ID or list of allowed words, nil if the argument has no
--   type]
function Command:get_arg_type(index)
  local arg_types = self.arg_types

  if !istable(arg_types) then return end

  local arg_type = arg_types[index]

  if arg_type == nil and arg_types[#arg_types] == 'text' then
    return 'text'
  end

  return arg_type
end

--- Returns the position of the argument that takes the rest of the text: the last entry of
-- `arg_types` if it is 'text'. That argument reaches `on_run` as one string, exactly as it
-- was typed, with its quotes and spaces, and only the whitespace at its end removed. A text
-- that is nothing but a pair of double quotes with only whitespace between them arrives as an
-- empty string.
-- @return [Number position of the argument, nil if the command has no such argument]
function Command:get_text_index()
  local arg_types = self.arg_types

  if istable(arg_types) and #arg_types > 0 and arg_types[#arg_types] == 'text' then
    return #arg_types
  end
end

--- Returns the position of the first 'player' entry of `arg_types`.
-- @return [Number the position, or nil if there is no such entry]
function Command:find_player_arg()
  for k, v in ipairs(istable(self.arg_types) and self.arg_types or {}) do
    if v == 'player' then
      return k
    end
  end
end

--- Called on the server when the command is run. Does nothing by default, override it
-- in the command file. It receives the player who has run the command (an invalid entity
-- if it was run from the server console) followed by the arguments as strings; the
-- `on_run` of a subcommand gets the arguments after the subcommand word. If the command has
-- immunity or player_arg set, or a 'player' entry in arg_types, the target argument is a
-- List<Player> instead, and an argument with a list of words in arg_types is the word as it
-- is written in that list. `self.raw_args` holds the text of the arguments as it was typed.
-- The command below is the only one of its plugin, so it names the role it is allowed to in
-- `permission` instead of being allowed in a role file.
-- ```
-- -- plugins/slap/plugin/commands/sh_slap.lua
-- CMD.name = 'Slap'
-- CMD.description = 'command.slap.description'
-- CMD.syntax = 'command.slap.syntax'
-- CMD.permission = 'assistant'
-- CMD.arguments = 1
-- CMD.arg_types = { 'player' }
-- CMD.immunity = true
-- CMD.aliases = { 'slap', 'plyslap' }
--
-- function CMD:on_run(actor, targets)
--   for k, v in ipairs(targets) do
--     v:TakeDamage(10, actor)
--   end
--
--   self:notify_staff('command.slap.message', {
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
