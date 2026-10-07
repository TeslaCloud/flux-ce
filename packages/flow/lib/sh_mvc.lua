-- Sorta model-view-controller implementation, except the model isn't /actually/ used lol.

mod 'MVC'

if CLIENT then
  local mvc_hooks = {}

  --- Sends a request to the server, where it is passed to the handlers registered with
  -- MVC.handler. Clientside variant.
  -- ```
  -- MVC.push('SpawnMenu::GiveItem', PLAYER, item_obj.id, 1)
  -- ```
  -- @param name [String name of the request]
  -- @param ... [Vararg data to pass to the handlers]
  function MVC.push(name, ...)
    if !isstring(name) then return end

    Cable.send('fl_mvc_push', name, ...)
  end

  --- Registers a callback for the data that the server pushes under the specified name.
  -- The callback is removed after the first response unless prevent_remove is set.
  -- @param name [String name of the request]
  -- @param handler [Function receives the pushed values]
  -- @param prevent_remove=false [Boolean keep the callback for further responses]
  function MVC.pull(name, handler, prevent_remove)
    if !isstring(name) or !isfunction(handler) then return end

    mvc_hooks[name] = mvc_hooks[name] or {}

    table.insert(mvc_hooks[name], {
      handler = handler,
      prevent_remove = prevent_remove
    })
  end

  --- Sends a request to the server and calls the handler once the server responds to it.
  -- ```
  -- MVC.request('fl_create_character', function(response)
  --   if response.success then
  --     print('Character created!')
  --   end
  -- end, char_data)
  -- ```
  -- @param name [String name of the request]
  -- @param handler [Function receives the values of the response]
  -- @param ... [Vararg data to send with the request]
  function MVC.request(name, handler, ...)
    MVC.pull(name, handler)
    MVC.push(name, ...)
  end

  --- Registers a permanent callback for the data that the server pushes under the specified name.
  -- @param name [String name of the request]
  -- @param handler [Function receives the pushed values]
  function MVC.listen(name, handler)
    MVC.pull(name, handler, true)
  end

  Cable.receive('fl_mvc_pull', function(name, ...)
    local hooks = mvc_hooks[name]

    if hooks then
      for k, v in ipairs(hooks) do
        local success, value = pcall(v.handler, ...)

        if !success then
          ErrorNoHalt("The '"..name.." - "..tostring(k).."' MVC callback has failed to run!\n")
          error_with_traceback(tostring(value))
        end

        if !v.prevent_remove then
          table.remove(mvc_hooks[name], k)
        end
      end
    end
  end)
else
  local mvc_handlers = {}
  local current_handler = nil

  --- Registers a function that handles the requests clients send with MVC.push or MVC.request.
  -- Call respond_to inside the handler to send a response back. Serverside only.
  -- ```
  -- MVC.handler('fl_create_character', function(actor, data)
  --   local status = Characters.create(actor, data)
  --
  --   respond_to { success = status == CHAR_SUCCESS, status = status }
  -- end)
  -- ```
  -- @param name [String name of the request]
  -- @param handler [Function receives the player who has sent the request, followed
  --   by the request's data]
  function MVC.handler(name, handler)
    if !isstring(name) then return end

    mvc_handlers[name] = mvc_handlers[name] or {}

    table.insert(mvc_handlers[name], handler)
  end

  --- Sends data to the callbacks the clients have registered with MVC.pull, MVC.request
  -- or MVC.listen. Serverside variant.
  -- @param target [Player/List<Player> recipients, everyone if not a valid player]
  -- @param name [String name of the request]
  -- @param ... [Vararg data to pass to the callbacks]
  function MVC.push(target, name, ...)
    if !isstring(name) then return end

    Cable.send(target, 'fl_mvc_pull', name, ...)
  end

  -- utility

  --- Sends a response to the player whose request is currently being handled. Can only
  -- be called from inside of an MVC.handler callback.
  -- @param data [Any response to send, usually a Map]
  function respond_to(data)
    MVC.push(current_handler[1], current_handler[2], data)
  end

  Cable.receive('fl_mvc_push', function(actor, name, ...)
    local handlers = mvc_handlers[name]
    local old_handler = current_handler

    current_handler = { actor, name }

    if handlers then
      for k, v in ipairs(handlers) do
        local success, value = pcall(v, actor, ...)

        if !success then
          ErrorNoHalt("The '"..name.." - "..tostring(k).."' MVC handler has failed to run!\n")
          error_with_traceback(tostring(value))
        end
      end
    end

    current_handler = old_handler
  end)
end
