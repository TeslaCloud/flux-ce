library 'Flux::Command'

local command_log_color = Color('orange')
local stored            = Flux.Command.stored   or {}
local aliases           = Flux.Command.aliases  or {}
Flux.Command.stored     = stored
Flux.Command.aliases    = aliases

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

  -- Add original command name to the aliases table.
  aliases[id] = data.id

  if data.aliases then
    for k, v in ipairs(data.aliases) do
      aliases[v] = id
    end
  end

  hook.run('OnCommandCreated', id, data)
end

function Flux.Command:find_by_id(id)
  id = id:utf8lower()

  if stored[id] then return stored[id] end
  if aliases[id] then return stored[aliases[id]] end
end

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

-- A function to find all commands by given search string.
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

function Flux.Command:extract_arguments(text)
  local arguments = {}
  local word = ''
  local skip = 0

  for i = 1, #text do
    if skip > 0 then
      skip = skip - 1

      continue
    end

    local char = text:utf8sub(i, i)

    if (char == '"' or char == "'" or char == '{') and word == '' then
      local end_pos = text:find('"', i + 1)
      local is_table = false

      if !end_pos then
        end_pos = text:find("'", i + 1)

        if !end_pos then
          end_pos = text:find('}', i + 1)
          is_table = true
        end
      end

      if end_pos then
        if !is_table then
          table.insert(arguments, text:utf8sub(i + 1, end_pos - 1))
        else
          local text = text:utf8sub(i, end_pos)
          local tab = table.from_string(text)

          if tab then
            table.insert(arguments, tab)
          else
            table.insert(arguments, text)
          end
        end

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

  return arguments
end

if SERVER then
  local macros = {
    -- Target everyone in a user group.
    ['@'] = function(player, str)
      local group_name = str:utf8sub(2, utf8.len(str)):utf8lower()
      local to_ret = {}

      for k, v in ipairs(_player.GetAll()) do
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

      for k, v in ipairs(_player.GetAll()) do
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
      return _player.GetAll(), '*'
    end,
    -- Target all players in radius.
    ['!'] = function(player, str)
      local radius = tonumber(str:utf8sub(2, utf8.len(str)))
      local to_ret = {}

      for k, v in pairs(_player.GetAll()) do
        if v != player and player:GetPos():Distance(v:GetPos()) <= radius then
          table.insert(to_ret, v)
        end
      end

      return to_ret, '!'
    end
  }

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

  function Flux.Command:interpret(player, text, from_console)
    local args

    if isstring(text) then
      args = self:extract_arguments(text)
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

          -- Let plugins hook into this and abort command's execution if necessary.
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

            self:run(player, cmd_table, args)
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
          ErrorNoHalt('This command cannot be run from console!\n')
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

  -- Warning: this function assumes that command is valid and all permission checks have been done.
  function Flux.Command:run(player, cmd_table, arguments)
    if cmd_table.on_run then
      try {
        cmd_table.on_run, cmd_table, player, unpack(arguments)
      } catch {
        function(exception)
          ErrorNoHalt("'"..cmd_table.id.."' command has failed to run!\n")
          error_with_traceback(exception)
        end
      }
    end
  end

  Cable.receive('fl_command_run', function(player, command)
    Flux.Command:interpret(player, command, true)
  end)
else
  function Flux.Command:send(command)
    Cable.send('fl_command_run', command)
  end
end

-- An internal function that powers the flc and flCmd console commands.
function Flux.Command.con_command(player, cmd, args, args_text)
  if SERVER then
    Flux.Command:interpret(player, args_text, true)
  else
    Flux.Command:send(args_text)
  end
end

concommand.Add('flCmd', Flux.Command.con_command)
concommand.Add('flc', Flux.Command.con_command)
