--[[
  Derpy © 2018 TeslaCloud Studios
  Do not use, re-distribute or share unless authorized.
--]]-- Sorta model-view-controller implementation, except the model isn't /actually/ used lol.

library.New "mvc"

if CLIENT then
  local mvcHooks = {}

  function mvc.Push(name, ...)
    if (!isstring(name)) then return end

    netstream.Start("Flux::MVC::Push", name, ...)
  end

  function mvc.Pull(name, handler, bPreventRemove)
    if (!isstring(name) or !isfunction(handler)) then return end

    mvcHooks[name] = mvcHooks[name] or {}

    table.insert(mvcHooks[name], {
      handler = handler,
      bPreventRemove = bPreventRemove
    })
  end

  function mvc.Request(name, handler, ...)
    mvc.Pull(name, handler)
    mvc.Push(name, ...)
  end

  function mvc.Listen(name, handler)
    mvc.Pull(name, handler, true)
  end

  netstream.Hook("Flux::MVC::Pull", function(name, ...)
    local hooks = mvcHooks[name]

    if (hooks) then
      for k, v in ipairs(hooks) do
        local success, value = pcall(v.handler, ...)

        if (!success) then
          ErrorNoHalt("[Flux:MVC] The '"..name.." - "..tostring(k).."' MVC callback has failed to run!\n")
          ErrorNoHalt(tostring(value).."\n")
        end

        if (!v.bPreventRemove) then
          table.remove(mvcHooks[name], k)
        end
      end
    end
  end)
else
  local mvcHandlers = {}

  function mvc.Handler(name, handler)
    if (!isstring(name)) then return end

    mvcHandlers[name] = mvcHandlers[name] or {}

    table.insert(mvcHandlers[name], handler)
  end

  function mvc.Push(player, name, ...)
    if (!isstring(name)) then return end

    netstream.Start(player, "Flux::MVC::Pull", name, ...)
  end

  netstream.Hook("Flux::MVC::Push", function(player, name, ...)
    local handlers = mvcHandlers[name]

    if (handlers) then
      for k, v in ipairs(handlers) do
        local success, value = pcall(v, player, ...)

        if (!success) then
          ErrorNoHalt("[Flux:MVC] The '"..name.." - "..tostring(k).."' MVC handler has failed to run!\n")
          ErrorNoHalt(tostring(value).."\n")
        end
      end
    end
  end)
end
