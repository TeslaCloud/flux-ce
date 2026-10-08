--- Key binds that Flux handles itself, independently of the binds in the settings of the game.
-- A bind ties a button (a `KEY_` or `MOUSE_` code) to a console command. Plugins add their
-- default binds on the client with `Flux.Binds:add_bind`, for example
-- `Flux.Binds:add_bind('ToggleThirdPerson', 'fl_third_person', KEY_P)`. When a player presses
-- a button, the server tells their client which one, and the client runs the console command
-- that is bound to it, if any. A command can only be bound to one button at a time. The
-- library itself only exists on the client.
-- @module [Flux.Binds]

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

  --- Returns the names of all of the keyboard and mouse button enumerations.
  -- @return [Map enumeration names (such as 'KEY_N') by button code]
  function Flux.Binds:get_enums()
    return key_enums
  end

  --- Returns all of the Flux key binds.
  -- @return [Map console commands by button code]
  function Flux.Binds:all()
    return stored
  end

  --- Returns the buttons that have something bound to them in the game's own settings.
  -- @return [Map engine bindings (String) by button code]
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

  --- Returns the buttons whose binding in the game's own settings is a number
  -- rather than a command.
  -- @return [Map engine bindings by button code]
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

  --- Returns the console command bound to the specified button with Flux binds.
  -- @param key [Number button code, see the KEY and MOUSE enumerations]
  -- @return [String console command, or nil if nothing is bound]
  function Flux.Binds:get_bind(key)
    return stored[key]
  end

  --- Binds a console command to the specified button, removing its previous bind.
  -- @param command [String console command to run when the button is pressed]
  -- @param key [Number button code, see the KEY and MOUSE enumerations]
  function Flux.Binds:set_bind(command, key)
    for k, v in pairs(stored) do
      if v == command then
        stored[k] = nil
      end
    end

    stored[key] = command
  end

  --- Adds a default key bind for a console command.
  -- ```
  -- Flux.Binds:add_bind('ToggleThirdPerson', 'fl_third_person', KEY_P)
  -- ```
  -- @param id [String name of the bind, currently unused]
  -- @param command [String console command to run when the button is pressed]
  -- @param key [Number button code, see the KEY and MOUSE enumerations]
  function Flux.Binds:add_bind(id, command, key)
    self:set_bind(command, key)
  end
end

--- Hook handlers of the binds library, registered as `FLBinds`.
local hooks = {}

if SERVER then
  --- Tells the client which button it has pressed, so that it can run the Flux bind.
  -- @param actor [Player]
  -- @param key [Number button code]
  function hooks:PlayerButtonDown(actor, key)
    Cable.send(actor, 'fl_bind_pressed', key)
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
