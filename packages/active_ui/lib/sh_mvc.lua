--- A small request and response layer between the client and the server, loosely modeled on
-- model-view-controller. Panels (the views) send named requests, and handlers on the server
-- (the controllers) act on them and can answer. On the server `MVC.handler` registers a
-- handler for a request name. Inside of a handler `respond_to` sends a response back to the
-- player who has made the request, `MVC.responder` gives a function that sends it later, from
-- a database callback for example, and `MVC.push` sends data under a name to any player at any
-- time. On the client `MVC.push` sends a request, `MVC.request` sends one and calls a function
-- with the response, and `MVC.listen` receives everything the server pushes under a name.
-- Plugins usually keep their handlers in their `controllers` folder.
--
-- Every request carries an ID. A request sent with `MVC.request` gets a number of its own, and
-- its response reaches only its own callback, exactly once: the server answers a request that
-- has no handler, or whose handler has raised an error before answering, with
-- `{ success = false, error = 'no_handler' }` or `{ success = false, error = 'handler_failed' }`.
-- A callback whose request is not answered within 30 seconds is dropped. A request sent with
-- `MVC.push` has the ID 0, and the response to it goes to the callbacks registered with
-- `MVC.pull` and `MVC.listen` under its name, like the data the server pushes.
-- @module [MVC]

mod 'MVC'

