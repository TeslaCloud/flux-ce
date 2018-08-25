library.new("command", fl)

local stored = fl.command.stored or {}
local aliases = fl.command.aliases or {}

fl.command.stored = stored
fl.command.aliases = aliases

function fl.command:Create(id, data)
  if (!id or !data) then return end

  data.id = id:to_id()
  data.name = data.name or "Unknown"
  data.description = data.description or "An undescribed command."
  data.syntax = data.syntax or "[none]"
  data.immunity = data.immunity or false
  data.player_arg = data.player_arg or nil
  data.arguments = data.arguments or 0

  stored[id] = data

  -- Add original command name to the aliases table.
  aliases[id] = data.id

  if (data.aliases) then
    for k, v in ipairs(data.aliases) do
      aliases[v] = id
    end
  end

  hook.Run("OnCommandCreated", id, data)
end

function fl.command:FindByID(id)
  id = id:utf8lower()

  if (stored[id]) then return stored[id] end
  if (aliases[id]) then return stored[aliases[id]] end
end

function fl.command:Find(id)
  id = id:utf8lower()

  local found = self:FindByID(id)

  if (found) then
    return found
  end

  for k, v in pairs(aliases) do
    if (k:find(id)) then
      return stored[v]
    end
  end
end

-- A function to find all commands by given search string.
function fl.command:FindAll(id)
  local hits = {}
  local ids = {}

  for k, v in pairs(aliases) do
    if (!ids[v] and (k:find(id) or v:find(id))) then
      if SERVER then
        table.insert(hits, stored[v])
      else
        if (fl.client:HasPermission(v)) then
          table.insert(hits, stored[v])
        end
      end

      ids[v] = true
    end
  end

  return hits
end

function fl.command:ExtractArguments(text)
  local arguments = {}
  local word = ""
  local skip = 0

  for i = 1, #text do
    if (skip > 0) then
      skip = skip - 1

      continue
    end

    local char = text:utf8sub(i, i)

    if ((char == "\"" or char == "'" or char == "{") and word == "") then
      local endPos = text:find("\"", i + 1)
      local isTable = false

      if (!endPos) then
        endPos = text:find("'", i + 1)

        if (!endPos) then
          endPos = text:find("}", i + 1)
          isTable = true
        end
      end

      if (endPos) then
        if (!isTable) then
          table.insert(arguments, text:utf8sub(i + 1, endPos - 1))
        else
          local text = text:utf8sub(i, endPos)
          local tab = util.BuildTableFromString(text)

          if (tab) then
            table.insert(arguments, tab)
          else
            table.insert(arguments, text)
          end
        end

        skip = endPos - i
      else
        word = word..char
      end
    elseif (char == " ") then
      if (word != "") then
        table.insert(arguments, word)
        word = ""
      end
    else
      word = word..char
    end
  end

  if (word != "") then
    table.insert(arguments, word)
  end

  return arguments
end

