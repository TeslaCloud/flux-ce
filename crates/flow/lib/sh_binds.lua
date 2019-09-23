if CLIENT then
  mod 'Flux::Binds'

  local stored          = Flux.Binds.stored     or {}
  local key_enums       = Flux.Binds.key_enums  or {}
  Flux.Binds.stored     = stored
  Flux.Binds.key_enums  = key_enums

  if #key_enums == 0 then
    for k, v in pairs(_G) do
      if string.sub(k, 1, 6) == 'MOUSE_' then
        key_enums[v] = k
      elseif string.sub(k, 1, 4) == 'KEY_' then
        key_enums[v] = k
      end
    end
  end

  function Flux.Binds:get_enums()
    return key_enums
  end

  function Flux.Binds:all()
    return stored
  end

  function Flux.Binds:get_bound()
    local binds = {}

    for k, v in pairs(key_enums) do
      local bind = input.LookupKeyBinding(k)

      if !tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function Flux.Binds:get_unbound()
    local binds = {}

    for k, v in pairs(key_enums) do
      local bind = input.LookupKeyBinding(k)

      if tonumber(bind) then
        binds[k] = bind
      end
    end

    return binds
  end

  function Flux.Binds:get_bind(key)
    return stored[key]
  end

  function Flux.Binds:set_bind(command, key)
    for k, v in pairs(stored) do
      if v == command then
        stored[k] = nil
      end
    end

    stored[key] = command
  end

  function Flux.Binds:add_bind(id, command, key)
    self:set_bind(command, key)
  end
end

local hooks = {}

if SERVER then
  function hooks:PlayerButtonDown(player, key)
    Cable.send(player, 'fl_bind_pressed', key)
  end
else
  Cable.receive('fl_bind_pressed', function(key)
    local bind = Flux.Binds:get_bind(key)

    if bind then
      RunConsoleCommand(bind)
    end
  end)
end

Plugin.add_hooks('FLBinds', hooks)
