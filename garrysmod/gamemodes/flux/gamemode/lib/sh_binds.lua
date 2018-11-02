if CLIENT then
  library.new('binds', fl)

  local stored = fl.binds.stored or {}
  local key_enums = fl.binds.key_enums or {}
  fl.binds.stored = stored
  fl.binds.key_enums = key_enums

  if #key_enums == 0 then
    for k, v in pairs(_G) do
      if string.sub(k, 1, 6) == 'MOUSE_' then
        key_enums[v] = k
      elseif string.sub(k, 1, 4) == 'KEY_' then
        key_enums[v] = k
      end
    end
  end

  function fl.binds:get_enums()
    return key_enums
  end

  function fl.binds:get_all()
    return stored
  end

  function fl.binds:get_bound()
    local binds = {}

    for k, v in pairs(key_enums) do
      local bind = input.LookupKeyBinding(k)

      if !tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function fl.binds:get_unbound()
    local binds = {}

    for k, v in pairs(key_enums) do
      local bind = input.LookupKeyBinding(k)

      if tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function fl.binds:get_bind(key)
    return stored[key]
  end

  function fl.binds:set_bind(command, key)
    for k, v in pairs(stored) do
      if v == command then
        stored[k] = nil
      end
    end

    stored[key] = command
  end

  function fl.binds:add_bind(id, command, key)
    self:set_bind(command, key)
  end
end

local hooks = {}

if SERVER then
  function hooks:PlayerButtonDown(player, key)
    cable.send(player, 'fl_bind_pressed', key)
  end
else
  cable.receive('fl_bind_pressed', function(key)
    local bind = fl.binds:get_bind(key)

    if bind then
      RunConsoleCommand(bind)
    end
  end)
end

plugin.add_hooks('FLBinds', hooks)
