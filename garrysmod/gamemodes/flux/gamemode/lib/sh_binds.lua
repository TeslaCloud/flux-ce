if CLIENT then
  library.new('binds', fl)

  local key_enums = fl.binds.key_enums or {}
  local stored = fl.binds.stored or {}
  fl.binds.key_enums = key_enums
  fl.binds.stored = stored

  if #key_enums == 0 then
    for k, v in pairs(_G) do
      if string.sub(k, 1, 6) == 'MOUSE_' then
        key_enums[v] = k
      elseif string.sub(k, 1, 4) == 'KEY_' then
        key_enums[v] = k
      end
    end
  end

  function fl.binds:GetEnums()
    return key_enums
  end

  function fl.binds:GetAll()
    return stored
  end

  function fl.binds:GetBound()
    local binds = {}

    for k, v in pairs(key_enums) do
      local bind = input.LookupKeyBinding(k)

      if !tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function fl.binds:GetUnbound()
    local binds = {}

    for k, v in pairs(key_enums) do
      local bind = input.LookupKeyBinding(k)

      if tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function fl.binds:GetBind(key)
    return stored[key]
  end

  function fl.binds:SetBind(command, key)
    for k, v in pairs(stored) do
      if v == command then
        stored[k] = nil
      end
    end

    stored[key] = command
  end

  function fl.binds:AddBind(id, command, key)
    self:SetBind(command, key)
  end
end

local hooks = {}

if SERVER then
  function hooks:PlayerButtonDown(player, key)
    cable.send(player, 'FLBindPressed', key)
  end
else
  cable.receive('FLBindPressed', function(key)
    local bind = fl.binds:GetBind(key)

    if bind then
      RunConsoleCommand(bind)
    end
  end)
end

plugin.add_hooks('FLBinds', hooks)