if CLIENT then
  local mvc_hooks = {}
  local requests = {}
  local request_timeout = 30

  MVC.last_request_id = MVC.last_request_id or 0

  --- Runs an MVC callback in protected mode and prints its error.
  -- @param name [String name of the request]
  -- @param callback [Function]
  -- @param ... [Vararg values of the response]
  local function run_callback(name, callback, ...)
    local success, value = pcall(callback, ...)

    if !success then
      ErrorNoHalt("The '"..name.."' MVC callback has failed to run!\n")
      error_with_traceback(tostring(value))
    end
  end

  --- Sends a request to the server, where it is passed to the handlers registered with
  -- MVC.handler. A response to it goes to the callbacks registered with MVC.pull and
  -- MVC.listen under the same name. Clientside variant.
  -- ```
  -- MVC.push('SpawnMenu::GiveItem', PLAYER, item_obj.id, 1)
  -- ```
  -- @param name [String name of the request]
  -- @param ... [Vararg data to pass to the handlers]
  function MVC.push(name, ...)
    if !isstring(name) then return end

    Cable.send('fl_mvc_push', name, 0, ...)
  end

  --- Registers a callback for the data that the server pushes under the specified name.
  -- The callback is removed after the first response unless prevent_remove is set.
  -- @param name [String name of the request]
  -- @param handler [Function receives the pushed values]
  -- @param prevent_remove=false [Boolean keep the callback for further responses]
  function MVC.pull(name, handler, prevent_remove)
    if !isstring(name) or !isfunction(handler) then return end

    mvc_hooks[name] = mvc_hooks[name] or {}

    local name_hooks = mvc_hooks[name]

    name_hooks[#name_hooks + 1] = {
      handler = handler,
      prevent_remove = prevent_remove
    }
  end

  --- Removes the callbacks registered with MVC.pull or MVC.listen under the name that are
  -- the specified function.
  -- @param name [String name of the request]
  -- @param handler [Function the callback that was registered]
  function MVC.unlisten(name, handler)
    local name_hooks = mvc_hooks[name]

    if !name_hooks then return end

    for index = #name_hooks, 1, -1 do
      if name_hooks[index].handler == handler then
        table.remove(name_hooks, index)
      end
    end
  end

  --- Sends a request to the server and calls the handler once with the response to it. The
  -- handler gets `{ success = false, error = 'no_handler' }` when the server has no handler
  -- for the request and `{ success = false, error = 'handler_failed' }` when a handler has
  -- raised an error before answering; it is dropped if no response arrives within 30 seconds.
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
    if !isstring(name) or !isfunction(handler) then return end

    local request_id = MVC.last_request_id + 1

    MVC.last_request_id = request_id
    requests[request_id] = { name = name, handler = handler }

    timer.Simple(request_timeout, function()
      requests[request_id] = nil
    end)

    Cable.send('fl_mvc_push', name, request_id, ...)
  end

  --- Registers a permanent callback for the data that the server pushes under the specified name.
  -- @param name [String name of the request]
  -- @param handler [Function receives the pushed values]
  function MVC.listen(name, handler)
    MVC.pull(name, handler, true)
  end

  Cable.receive('fl_mvc_pull', function(name, request_id, ...)
    if request_id != 0 then
      local request = requests[request_id]

      if request then
        requests[request_id] = nil

        run_callback(request.name, request.handler, ...)
      end

      return
    end

    local hooks = mvc_hooks[name]

    if hooks then
      local count = #hooks
      local kept = {}

      for index = 1, count do
        local mvc_hook = hooks[index]

        run_callback(name, mvc_hook.handler, ...)

        if mvc_hook.prevent_remove then
          kept[#kept + 1] = mvc_hook
        end
      end

      for index = count + 1, #hooks do
        kept[#kept + 1] = hooks[index]
      end

      mvc_hooks[name] = kept
    end
  end)
else
  local mvc_handlers = {}
  local current_request = nil

  --- Registers a function that handles the requests clients send with MVC.push or MVC.request.
  -- Call respond_to inside the handler to send a response back, or MVC.responder to send it
  -- later. Serverside only.
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

    local handlers = mvc_handlers[name] or {}

    mvc_handlers[name] = handlers
    handlers[#handlers + 1] = handler
  end

  --- Sends data to the callbacks the clients have registered with MVC.pull or MVC.listen.
  -- Serverside variant.
  -- @param target [Player/List<Player> recipients, everyone if not a valid player]
  -- @param name [String name of the request]
  -- @param ... [Vararg data to pass to the callbacks]
  function MVC.push(target, name, ...)
    if !isstring(name) then return end

    Cable.send(target, 'fl_mvc_pull', name, 0, ...)
  end

  --- Sends a response to a request: to its callback on the client, or under its name to the
  -- callbacks registered with MVC.pull and MVC.listen if it was sent with MVC.push.
  -- @param request [Map the request: actor, name, id and whether it has been answered]
  -- @param data [Any response to send]
  local function respond(request, data)
    request.answered = true

    Cable.send(request.actor, 'fl_mvc_pull', request.name, request.id, data)
  end

  --- Sends an error response to a request that expects one and has not been answered yet.
  -- @param request [Map the request]
  -- @param reason [String 'no_handler' or 'handler_failed']
  local function respond_with_error(request, reason)
    if request.id == 0 or request.answered then return end

    respond(request, { success = false, error = reason })
  end

  --- Sends a response to the player whose request is currently being handled. Can only
  -- be called from inside of an MVC.handler callback, while it runs; use MVC.responder to
  -- answer later.
  -- @param data [Any response to send, usually a Map]
  function respond_to(data)
    if !current_request then
      error('respond_to called outside of an MVC handler', 2)
    end

    respond(current_request, data)
  end

  --- Returns a function that sends a response to the request that is currently being
  -- handled, for handlers that answer later, from a database callback for example. The
  -- function answers the player who has made this request even when other requests have been
  -- handled in the meantime, and does nothing if that player has left. Can only be called
  -- from inside of an MVC.handler callback, while it runs.
  -- ```
  -- MVC.handler('fl_character_names', function(actor)
  --   local respond = MVC.responder()
  --
  --   Character:where('user_id', actor.record.id):get(function(characters)
  --     respond { success = true, names = table.map(characters, char -> char.name) }
  --   end)
  -- end)
  -- ```
  -- @return [Function sends its argument, usually a Map, as the response]
  function MVC.responder()
    local request = current_request

    if !request then
      error('MVC.responder called outside of an MVC handler', 2)
    end

    return function(data)
      if IsValid(request.actor) then
        respond(request, data)
      end
    end
  end

  Cable.receive('fl_mvc_push', function(actor, name, request_id, ...)
    if !isstring(name) or !isnumber(request_id) then return end

    local request = { actor = actor, name = name, id = request_id, answered = false }
    local handlers = mvc_handlers[name]

    if !handlers then
      Flux.dev_print("MVC request '"..name.."' from "..tostring(actor)..' has no handler.')

      respond_with_error(request, 'no_handler')

      return
    end

    local old_request = current_request
    local failed = false

    current_request = request

    for i = 1, #handlers do
      local success, value = pcall(handlers[i], actor, ...)

      if !success then
        failed = true

        ErrorNoHalt("The '"..name..' - '..tostring(i).."' MVC handler has failed to run!\n")
        error_with_traceback(tostring(value))
      end
    end

    current_request = old_request

    if failed then
      respond_with_error(request, 'handler_failed')
    end
  end)
end
