--- The command system: keeps the registered chat and console commands, completes what players
-- type and runs the commands for them. Commands are `Command` objects. Every file in the
-- `commands` folder of a plugin or schema gets a `CMD` table to fill in (name, description,
-- syntax, argument types, permission, aliases, subcommands and the `on_run` callback) and is
-- registered automatically under an ID taken from its file name; see `Command:on_run` and
-- `Command:subcommand` for examples. Players run commands by typing them in the chat with a
-- command prefix or through the `flc` console command, which also works from the server
-- console.
--
-- Everything that is typed has to match exactly, ignoring the case: the command ID or alias,
-- the subcommand word, a word from a list of allowed words, and a player's full name or
-- SteamID. `Flux.Command:complete` turns what has been typed so far into the full words: the
-- chatbox and the console offer its suggestions, and `Flux.Command:add_completer` lets
-- plugins suggest the values of their own argument types.
--
-- On the server `Flux.Command:interpret` does the work: it splits the text into arguments,
-- finds the command by its ID or alias and the subcommand by its word, checks the permission
-- of the player, the amount of arguments and the words from lists, turns the player argument
-- into a list of targets (player names or the selectors described under
-- `Flux.Command:str_to_player`), checks their immunity, logs the command and calls its
-- `on_run`. Plugins can step in through the `PlayerCanRunCommand`, `CommandCheckImmunity`,
-- `PlayerRunCommand` and `TargetFromString` hooks. On the client `Flux.Command:send` asks
-- the server to run a command for the local player.

mod 'Flux::Command'

local IsValid           = IsValid
local istable           = istable
local isstring          = isstring
local isfunction        = isfunction

local command_log_color = Color('orange')
local max_commands_per_second = 10
local stored            = Flux.Command.stored     or {}
local aliases           = Flux.Command.aliases    or {}
local completers        = Flux.Command.completers or {}
Flux.Command.stored     = stored
Flux.Command.aliases    = aliases
Flux.Command.completers = completers

--- Counts the characters of a UTF-8 string, counting every byte that does not continue a
-- character.
-- @param str [String]
-- @return [Number]
local function char_count(str)
  local _, count = str:gsub('[^\128-\191]', '')

  return count
end

local function command_throttled(actor)
  local cur_time = CurTime()

  if (actor.fl_command_window or 0) <= cur_time then
    actor.fl_command_window = cur_time + 1
    actor.fl_command_count = 0
  end

  actor.fl_command_count += 1

  return actor.fl_command_count > max_commands_per_second
end

--- Fills in the defaults for the missing fields of a command and of its subcommands: name,
-- syntax, immunity, arguments, description, aliases from a single `alias`, and `player_arg`
-- from the first 'player' entry of `arg_types`.
-- @param cmd [Command]
local function prepare(cmd)
  cmd.name        = cmd.name        or 'Unknown'
  cmd.syntax      = cmd.syntax      or '[-]'
  cmd.immunity    = cmd.immunity    or false
  cmd.arguments   = cmd.arguments   or 0
  cmd.description = cmd.description or 'An undescribed command.'

  if isstring(cmd.alias) then
    cmd.aliases = { cmd.alias }
  end

  if cmd.player_arg == nil then
    cmd.player_arg = cmd:find_player_arg()
  end

  for _, subcommand in ipairs(cmd:get_subcommands()) do
    prepare(subcommand)
  end
end

local function is_reachable(cmd, actor)
  if cmd:is_allowed(actor) then
    return true
  end

  for _, subcommand in ipairs(cmd:get_subcommands()) do
    if is_reachable(subcommand, actor) then
      return true
    end
  end

  return false
end

--- Follows the subcommand words of a list of tokens, starting at a command.
-- @param cmd [Command the command the first token calls]
-- @param tokens [List<Map> tokens as `Flux.Command:tokenize` returns them]
-- @param last [Number position of the last token that may be a subcommand word]
-- @return [Command the deepest command or subcommand found, Number position of the first
--   token after it]
local function descend(cmd, tokens, last)
  local index = 2

  while index <= last and cmd:has_subcommands() do
    local sub = cmd:find_subcommand(tokens[index].value)

    if !sub then break end

    cmd = sub
    index += 1
  end

  return cmd, index
end

