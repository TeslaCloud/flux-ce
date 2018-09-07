if CLIENT then
  library.new("binds", fl)

  local keyEnums = fl.binds.keyEnums or {}
  local stored = fl.binds.stored or {}
  fl.binds.keyEnums = keyEnums
  fl.binds.stored = stored

  if #keyEnums == 0 then
    for k, v in pairs(_G) do
      if string.sub(k, 1, 6) == "MOUSE_" then
        keyEnums[v] = k
      elseif string.sub(k, 1, 4) == "KEY_" then
        keyEnums[v] = k
      end
    end
  end

  function fl.binds:GetEnums()
    return keyEnums
  end

  function fl.binds:GetAll()
    return stored
  end

  function fl.binds:GetBound()
    local binds = {}

    for k, v in pairs(keyEnums) do
      local bind = input.LookupKeyBinding(k)

      if !tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function fl.binds:GetUnbound()
    local binds = {}

    for k, v in pairs(keyEnums) do
      local bind = input.LookupKeyBinding(k)

      if tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function fl.binds:GetBind(nKey)
    return stored[nKey]
  end

  function fl.binds:SetBind(command, nKey)
    for k, v in pairs(stored) do
      if v == command then
        stored[k] = nil
      end
    end

    stored[nKey] = command
  end

  function fl.binds:AddBind(id, command, key)
    self:SetBind(command, key)
  end
end

local hooks = {}

if SERVER then
  function hooks:PlayerButtonDown(player, nKey)
    netstream.Start(player, "FLBindPressed", nKey)
  end
else
  netstream.Hook("FLBindPressed", function(nKey)
    local bind = fl.binds:GetBind(nKey)

    if bind then
      RunConsoleCommand(bind)
    end
  end)
end

plugin.add_hooks("FLBinds", hooks)
