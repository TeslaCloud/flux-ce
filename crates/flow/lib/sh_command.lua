mod 'Flux::Command'

local command_log_color = Color('orange')
local stored            = Flux.Command.stored   or {}
local aliases           = Flux.Command.aliases  or {}
Flux.Command.stored     = stored
Flux.Command.aliases    = aliases

--- Registers a command along with its aliases, fills in the defaults for missing fields,
-- and runs the 'OnCommandCreated' hook. Commands defined in the 'commands' folder of
-- a plugin are registered automatically, see Command#on_run for an example.
-- @param id [String unique command ID, also the main name it is called by]
-- @param data [Command/Hash command object or a table with the same fields: name, description,
--   syntax, permission, arguments (minimum amount), immunity, player_arg, alias or aliases,
--   no_console and the on_run callback]
-- @see [Command#on_run]
function Flux.Command:create(id, data)
  if !id or !data then return end

  data.id           = id:to_id()
  data.name         = data.name         or 'Unknown'
  data.syntax       = data.syntax       or '[-]'
  data.immunity     = data.immunity     or false
  data.arguments    = data.arguments    or 0
  data.permission   = data.permission   or 'user'
  data.player_arg   = data.player_arg   or nil
  data.description  = data.description  or 'An undescribed command.'

  stored[id] = data

  -- Add the original command name to the aliases table.
  aliases[id] = data.id

  if isstring(data.alias) then
    data.aliases = { data.alias }
  end

  if data.aliases then
    for k, v in ipairs(data.aliases) do
      aliases[v] = id
    end
  end

  hook.run('OnCommandCreated', id, data)
end

--- Finds a command by its exact ID or alias, ignoring the case.
-- @param id [String command ID or alias]
-- @return [Command the command, or nil if there is no such command]
function Flux.Command:find_by_id(id)
  id = id:utf8lower()

  if stored[id] then return stored[id] end
  if aliases[id] then return stored[aliases[id]] end
end

--- Finds a command by its ID or alias. If there is no exact match, returns the first
-- command that has an alias containing the specified string.
-- @param id [String full or partial command ID or alias, treated as a Lua pattern]
-- @return [Command the command, or nil if nothing was found]
function Flux.Command:find(id)
  id = id:utf8lower()

  local found = self:find_by_id(id)

  if found then
    return found
  end

  for k, v in pairs(aliases) do
    if k:find(id) then
      return stored[v]
    end
  end
end

--- Finds all of the commands that have the search string in their ID or aliases.
-- On the client only the commands the local player has access to are returned.
-- @param id [String search string]
-- @return [Array<Command> matching commands]
function Flux.Command:find_all(id)
  local hits = {}
  local ids = {}

  for k, v in pairs(aliases) do
    if !ids[v] and (k:include(id) or v:include(id)) then
      if SERVER then
        table.insert(hits, stored[v])
      else
        if PLAYER:can(v) then
          table.insert(hits, stored[v])
        end
      end

      ids[v] = true
    end
  end

  return hits
end

--- Splits a command string into arguments. Arguments are separated by spaces, quoted text
-- is treated as a single argument.
-- ```
-- -- { 'ban', 'John Doe', '60', 'minging' }
-- local args = Flux.Command:extract_arguments('ban "John Doe" 60 minging')
-- ```
-- @param text [String]
-- @return [Array<String> arguments, String raw text of the arguments]
function Flux.Command:extract_arguments(text)
  local raw_args
  local arguments = {}
  local word = ''
  local skip = 0
  local tlen = string.len(text)

  for i = 1, tlen do
    if raw_args == nil and #arguments > 0 then
      raw_args = string.sub(i, tlen)
    end

    if skip > 0 then
      skip = skip - 1

      continue
    end

    local char = text:utf8sub(i, i)

    if (char == '"' or char == "'") and word == '' then
      local end_pos = text:find('"', i + 1)

      if !end_pos then
        end_pos = text:find("'", i + 1)
      end

      if end_pos then
        table.insert(arguments, text:utf8sub(i + 1, end_pos - 1))
        skip = end_pos - i
      else
        word = word..char
      end
    elseif char == ' ' then
      if word != '' then
        table.insert(arguments, word)
        word = ''
      end
    else
      word = word..char
    end
  end

  if word != '' then
    table.insert(arguments, word)
  end

  return arguments, (raw_args or '')
end

if SERVER then
  local macros = {
    -- Target everyone in a user group.
    ['@'] = function(player, str)
      local group_name = str:utf8sub(2, utf8.len(str)):utf8lower()
      local to_ret = {}

      for k, v in ipairs(_player.all()) do
        if v:GetUserGroup() == group_name then
          table.insert(to_ret, v)
        end
      end

      return to_ret, '@'
    end,
    -- Target everyone with str in their name.
      ['('] = function(player, str)
      local name = str:utf8sub(2, utf8.len(str) - 1)
      local to_ret = _player.find(name)

      if IsValid(to_ret) then
        to_ret = { to_ret }
      end

      if !istable(to_ret) then
        to_ret = {}
      end

      return to_ret, '('
    end,
    -- Target the first person whose nick is exactly str.
    ['['] = function(player, str)
      local name = str:utf8sub(2, utf8.len(str) - 1)

      for k, v in ipairs(_player.all()) do
        if v:name() == name then
          return { v }, '['
        end
      end

      return false, '['
    end,
    -- Target yourself.
    ['^'] = function(player, str)
      if IsValid(player) then
        return { player }, '^'
      else
        return false, '^'
      end
    end,
    -- Target everyone.
    ['*'] = function(player, str)
      return _player.all(), '*'
    end,
    -- Target all players in radius.
    ['!'] = function(player, str)
      local radius = tonumber(str:utf8sub(2, utf8.len(str)))
      local to_ret = {}

      for k, v in pairs(_player.all()) do
        if v != player and player:GetPos():Distance(v:GetPos()) <= radius then
          table.insert(to_ret, v)
        end
      end

      return to_ret, '!'
    end
  }

  --- Finds the players targeted by a command argument. Other than a player's name the following
  -- target selectors are supported: '@group' (everyone in a user group), '(name)' (everyone
  -- with this text in their name), '[name]' (the player with exactly this name), '^' (yourself),
  -- '*' (everyone) and '!radius' (everyone within this distance from you). Plugins can add
  -- more by returning a parser function from the 'TargetFromString' hook. Serverside only.
  -- @param player [Player the player who is running the command]
  -- @param str [String player name or target selector]
  -- @return [Array<Player> the targets, or false if nobody was found; String the selector
  --   character, if one was used]
  function Flux.Command:str_to_player(player, str)
    local start = str:utf8sub(1, 1)
    local parser = macros[start] or hook.run('TargetFromString', player, str, start)

    if isfunction(parser) then
      return parser(player, str)
    else
      local target = _player.find(str)

      if IsValid(target) then
        return { target }
      elseif istable(target) and #target > 0 then
        return { target[1] }
      end
    end

    return false
  end

  --- Parses a command string and runs the command on behalf of the specified player.
  -- Checks that the command exists, that the player has access to it and has provided enough
  -- arguments, resolves the targets and their immunity, and logs the command. The player
  -- is notified of any failure (it is printed to the console for the server console).
  -- Serverside only.
  -- @param player [Player the player who runs the command, an invalid entity for server console]
  -- @param text [String command ID followed by its arguments]
  -- @param from_console=nil [Boolean whether it was run as a console command, passed to the
  --   'PlayerCanRunCommand' hook]
  function Flux.Command:interpret(player, text, from_console)
    local args, raw_args

    if isstring(text) then
      args, raw_args = self:extract_arguments(text)
    else
      return
    end

    if !isstring(args[1]) then
      if !IsValid(player) then
        ErrorNoHalt('[Flux:Command] You must enter a command!\n')
      else
        player:notify('error.command.you_must_enter_command')
      end

      return
    end

    local command = args[1]:utf8lower()

    table.remove(args, 1)

    local cmd_table = self:find_by_id(command)

    if cmd_table then
      if (!IsValid(player) and !cmd_table.no_console) or player:can(cmd_table.id) then
        if hook.run('PlayerCanRunCommand', player, cmd_table, from_console) != nil then return end

        if cmd_table.arguments == 0 or cmd_table.arguments <= #args then
          local targets = {}

          if cmd_table.immunity or cmd_table.player_arg != nil then
            local target_arg = args[(cmd_table.player_arg or 1)]

            if istable(target_arg) then
              local cache = {}

              for k, v in pairs(target_arg) do
                local target, kind = self:str_to_player(player, v)

                if istable(target) then
                  for k2, v2 in ipairs(target) do
                    if IsValid(v2) and !cache[v2] then
                      cache[v2] = true

                      table.insert(targets, v2)
                    end
                  end
                end
              end
            else
              local target, kind = self:str_to_player(player, target_arg)
              local cache = {}

              if istable(target) then
                for k, v in ipairs(target) do
                  if IsValid(v) and !cache[v] then
                    cache[v] = true

                    table.insert(targets, v)
                  end
                end
              else
                if IsValid(player) then
                  player:notify('error.command.player_invalid', {
                    player = tostring(target_arg)
                  })
                else
                  if kind != '^' then
                    ErrorNoHalt("'"..tostring(target_arg).."' is not a valid player!")
                  else
                    ErrorNoHalt('[Flux:Command] You cannot target yourself as console.')
                  end
                end

                return
              end
            end

            if istable(targets) and #targets > 0 then
              for k, v in ipairs(targets) do
                if cmd_table.immunity and IsValid(player) and hook.run('CommandCheckImmunity', player, v, cmd_table.can_equal) == false then
                  player:notify('error.command.higher_immunity', {
                    target = get_player_name(v)
                  })

                  return
                end
              end

              -- One step less for commands.
              args[cmd_table.player_arg or 1] = targets
            else
              if IsValid(player) then
                player:notify('error.command.player_invalid', {
                  player = tostring(target_arg)
                })
              else
                ErrorNoHalt("'"..tostring(target_arg).."' is not a valid player!\n")
              end

              return
            end
          end

          -- Let plugins hook into this and abort the command's execution if necessary.
          if !hook.run('PlayerRunCommand', player, cmd_table, args) then
            local message

            if IsValid(player) then
              message = player:name()..' has used /'..cmd_table.name..' '..text:utf8sub(utf8.len(command) + 2, utf8.len(text))
            else
              message = 'Console has issued the '..cmd_table.name..' command'

              local arg_str = text:sub(string.len(command) + 2, string.len(text))

              if arg_str and arg_str:gsub(' ', '') != '' then
                message = message..' with the following arguments: '..arg_str
              else
                message = message..'.'
              end
            end

            Log:colored(
              command_log_color,
              message,
              'PlayerRunCommand',
              IsValid(player) and player.record.id or 'console',
              table.concat(
                table.map(targets, function(v)
                  return IsValid(v) and v.record and v.record.id
                end),
                ','
              )
            ):replicate(function(listener)
              return listener:is_staff() and listener:can(cmd_table.id)
            end)

            self:run(player, cmd_table, args, raw_args)
          end
        else
          player:notify('error.command.syntax', {
            command = cmd_table.name,
            syntax = cmd_table.syntax
          })
        end
      else
        if IsValid(player) then
          player:notify('error.command.no_access')
        else
          ErrorNoHalt('This command cannot be run from the console!\n')
        end
      end
    else
      if IsValid(player) then
        player:notify('error.command.not_valid', {
          command = command
        })
      else
        ErrorNoHalt("'"..command.."' is not a valid command!\n")
      end
    end
  end

  --- Calls the on_run callback of a command in protected mode. Assumes that the command
  -- is valid and that all of the permission checks have already been done. Serverside only.
  -- @param player [Player the player who runs the command, an invalid entity for server console]
  -- @param cmd_table [Command]
  -- @param arguments [Array arguments to pass to on_run after the player]
  -- @param raw_args=nil [String raw text of the arguments, available to the callback
  --   as self.raw_args]
  function Flux.Command:run(player, cmd_table, arguments, raw_args)
    if cmd_table.on_run then
      local old_raw_args = cmd_table.raw_args
      cmd_table.raw_args = raw_args

      local success, error_message = pcall(cmd_table.on_run, cmd_table, player, unpack(arguments))

      cmd_table.raw_args = old_raw_args

      if !success then
        ErrorNoHalt(tostring(cmd_table)..' command has failed to run!\n')
        error_with_traceback(error_message)
      end
    end
  end

  Cable.receive('fl_command_run', function(player, command)
    Flux.Command:interpret(player, command, true)
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
-- @param player [Player the player who has run the console command]
-- @param cmd [String name of the console command]
-- @param args [Array<String> arguments of the console command]
-- @param args_text [String arguments as a single string, the Flux command to run]
function Flux.Command.con_command(player, cmd, args, args_text)
  if SERVER then
    Flux.Command:interpret(player, args_text, true)
  else
    Flux.Command:send(args_text)
  end
end

concommand.Add('flCmd', Flux.Command.con_command)
concommand.Add('flc', Flux.Command.con_command)

Pipeline.register('commands', function(id, file_name, pipe)
  if file_name:ends('.lua') then
    local old_command = CMD
    CMD = Command.new(id)

    require_relative(file_name)

    CMD:register()
    CMD = old_command
  end
end)

Plugin.add_extra('commands')
