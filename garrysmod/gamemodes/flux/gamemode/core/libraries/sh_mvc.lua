--[[
  Flux © 2016-2018 TeslaCloud Studios
  Do not share or re-distribute before
  the framework is publicly released.
--]]

-- Sorta model-view-controller implementation, except the model isn't /actually/ used lol.

library.New "mvc"

if (CLIENT) then
  local mvcHooks = {}

  function mvc.Push(strName, ...)
    if (!isstring(strName)) then return end

    netstream.Start("Flux::MVC::Push", strName, ...)
  end

  function mvc.Pull(strName, handler, bPreventRemove)
    if (!isstring(strName) or !isfunction(handler)) then return end

    mvcHooks[strName] = mvcHooks[strName] or {}

    table.insert(mvcHooks[strName], {
      handler = handler,
      bPreventRemove = bPreventRemove
    })
  end

  function mvc.Request(strName, handler, ...)
    mvc.Pull(strName, handler)
    mvc.Push(strName, ...)
  end

  function mvc.Listen(strName, handler)
    mvc.Pull(strName, handler, true)
  end

  netstream.Hook("Flux::MVC::Pull", function(strName, ...)
    local hooks = mvcHooks[strName]

    if (hooks) then
      for k, v in ipairs(hooks) do
        local success, value = pcall(v.handler, ...)

        if (!success) then
          ErrorNoHalt("[Flux:MVC] The '"..strName.." - "..tostring(k).."' MVC callback has failed to run!\n")
          ErrorNoHalt(tostring(value).."\n")
        end

        if (!v.bPreventRemove) then
          table.remove(mvcHooks[strName], k)
        end
      end
    end
  end)
else
  local mvcHandlers = {}

  function mvc.Handler(strName, handler)
    if (!isstring(strName)) then return end

    mvcHandlers[strName] = mvcHandlers[strName] or {}

    table.insert(mvcHandlers[strName], handler)
  end

  function mvc.Push(player, strName, ...)
    if (!isstring(strName)) then return end

    netstream.Start(player, "Flux::MVC::Pull", strName, ...)
  end

  netstream.Hook("Flux::MVC::Push", function(player, strName, ...)
    local handlers = mvcHandlers[strName]

    if (handlers) then
      for k, v in ipairs(handlers) do
        local success, value = pcall(v, player, ...)

        if (!success) then
          ErrorNoHalt("[Flux:MVC] The '"..strName.." - "..tostring(k).."' MVC handler has failed to run!\n")
          ErrorNoHalt(tostring(value).."\n")
        end
      end
    end
  end)
end
