library.new('command', fl)

local stored = fl.command.stored or {}
local aliases = fl.command.aliases or {}
fl.command.stored = stored
fl.command.aliases = aliases

function fl.command:create(id, data)
  if !id or !data then return end

  data.id = id:to_id()
  data.name = data.name or 'Unknown'
  data.description = data.description or 'An undescribed command.'
  data.syntax = data.syntax or '[-]'
  data.immunity = data.immunity or false
  data.player_arg = data.player_arg or nil
  data.arguments = data.arguments or 0

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

function fl.command:find_by_id(id)
  id = id:utf8lower()

  if stored[id] then return stored[id] end
  if aliases[id] then return stored[aliases[id]] end
end

function fl.command:find(id)
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
function fl.command:find_all(id)
  local hits = {}
  local ids = {}

  for k, v in pairs(aliases) do
    if !ids[v] and (k:find(id) or v:find(id)) then
      if SERVER then
        table.insert(hits, stored[v])
      else
        if fl.client:can(v) then
          table.insert(hits, stored[v])
        end
      end

      ids[v] = true
    end
  end

  return hits
end

function fl.command:extract_arguments(text)
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
      local group_name = str:utf8sub(2, str:utf8len()):utf8lower()
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
      local name = str:utf8sub(2, str:utf8len() - 1)
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
      local name = str:utf8sub(2, str:utf8len() - 1)

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
      local radius = tonumber(str:utf8sub(2, str:utf8len()))
      local to_ret = {}

      for k, v in pairs(_player.GetAll()) do
        if v != player and player:GetPos():Distance(v:GetPos()) <= radius then
          table.insert(to_ret, v)
        end
      end

      return to_ret, '!'
    end
  }

  function fl.command:str_to_player(player, str)
    local start = str:utf8sub(1, 1)
    local parser = macros[start] or hook.run('TargetFromString', player, str, start)

    if isfunction(parser) then
      return parser(player, str)
    else
      local target = _player.find(str)

      if IsValid(target) then
        return { target }
      elseif istable(target) and #target > 0 then
        return target
      end
    end

    return false
  end

  function fl.command:interpret(player, text)
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
        fl.player:notify(player, 'commands.you_must_enter_command')
      end

      return
    end

    local command = args[1]:utf8lower()

    table.remove(args, 1)

    local cmd_table = self:find_by_id(command)

    if cmd_table then
      if (!IsValid(player) and !cmd_table.no_console) or player:can(cmd_table.id) then
        if cmd_table.arguments == 0 or cmd_table.arguments <= #args then
          if cmd_table.immunity or cmd_table.player_arg != nil then
            local target_arg = args[(cmd_table.player_arg or 1)]
            local targets = {}

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
                  fl.player:notify(player, t('commands.player_invalid', tostring(target_arg)))
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
                  fl.player:notify(player, t('commands.higher_immunity', v:name()))

                  return
                end
              end

              -- One step less for commands.
              args[cmd_table.player_arg or 1] = targets
            else
              if IsValid(player) then
                fl.player:notify(player, t('commands.player_invalid', tostring(target_arg)))
              else
                ErrorNoHalt("'"..tostring(target_arg).."' is not a valid player!\n")
              end

              return
            end
          end

          -- Let plugins hook into this and abort command's execution if necessary.
          if !hook.run('PlayerRunCommand', player, cmd_table, args) then
            if IsValid(player) then
              ServerLog(player:name()..' has used /'..cmd_table.name..' '..text:utf8sub(string.utf8len(command) + 2, string.utf8len(text)))
            end

            self:run(player, cmd_table, args)
          end
        else
          fl.player:notify(player, '/'..cmd_table.name..' '..cmd_table.syntax)
        end
      else
        if IsValid(player) then
          fl.player:notify(player, 'commands.no_access')
        else
          ErrorNoHalt('This command cannot be run from console!\n')
        end
      end
    else
      if IsValid(player) then
        fl.player:notify(player, t('commands.not_valid', command))
      else
        ErrorNoHalt("'"..command.."' is not a valid command!\n")
      end
    end
  end

  -- Warning: this function assumes that command is valid and all permission checks have been done.
  function fl.command:run(player, cmd_table, arguments)
    if cmd_table.on_run then
      try {
        cmd_table.on_run, cmd_table, player, unpack(arguments)
      } catch {
        function(exception)
          ErrorNoHalt("'"..cmd_table.id.."' command has failed to run!\n")
          ErrorNoHalt(exception..'\n')
        end
      }
    end
  end

  cable.receive('Flux::Command::Run', function(player, command)
    fl.command:interpret(player, command)
  end)
else
  function fl.command:send(command)
    cable.send('Flux::Command::Run', command)
  end
end

-- An internal function that powers the flc and flCmd console commands.
function fl.command.con_command(player, cmd, args, args_text)
  if SERVER then
    fl.command:interpret(player, args_text)
  else
    fl.command:send(args_text)
  end
end

concommand.Add('flCmd', fl.command.con_command)
concommand.Add('flc', fl.command.con_command)