--- Registers a command along with its aliases, fills in the defaults for missing fields of
-- the command and its subcommands, and runs the 'CommandCreated' hook. Commands defined in
-- the 'commands' folder of a plugin are registered automatically, see Command#on_run for an
-- example. When `player_arg` is not set, the position of the first 'player' entry of
-- `arg_types` is used.
-- @param id [String unique command ID, also the main name it is called by; it is stored
--   converted with `string.to_id`]
-- @param data [Command/Map command object or a table with the same fields: name, description,
--   syntax, permission (ID of the role it is allowed to), permission_id, arguments (minimum
--   amount), arg_types, immunity, player_arg, alias or aliases, no_console and the on_run
--   callback; a table is turned into a Command]
-- @see [Command#on_run]
-- @see [Command#subcommand]
function Flux.Command:create(id, data)
  if !id or !data then return end

  if !isfunction(data.get_permission) then
    local cmd = Command.new(id)

    for field, value in pairs(data) do
      cmd[field] = value
    end

    data = cmd
  end

  id = id:to_id()
  data.id = id

  prepare(data)

  stored[id] = data
  aliases[id] = id

  for _, alias in ipairs(data.aliases or {}) do
    aliases[alias:utf8lower()] = id
  end

  --- Called on the server and the client after a command has been registered with
  -- `Flux.Command:create`.
  -- @param id [String command ID]
  -- @param data [Command the command, with the defaults filled in; its subcommands are in
  --   `Command:get_subcommands`]
  hook.Run('CommandCreated', id, data)
end

--- Finds a command by its exact ID or alias, ignoring the case.
-- @param id [String command ID or alias]
-- @return [Command the command, or nil if there is no such command]
function Flux.Command:find_by_id(id)
  id = id:utf8lower()

  if stored[id] then return stored[id] end
  if aliases[id] then return stored[aliases[id]] end
end

--- Finds all of the commands that have the search string in their ID or aliases.
-- On the client only the commands the local player has access to are returned.
-- @param id [String search string]
-- @return [List<Command> matching commands]
function Flux.Command:find_all(id)
  local hits = {}
  local ids = {}

  for alias, cmd_id in pairs(aliases) do
    if !ids[cmd_id] and stored[cmd_id] and (alias:include(id) or cmd_id:include(id)) then
      if SERVER or is_reachable(stored[cmd_id], LocalPlayer()) then
        hits[#hits + 1] = stored[cmd_id]
      end

      ids[cmd_id] = true
    end
  end

  return hits
end

--- Checks whether a text is a command, that is whether it starts with one of the prefixes of
-- the 'flow_command_prefixes' config. If several prefixes match, the longest one is used, so that
-- prefixes can contain each other (e.g. '/' and '//'). The ShouldTreatAsCommand hook can
-- return false to prevent that.
-- @param text [String]
-- @return [Boolean whether the text is a command, Number length of the prefix if it is one]
function Flux.Command:is_command(text)
  local prefixes = Config.get('flow_command_prefixes') or {}
  local longest

  for _, prefix in ipairs(prefixes) do
    if text:start_with(prefix) then
      longest = math.max(longest or 0, utf8.len(prefix))
    end
  end

  --- Called when `Flux.Command:is_command` checks a text that starts with one of the command
  -- prefixes.
  -- Lets plugins keep such a text from being treated as a command, as the Chatbox plugin does
  -- for the texts that start with a chat prefix. Runs on both the server and the client.
  -- @param text [String the text being checked]
  -- @return [Boolean Return false to have the text treated as regular text instead of a
  --   command]
  if longest and hook.Run('ShouldTreatAsCommand', text) != false then
    return true, longest
  end

  return false
end

--- Splits a command string into tokens. Tokens are separated by whitespace; text in double
-- quotes that start a token is one token, and the quotes are not part of its value. A double
-- quote that is never closed is an ordinary character, unless `open_end` is set: the rest of
-- the text is then the last token, as it is while a quoted argument is being typed.
-- ```
-- -- 'ban', 'John Doe' (quoted, closed) and '60'
-- local tokens = Flux.Command:tokenize('ban "John Doe" 60')
-- ```
-- @param text [String]
-- @param open_end=false [Boolean read an unclosed quote as a token that is being typed]
-- @return [List<Map> tokens: value (String), start and finish (Number positions of the first
--   and the last byte of the token in the text, quotes included), quoted (Boolean true if it
--   starts with a quote) and closed (Boolean whether the quote is closed, false only for an
--   unclosed quote read with open_end)]
function Flux.Command:tokenize(text, open_end)
  local tokens = {}
  local length = #text
  local pos = 1

  while pos <= length do
    local start = text:find('%S', pos)

    if !start then break end

    local close = text:byte(start) == 34 and text:find('"', start + 1, true)

    if close then
      tokens[#tokens + 1] = {
        value = text:sub(start + 1, close - 1),
        start = start,
        finish = close,
        quoted = true,
        closed = true
      }

      pos = close + 1
    elseif open_end and text:byte(start) == 34 then
      tokens[#tokens + 1] = {
        value = text:sub(start + 1),
        start = start,
        finish = length,
        quoted = true,
        closed = false
      }

      pos = length + 1
    else
      local finish = (text:find('%s', start) or length + 1) - 1

      tokens[#tokens + 1] = {
        value = text:sub(start, finish),
        start = start,
        finish = finish
      }

      pos = finish + 1
    end
  end

  return tokens
end

--- Splits a command string into arguments, the way `Flux.Command:tokenize` does.
-- ```
-- -- { 'ban', 'John Doe', '60', 'minging' }
-- local args = Flux.Command:extract_arguments('ban "John Doe" 60 minging')
-- ```
-- @param text [String]
-- @return [List<String> arguments, String text of the arguments after the first one, as it
--   was typed]
function Flux.Command:extract_arguments(text)
  local tokens = self:tokenize(text)
  local arguments = {}

  for index, token in ipairs(tokens) do
    arguments[index] = token.value
  end

  return arguments, (tokens[2] and text:sub(tokens[2].start) or '')
end

--- Returns a value the way it has to be typed as one argument: in double quotes if it is
-- empty or has whitespace in it.
-- @param value [String]
-- @return [String]
function Flux.Command:quote(value)
  value = tostring(value)

  if value == '' or value:find('%s') then
    return '"'..value..'"'
  end

  return value
end

--- Registers the completer of an argument type: the function that lists the values an
-- argument of that type can have, for the suggestions of `Flux.Command:complete`. Commands
-- use the type by naming it in their `arg_types`. The completer returns every value that
-- fits, as it has to be typed; the suggestions are narrowed down to what the player has
-- typed and sorted elsewhere, so the completer may ignore the partial text. Register
-- completers in a shared file, so that the client has them. Flux registers 'player' itself.
-- ```
-- -- plugins/factions/plugin/sh_plugin.lua
-- Flux.Command:add_completer('faction', function(actor, partial, args, cmd)
--   local ids = {}
--
--   for id in pairs(Factions.all()) do
--     ids[#ids + 1] = id
--   end
--
--   return ids
-- end)
-- ```
-- @param type_id [String ID of the argument type]
-- @param callback [Function(actor, partial, args, cmd) that returns a List<String> of values;
--   it gets the player who is typing (nil for the server console), the text typed for the
--   argument so far, a List<String> of the arguments before it and the Command or
--   subcommand the argument belongs to]
function Flux.Command:add_completer(type_id, callback)
  completers[type_id] = callback
end

--- Returns the completer of an argument type.
-- @param type_id [String ID of the argument type]
-- @return [Function the completer, or nil if the type has none]
-- @see [Flux.Command#add_completer]
function Flux.Command:get_completer(type_id)
  return completers[type_id]
end

--- Narrows suggestions down to the ones that contain the typed text, ignoring the case, and
-- writes them into a completion result: the ones that start with it first, then the others,
-- each in the order they were given. Duplicate values are left out.
-- @param result [Map completion result, see Flux.Command#complete]
-- @param entries [List<Map> suggestions: value (String), command (Command, optional) and
--   alias (Boolean true when the value is an alias of the command, optional)]
-- @param partial [String the typed text]
local function fill_candidates(result, entries, partial)
  local lower = partial:utf8lower()
  local prefixed, inner, seen = {}, {}, {}

  for _, entry in ipairs(entries) do
    local value = tostring(entry.value)

    if !seen[value] then
      local pos = value:utf8lower():find(lower, 1, true)

      if pos then
        seen[value] = true
        entry.value = value

        if pos == 1 then
          prefixed[#prefixed + 1] = entry
        else
          inner[#inner + 1] = entry
        end
      end
    end
  end

  for _, entry in ipairs(inner) do
    prefixed[#prefixed + 1] = entry
  end

  for index, entry in ipairs(prefixed) do
    result.candidates[index] = entry.value
    result.commands[index] = entry.command
    result.aliases[index] = entry.alias == true or nil
  end
end

local function starts_with(name, lower)
  return name:utf8lower():sub(1, #lower) == lower
end

--- Picks the name a command is suggested under: its ID if that starts with the typed text,
-- else the first of its aliases that does, ignoring the case. A command that neither its ID
-- nor an alias starts the text of is not suggested at all.
-- @param id [String command ID]
-- @param names [List<String> aliases of the command]
-- @param lower [String the typed text in lower case]
-- @return [String the name, or nil if none of them fits, Boolean true if the name is an
--   alias]
local function pick_name(id, names, lower)
  if starts_with(id, lower) then
    return id, false
  end

  for _, name in ipairs(names or {}) do
    if starts_with(name, lower) then
      return name, true
    end
  end
end

--- Sorts suggestions of commands: a name that is exactly what was typed first, then by name,
-- and an ID before an alias of the same name.
-- @param entries [List<Map> suggestions (value, command, alias), sorted in place]
-- @param lower [String the typed text in lower case]
local function sort_command_entries(entries, lower)
  table.sort(entries, function(a, b)
    local a_value, b_value = a.value:utf8lower(), b.value:utf8lower()
    local a_exact, b_exact = a_value == lower, b_value == lower

    if a_exact != b_exact then
      return a_exact
    end

    if a_value != b_value then
      return a_value < b_value
    end

    return !a.alias and b.alias == true
  end)
end

--- Lists the commands someone may run whose ID or one of whose aliases starts with the typed
-- text, each under the name it is suggested under.
-- @param actor [Player the player, or nil for the server console]
-- @param lower [String the typed text in lower case]
-- @return [List<Map> suggestions (value, command, alias), the exact match first, then sorted
--   by value]
local function command_entries(actor, lower)
  local entries = {}

  for id, cmd in pairs(stored) do
    if is_reachable(cmd, actor) then
      local value, is_alias = pick_name(id, cmd.aliases, lower)

      if value then
        entries[#entries + 1] = { value = value, command = cmd, alias = is_alias }
      end
    end
  end

  sort_command_entries(entries, lower)

  return entries
end

--- Lists the subcommands of a command someone may run, in the order they were added, each
-- under its ID, or under an alias that starts with the typed text if the ID does not.
-- @param actor [Player the player, or nil for the server console]
-- @param cmd [Command]
-- @param lower [String the typed text in lower case]
-- @return [List<Map> suggestions (value, command)]
local function subcommand_entries(actor, cmd, lower)
  local entries = {}

  for _, subcommand in ipairs(cmd:get_subcommands()) do
    if is_reachable(subcommand, actor) then
      local value, is_alias = pick_name(subcommand.id, subcommand.aliases, lower)

      if value then
        entries[#entries + 1] = { value = value, command = subcommand, alias = is_alias }
      end
    end
  end

  return entries
end

--- Lists the values an argument can have: the words of a list from `arg_types`, or what the
-- completer of its type returns.
-- @param actor [Player the player, or nil for the server console]
-- @param cmd [Command the command or subcommand the argument belongs to]
-- @param arg_type [String/List<String> the type of the argument]
-- @param partial [String the text typed for the argument so far]
-- @param args [List<String> the arguments before it]
-- @return [List<Map> suggestions (value)]
local function argument_entries(actor, cmd, arg_type, partial, args)
  local values

  if istable(arg_type) then
    values = arg_type
  elseif isstring(arg_type) and completers[arg_type] then
    local success, returned = pcall(completers[arg_type], actor, partial, args, cmd)

    if success then
      values = returned
    else
      ErrorNoHalt("[Flux:Command] The '"..arg_type.."' completer has failed: "..tostring(returned)..'\n')
    end
  end

  local entries = {}

  for index, value in ipairs(istable(values) and values or {}) do
    entries[index] = { value = value }
  end

  return entries
end

--- Works out what can be typed next in a command, for the suggestions of the chatbox and of
-- the console. The text is what has been typed after the command prefix, up to the caret.
-- The token that is completed is the last one, or a new one if the text ends with
-- whitespace; a double quote that is not closed makes the rest of the text that token. The
-- suggestions are the commands the player may run, the subcommands of the command that was
-- typed, or the values of its next argument: the words of a list from `arg_types` or what
-- the completer of the argument's type returns. Commands and subcommands the player may not
-- run are left out. A command or subcommand is suggested only when its ID or one of its
-- aliases starts with the typed text, ignoring the case: under its ID if that is the one,
-- else under the alias, which `aliases` marks. The name that is exactly what was typed comes
-- first, the others are sorted by name. The values of an argument are kept when they contain
-- the typed text, ignoring the case, those that start with it first, so that a player can be
-- found by any part of their name. Apply a suggestion with `Flux.Command:apply_completion`.
-- ```
-- local result = Flux.Command:complete('whitelist ad', PLAYER)
-- -- result.kind == 'subcommand', result.candidates == { 'add' }, result.start == 11
-- local text = Flux.Command:apply_completion('whitelist ad', result, 1)
-- -- text == 'whitelist add '
-- ```
-- @param text [String the typed text without the command prefix]
-- @param actor=nil [Player the player who is typing, for the permission checks; nil for the
--   server console]
-- @return [Map the result: kind (String 'command', 'subcommand' or 'argument'; nil when
--   nothing can be suggested because the command is unknown or not allowed, or a word that
--   is not one of its subcommands has been typed), partial (String
--   the typed text of the token, without its quote), start (Number position of the first
--   character of the token, its opening quote included, counted in characters), start_byte
--   (Number the same position in bytes), token_index (Number position of the token among all
--   of them, 1 for the command), command (Command the command or subcommand that has been
--   typed, nil while the command itself is typed), arg_index (Number position of the argument
--   that is typed, 1 for the first one after the command or subcommand word, nil while the
--   command is typed), arg_type (String/List<String> its type from `arg_types`, nil if it has
--   none), candidates (List<String> the suggestions, as values to be quoted by
--   apply_completion), commands (Map<Number, Command> the command or subcommand of the
--   suggestion at the same position, for the suggestions that are one) and aliases
--   (Map<Number, Boolean> true at the position of a suggestion that is an alias of its
--   command rather than its ID)]
-- @see [Flux.Command#add_completer]
function Flux.Command:complete(text, actor)
  text = isstring(text) and text or ''

  local tokens = self:tokenize(text, true)
  local count = #tokens
  local current = tokens[count]
  local open_quote = current and current.quoted and !current.closed

  if !current or (!open_quote and text:find('%s$')) then
    current = { value = '', start = #text + 1 }
    count += 1
    tokens[count] = current
  end

  local partial = current.value
  local lower = partial:utf8lower()
  local result = {
    partial = partial,
    start = char_count(text:sub(1, current.start - 1)) + 1,
    start_byte = current.start,
    token_index = count,
    candidates = {},
    commands = {},
    aliases = {}
  }

  if count == 1 then
    result.kind = 'command'

    fill_candidates(result, command_entries(actor, lower), partial)

    return result
  end

  local cmd = self:find_by_id(tokens[1].value)

  if !cmd then return result end

  local index

  cmd, index = descend(cmd, tokens, count - 1)

  if !is_reachable(cmd, actor) then return result end

  result.command = cmd

  local has_subcommands = cmd:has_subcommands()
  local takes_arguments = cmd:takes_arguments()

  if has_subcommands and index < count and !takes_arguments then return result end

  local entries = {}

  if has_subcommands and index == count then
    result.kind = 'subcommand'
    entries = subcommand_entries(actor, cmd, lower)
  end

  if takes_arguments or !has_subcommands then
    local args = {}

    for i = index, count - 1 do
      args[#args + 1] = tokens[i].value
    end

    result.kind = result.kind or 'argument'
    result.arg_index = count - index + 1
    result.arg_type = cmd:get_arg_type(result.arg_index)

    for _, entry in ipairs(argument_entries(actor, cmd, result.arg_type, partial, args)) do
      entries[#entries + 1] = entry
    end
  end

  fill_candidates(result, entries, partial)

  return result
end

--- Puts one of the suggestions of `Flux.Command:complete` in place of the token it was made
-- for, in double quotes if it has whitespace in it, and adds a space after it, so that the
-- suggestions for the next token can follow. Pass the same text that was completed; to cycle
-- through the suggestions, apply each one to that text in turn.
-- @param text [String the text that was passed to complete]
-- @param result [Map the result of complete]
-- @param index [Number position of the suggestion in result.candidates]
-- @return [String the new text, or the same text if there is no such suggestion]
function Flux.Command:apply_completion(text, result, index)
  local value = istable(result) and result.candidates[index]

  if value == nil then return text end

  return text:sub(1, result.start_byte - 1)..self:quote(value)..' '
end

--- Lists the players for an argument of the 'player' type, as their names have to be typed:
-- the character name of every player, sorted by name, and also the Steam name of a player
-- whose Steam name contains the typed text while their character name does not. Once the
-- typed text starts with 'STEAM_', it lists their SteamIDs instead.
-- @param _actor [Player the player who is typing]
-- @param partial [String the text typed for the argument so far]
-- @return [List<String>]
local function complete_player(_actor, partial)
  local lower = partial:utf8lower()
  local values = {}

  if lower:sub(1, 6) == 'steam_' then
    for _, client in player.Iterator() do
      values[#values + 1] = client:SteamID()
    end

    return values
  end

  for _, client in player.Iterator() do
    local char_name = client:name(true)
    local steam_name = client:steam_name()

    values[#values + 1] = char_name

    if lower != '' and steam_name != char_name and !char_name:utf8lower():find(lower, 1, true) and
       steam_name:utf8lower():find(lower, 1, true) then
      values[#values + 1] = steam_name
    end
  end

  table.sort(values, |a, b| -> a:utf8lower() < b:utf8lower())

  return values
end

Flux.Command:add_completer('player', complete_player)

if SERVER then
  local macros = {
    ['@'] = function(_actor, str)
      local group_name = str:utf8sub(2, utf8.len(str)):utf8lower()
      local to_ret = {}

      for _, client in player.Iterator() do
        if client:get_role_table().id == group_name then
          to_ret[#to_ret + 1] = client
        end
      end

      return to_ret, '@'
    end,
    ['('] = function(_actor, str)
      local name = str:utf8sub(2, utf8.len(str) - 1)
      local to_ret = player.find(name)

      if IsValid(to_ret) then
        to_ret = { to_ret }
      end

      if !istable(to_ret) then
        to_ret = {}
      end

      return to_ret, '('
    end,
    ['['] = function(_actor, str)
      local name = str:utf8sub(2, utf8.len(str) - 1)

      for _, client in player.Iterator() do
        if client:name() == name then
          return { client }, '['
        end
      end

      return false, '['
    end,
    ['^'] = function(actor, _str)
      if IsValid(actor) then
        return { actor }, '^'
      else
        return false, '^'
      end
    end,
    ['*'] = function(_actor, _str)
      return player.GetAll(), '*'
    end,
    ['!'] = function(actor, str)
      local radius = tonumber(str:utf8sub(2, utf8.len(str)))
      local to_ret = {}

      if !radius or radius < 0 or !IsValid(actor) then
        return to_ret, '!'
      end

      local radius_sqr = radius * radius

      for _, client in player.Iterator() do
        if client != actor and actor:GetPos():DistToSqr(client:GetPos()) <= radius_sqr then
          to_ret[#to_ret + 1] = client
        end
      end

      return to_ret, '!'
    end
  }

  --- Finds the players targeted by a command argument: the player with exactly this
  -- SteamID, character name or Steam name (see `player.find_exact`), or one of the following
  -- target selectors: '@group' (everyone in a user group), '(name)' (everyone with this text
  -- in their name), '[name]' (the player with exactly this name, in this case), '^'
  -- (yourself), '*' (everyone) and '!radius' (everyone within this distance from you).
  -- Plugins can add more by returning a parser function from the 'TargetFromString' hook. A
  -- name that several players have targets nobody. Serverside only.
  -- @param actor [Player the player who is running the command]
  -- @param str [String player name, SteamID or target selector]
  -- @return [List<Player> the targets, or false if nobody was found; String the selector
  --   character if one was used, or 'ambiguous' if several players have this name]
  function Flux.Command:str_to_player(actor, str)
    if !isstring(str) or str == '' then return false end

    local start = str:utf8sub(1, 1)
    --- Lets plugins add target selectors for the player argument of commands. Called on the
    -- server when the argument does not start with one of the built-in selector characters. If
    -- no function is returned, the argument is looked up as a player name.
    -- @param actor [Player the player who is running the command, an invalid entity for the
    --   server console]
    -- @param str [String the whole player argument]
    -- @param start [String first character of the argument]
    -- @return [Function Parser that is called with the actor and the argument; it returns a
    --   List<Player> of targets, or false if there are none, and the selector character]
    local parser = macros[start] or hook.Run('TargetFromString', actor, str, start)

    if isfunction(parser) then
      return parser(actor, str)
    end

    local found = player.find_exact(str)

    if #found == 1 then
      return found
    elseif #found > 1 then
      return false, 'ambiguous'
    end

    return false
  end

  --- Tells the player who runs a command about a problem with it. For the server console the
  -- message is printed as an error, with the string arguments translated.
  -- @param actor [Player the player, an invalid entity for the server console]
  -- @param phrase [String language phrase]
  -- @param args=nil [Map values to substitute into the phrase]
  local function command_error(actor, phrase, args)
    if IsValid(actor) then
      actor:notify(phrase, args)

      return
    end

    local translated = {}

    for key, value in pairs(args or {}) do
      translated[key] = isstring(value) and t(value) or value
    end

    ErrorNoHalt('[Flux:Command] '..t(phrase, translated)..'\n')
  end

  local function syntax_error(actor, cmd)
    command_error(actor, 'error.command.syntax', {
      command = cmd:get_full_name(),
      syntax = cmd:get_syntax()
    })
  end

  local function access_error(actor)
    if IsValid(actor) then
      actor:notify('error.command.no_access')
    else
      ErrorNoHalt('[Flux:Command] This command cannot be run from the console!\n')
    end
  end

  --- Replaces the arguments that have a list of words in `arg_types` with the word from the
  -- list they match, ignoring the case, and tells the player if one does not match any.
  -- @param actor [Player the player, an invalid entity for the server console]
  -- @param cmd [Command the command or subcommand]
  -- @param args [List<String> the arguments, changed in place]
  -- @return [Boolean true if every such argument matches]
  local function check_choices(actor, cmd, args)
    for i = 1, #args do
      local arg_type = cmd:get_arg_type(i)

      if istable(arg_type) then
        local value = args[i]:utf8lower()
        local found

        for _, choice in ipairs(arg_type) do
          if tostring(choice):utf8lower() == value then
            found = choice

            break
          end
        end

        if found == nil then
          command_error(actor, 'error.command.invalid_choice', {
            value = args[i],
            choices = table.concat(arg_type, ', ')
          })

          return false
        end

        args[i] = found
      end
    end

    return true
  end

  --- Turns the player argument of a command into the list of its targets and checks their
  -- immunity, telling the player if there is a problem.
  -- @param actor [Player the player, an invalid entity for the server console]
  -- @param cmd [Command the command or subcommand]
  -- @param target_arg [String the player argument]
  -- @return [List<Player> the targets, or nil if there are none or one of them is immune]
  local function find_targets(actor, cmd, target_arg)
    local found, kind = Flux.Command:str_to_player(actor, target_arg)
    local targets, cache = {}, {}

    if istable(found) then
      for _, target in ipairs(found) do
        if IsValid(target) and !cache[target] then
          cache[target] = true

          targets[#targets + 1] = target
        end
      end
    end

    if #targets == 0 then
      if kind == 'ambiguous' then
        command_error(actor, 'error.command.player_ambiguous', { player = target_arg })
      elseif kind == '^' and !IsValid(actor) then
        ErrorNoHalt('[Flux:Command] You cannot target yourself as console.\n')
      else
        command_error(actor, 'error.command.player_invalid', { player = target_arg })
      end

      return
    end

    if cmd.immunity and IsValid(actor) then
      for _, target in ipairs(targets) do
        --- Called for every player a command with `immunity` set is about to be run on, when
        -- the command was not run from the server console. The actor themselves can be among
        -- the targets; Bolt's handler always lets that pass, and lets root players
        -- target anyone.
        -- @param actor [Player Player who runs the command]
        -- @param target [Player Player the command targets]
        -- @param can_equal [Boolean The command's `can_equal` setting: whether a target of
        --   the same standing as the actor may be affected]
        -- @return [Boolean Return false if the target is immune to the actor; the command is
        --   then not run and the actor is notified]
        if hook.Run('CommandCheckImmunity', actor, target, cmd.can_equal) == false then
          actor:notify('error.command.higher_immunity', {
            target = get_player_name(target)
          })

          return
        end
      end
    end

    return targets
  end

  --- Parses a command string and runs the command on behalf of the specified player.
  -- Finds the command by its ID or alias and then its subcommand by the next word, both
  -- matched exactly in any case. Checks that the player has access to the command or
  -- subcommand, that enough arguments were given and that the arguments with a list of words
  -- in `arg_types` are one of them, resolves the targets and their immunity, logs the command
  -- and runs it. A trailing 'text' argument is passed on exactly as it was typed, see
  -- `Command:get_text_index`. The player is notified of any failure (it is printed to the
  -- console for the server console). Serverside only.
  -- @param actor [Player the player who runs the command, an invalid entity for server console]
  -- @param text [String command ID followed by its subcommand word, if any, and its arguments]
  -- @param from_console=nil [Boolean whether it was run as a console command, passed to the
  --   'PlayerCanRunCommand' hook]
  function Flux.Command:interpret(actor, text, from_console)
    if !isstring(text) then return end

    local actor_valid = IsValid(actor)
    local tokens = self:tokenize(text)

    if !tokens[1] then
      if !actor_valid then
        ErrorNoHalt('[Flux:Command] You must enter a command!\n')
      else
        actor:notify('error.command.you_must_enter_command')
      end

      return
    end

    local cmd_table = self:find_by_id(tokens[1].value)

    if !cmd_table then
      command_error(actor, 'error.command.not_valid', { command = tokens[1].value })

      return
    end

    local index

    cmd_table, index = descend(cmd_table, tokens, #tokens)

    if cmd_table:has_subcommands() then
      local word = tokens[index]

      if (word and !cmd_table:takes_arguments()) or (!word and !cmd_table:has_callback()) then
        if !is_reachable(cmd_table, actor) then
          access_error(actor)
        elseif word then
          local ids = {}

          for _, subcommand in ipairs(cmd_table:get_subcommands()) do
            ids[#ids + 1] = subcommand.id
          end

          command_error(actor, 'error.command.unknown_subcommand', {
            subcommand = word.value,
            command = cmd_table:get_full_name(),
            subcommands = table.concat(ids, ', ')
          })
        else
          syntax_error(actor, cmd_table)
        end

        return
      end
    end

    if !cmd_table:is_allowed(actor) then
      access_error(actor)

      return
    end

    local args = {}

    for i = index, #tokens do
      args[#args + 1] = tokens[i].value
    end

    local raw_args = tokens[index] and text:sub(tokens[index].start):gsub('%s+$', '') or ''

    --- Called on the server when a player is about to run a command, after the permission
    -- check has passed and before the arguments are checked. The player is not told when a
    -- handler stops the command, so the handler should notify them.
    -- @param actor [Player the player who runs the command, an invalid entity for the
    --   server console]
    -- @param cmd_table [Command the command that runs; for a subcommand this is the
    --   subcommand, and its `parent` is the command it belongs to]
    -- @param from_console [Boolean true if it was run as a console command, nil if it was
    --   typed in the chat]
    -- @return [Boolean Return false to stop the command from running; true and nil let it run]
    if hook.Run('PlayerCanRunCommand', actor, cmd_table, from_console) == false then return end

    if cmd_table.arguments > #args then
      syntax_error(actor, cmd_table)

      return
    end

    local text_index = cmd_table:get_text_index()
    local text_token = text_index and tokens[index + text_index - 1]

    if text_token then
      for i = #args, text_index + 1, -1 do
        args[i] = nil
      end

      if text_token.quoted and text_token.closed and !tokens[index + text_index] and
         !text_token.value:find('%S') then
        args[text_index] = ''
      else
        args[text_index] = (text:sub(text_token.start):gsub('%s+$', ''))
      end
    end

    if !check_choices(actor, cmd_table, args) then return end

    local targets = {}

    if cmd_table.immunity or isnumber(cmd_table.player_arg) then
      local target_index = isnumber(cmd_table.player_arg) and cmd_table.player_arg or 1
      local target_arg = args[target_index]

      if target_arg != nil then
        targets = find_targets(actor, cmd_table, target_arg)

        if !targets then return end

        args[target_index] = targets
      end
    end

    --- Called on the server right before a command is logged and run, after all of the
    -- checks have passed and its targets have been found. A handler that returns true takes
    -- the command over: the command is then neither logged nor run, and the handler is
    -- responsible for whatever it does in its place. Return nil to let the command run.
    -- Unlike `PlayerCanRunCommand`, the handler sees the parsed arguments and targets.
    -- @param actor [Player the player who runs the command, an invalid entity for the
    --   server console]
    -- @param cmd_table [Command the command that runs; for a subcommand this is the
    --   subcommand, and its `parent` is the command it belongs to]
    -- @param args [List arguments that are passed to `on_run`, without the subcommand word;
    --   for a command that targets players, the player argument is already a List<Player>]
    -- @return [Boolean Return true to take the command over; the player is not notified]
    if hook.Run('PlayerRunCommand', actor, cmd_table, args) then return end

    local full_name = cmd_table:get_full_name()
    local message
    local object = 'console'

    if actor_valid then
      message = actor:name()..' has used /'..full_name..(raw_args != '' and ' '..raw_args or '')
      object = actor.record and actor.record.id
    else
      message = 'Console ran '..full_name..(raw_args != '' and ' '..raw_args or '.')
    end

    Log:colored(
      command_log_color,
      message,
      'PlayerRunCommand',
      object,
      table.concat(
        table.map(targets, v -> IsValid(v) and v.record and v.record.id or nil),
        ','
      )
    ):replicate(listener -> listener:is_staff() and listener:can(cmd_table:get_permission()))

    self:run(actor, cmd_table, args, raw_args)
  end

  --- Calls the on_run callback of a command in protected mode. Assumes that the command
  -- is valid and that all of the permission checks have already been done. Serverside only.
  -- @param actor [Player the player who runs the command, an invalid entity for server console]
  -- @param cmd_table [Command the command or subcommand]
  -- @param arguments [List arguments to pass to on_run after the player]
  -- @param raw_args=nil [String raw text of the arguments, available to the callback
  --   as self.raw_args]
  function Flux.Command:run(actor, cmd_table, arguments, raw_args)
    if cmd_table.on_run then
      local old_raw_args = cmd_table.raw_args
      cmd_table.raw_args = raw_args

      local success, error_message = pcall(cmd_table.on_run, cmd_table, actor, unpack(arguments))

      cmd_table.raw_args = old_raw_args

      if !success then
        ErrorNoHalt(tostring(cmd_table)..' command has failed to run!\n')
        error_with_traceback(error_message)
      end
    end
  end

  Cable.receive('fl_command_run', function(actor, command)
    if command_throttled(actor) then return end

    Flux.Command:interpret(actor, command, true)
  end)
else
  --- Asks the server to run a command on behalf of the local player. Clientside only.
  -- ```
  -- Flux.Command:send('getup')
  -- ```
  -- @param command [String command ID followed by its arguments]
  function Flux.Command:send(command)
    Cable.send('fl_command_run', command)
  end
end

--- Powers the flc and flCmd console commands. Interprets the command on the server
-- and sends it to the server on the client.
-- @warning [Internal]
-- @param actor [Player the player who has run the console command]
-- @param _cmd [String name of the console command]
-- @param _args [List<String> arguments of the console command]
-- @param args_text [String arguments as a single string, the Flux command to run]
function Flux.Command.con_command(actor, _cmd, _args, args_text)
  if SERVER then
    if IsValid(actor) and command_throttled(actor) then return end

    Flux.Command:interpret(actor, args_text, true)
  else
    Flux.Command:send(args_text)
  end
end

--- Completes the flc and flCmd console commands with the suggestions of
-- `Flux.Command:complete`.
-- @warning [Internal]
-- @param cmd [String name of the console command]
-- @param args_text [String what has been typed after it]
-- @return [List<String> the console lines to offer]
function Flux.Command.con_autocomplete(cmd, args_text)
  local text = (tostring(args_text or ''):gsub('^%s+', ''))
  local result = Flux.Command:complete(text, CLIENT and LocalPlayer() or nil)
  local lines = {}

  for i = 1, #result.candidates do
    lines[i] = cmd..' '..Flux.Command:apply_completion(text, result, i)
  end

  return lines
end

concommand.Add('flCmd', Flux.Command.con_command, Flux.Command.con_autocomplete)
concommand.Add('flc', Flux.Command.con_command, Flux.Command.con_autocomplete)

Pipeline.register('commands', function(id, file_name, _pipe)
  if file_name:end_with('.lua') then
    local old_command = CMD
    CMD = Command.new(id)

    require_relative(file_name)

    CMD:register()
    CMD = old_command
  end
end)

Plugin.add_extra('commands')