if SERVER then
  local macros = {
    -- Target everyone in a user group.
    ["@"] = function(player, str)
      local groupName = str:utf8sub(2, str:utf8len()):utf8lower()
      local toReturn = {}

      for k, v in ipairs(_player.GetAll()) do
        if (v:GetUserGroup() == groupName) then
          table.insert(toReturn, v)
        end
      end

      return toReturn, "@"
    end,
    -- Target everyone with str in their name.
    ["("] = function(player, str)
      local name = str:utf8sub(2, str:utf8len() - 1)
      local toReturn = _player.Find(name)

      if (IsValid(toReturn)) then
        toReturn = {toReturn}
      end

      if (!istable(toReturn)) then
        toReturn = {}
      end

      return toReturn, "("
    end,
    -- Target the first person whose nick is exactly str.
    ["["] = function(player, str)
      local name = str:utf8sub(2, str:utf8len() - 1)

      for k, v in ipairs(_player.GetAll()) do
        if (v:Name() == name) then
          return {v}, "["
        end
      end

      return false, "["
    end,
    -- Target yourself.
    ["^"] = function(player, str)
      if (IsValid(player)) then
        return {player}, "^"
      else
        return false, "^"
      end
    end,
    -- Target everyone.
    ["*"] = function(player, str)
      return _player.GetAll(), "*"
    end
  }

  function fl.command:PlayerFromString(player, str)
    local start = str:utf8sub(1, 1)
    local parser = macros[start] or hook.Run("TargetFromString", player, str, start)

    if (isfunction(parser)) then
      return parser(player, str)
    else
      local target = _player.Find(str)

      if (IsValid(target)) then
        return {target}
      elseif (istable(target) and #target > 0) then
        return target
      end
    end

    return false
  end

  function fl.command:Interpret(player, text)
    local args

    if (isstring(text)) then
      args = self:ExtractArguments(text)
    else
      return
    end

    if (!isstring(args[1])) then
      if (!IsValid(player)) then
        ErrorNoHalt("[Flux:Command] You must enter a command!\n")
      else
        fl.player:Notify(player, "#Commands_YouMustEnterCommand")
      end

      return
    end

    local command = args[1]:utf8lower()

    table.remove(args, 1)

    local cmdTable = self:FindByID(command)

    if (cmdTable) then
      if ((!IsValid(player) and !cmdTable.no_console) or player:HasPermission(cmdTable.id)) then
        if (cmdTable.arguments == 0 or cmdTable.arguments <= #args) then
          if (cmdTable.immunity or cmdTable.player_arg != nil) then
            local targetArg = args[(cmdTable.player_arg or 1)]
            local targets = {}

            if (istable(targetArg)) then
              local cache = {}

              for k, v in pairs(targetArg) do
                local target, kind = self:PlayerFromString(player, v)

                if (istable(target)) then
                  for k2, v2 in ipairs(target) do
                    if (IsValid(v2) and !cache[v2]) then
                      cache[v2] = true

                      table.insert(targets, v2)
                    end
                  end
                end
              end
            else
              local target, kind = self:PlayerFromString(player, targetArg)
              local cache = {}

              if (istable(target)) then
                for k, v in ipairs(target) do
                  if (IsValid(v) and !cache[v]) then
                    cache[v] = true

                    table.insert(targets, v)
                  end
                end
              else
                if (IsValid(player)) then
                  fl.player:Notify(player, L("Commands_PlayerInvalid", tostring(targetArg)))
                else
                  if (kind != "^") then
                    ErrorNoHalt("'"..tostring(targetArg).."' is not a valid player!")
                  else
                    ErrorNoHalt("[Flux:Command] You cannot target yourself as console.")
                  end
                end

                return
              end
            end

            if (istable(targets) and #targets > 0) then
              for k, v in ipairs(targets) do
                if (cmdTable.immunity and IsValid(player) and hook.Run("CommandCheckImmunity", player, v, cmdTable.canBeEqual) == false) then
                  fl.player:Notify(player, L("Commands_HigherImmunity", v:Name()))

                  return
                end
              end

              -- One step less for commands.
              args[cmdTable.player_arg or 1] = targets
            else
              if (IsValid(player)) then
                fl.player:Notify(player, L("Commands_PlayerInvalid", tostring(targetArg)))
              else
                ErrorNoHalt("'"..tostring(targetArg).."' is not a valid player!\n")
              end

              return
            end
          end

          -- Let plugins hook into this and abort command's execution if necessary.
          if (!hook.Run("PlayerRunCommand", player, cmdTable, args)) then
            if (IsValid(player)) then
              ServerLog(player:Name().." has used /"..cmdTable.name.." "..text:utf8sub(string.utf8len(command) + 2, string.utf8len(text)))
            end

            self:Run(player, cmdTable, args)
          end
        else
          fl.player:Notify(player, "/"..cmdTable.name.." "..cmdTable.syntax)
        end
      else
        if (IsValid(player)) then
          fl.player:Notify(player, "#Commands_NoAccess")
        else
          ErrorNoHalt("This command cannot be run from console!\n")
        end
      end
    else
      if (IsValid(player)) then
        fl.player:Notify(player, L("Commands_NotValid", command))
      else
        ErrorNoHalt("'"..command.."' is not a valid command!\n")
      end
    end
  end

  -- Warning: this function assumes that command is valid and all permission checks have been done.
  function fl.command:Run(player, cmdTable, arguments)
    if (cmdTable.OnRun) then
      try {
        cmdTable.OnRun, cmdTable, player, unpack(arguments)
      } catch {
        function(exception)
          ErrorNoHalt(""..cmdTable.id.." command has failed to run!\n")
          ErrorNoHalt(exception.."\n")
        end
      }
    end
  end

  netstream.Hook("Flux::Command::Run", function(player, command)
    fl.command:Interpret(player, command)
  end)
else
  function fl.command:Send(command)
    netstream.Start("Flux::Command::Run", command)
  end
end

-- An internal function that powers the flc and flCmd console commands.
function fl.command.ConCommand(player, cmd, args, argsText)
  if SERVER then
    fl.command:Interpret(player, argsText)
  else
    fl.command:Send(argsText)
  end
end

concommand.Add("flCmd", fl.command.ConCommand)
concommand.Add("flc", fl.command.ConCommand)
