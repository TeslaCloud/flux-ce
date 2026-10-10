--- Prompts: questions that the server asks a single player. `Flux.Prompt:request_string`
-- (or `Player:request_string`) asks them to type a text and
-- `Flux.Prompt:request_confirmation` (or `Player:request_confirmation`) asks them a yes or
-- no question. The client shows the question in a dialog window and sends the answer back,
-- and the server passes it to the callback of the request.
-- ```
-- actor:request_string('ui.rename.title', 'ui.rename.message', function(target, name)
--   if name then
--     rename_item(target, item, name)
--   end
-- end, { default = item.name, max_length = 32 })
--
-- actor:request_confirmation('ui.destroy.title', 'ui.destroy.message', function(target, confirmed)
--   if confirmed then
--     destroy_item(target, item)
--   end
-- end)
-- ```
--
-- Every request has an ID and can only be answered once, by the player who was asked and
-- with the kind of answer it expects. A request that is not answered in time (5 minutes
-- unless set otherwise) or whose player leaves is closed, and its callback is called with
-- false, so the callback of a request that was sent always runs exactly once.
-- @module [Flux.Prompt]

mod 'Flux::Prompt'

if SERVER then
  local pending         = Flux.Prompt.pending or {}
  Flux.Prompt.pending   = pending
  Flux.Prompt.last_id   = Flux.Prompt.last_id or 0

  Cable.check_networked_string('fl_prompt_request')
  Cable.check_networked_string('fl_prompt_close')

  --- Closes a pending request and calls its callback with the answer.
  -- @param id [Number request ID]
  -- @param answer [String/Boolean the answer, false if there is none]
  -- @return [Boolean false if there is no such request]
  local function resolve(id, answer)
    local entry = pending[id]

    if !entry then return false end

    pending[id] = nil

    timer.Remove('fl_prompt_'..id)

    if isfunction(entry.callback) then
      local ok, result = pcall(entry.callback, entry.target, answer)

      if !ok then
        error_with_traceback('Callback of a prompt has failed to run!\n'..result)
      end
    end

    return true
  end

  --- Stores a request, sends it to the player and starts its timeout.
  -- @param target [Player the player to ask]
  -- @param kind [String 'string' or 'confirmation']
  -- @param title [String title of the dialog, text or language phrase]
  -- @param message [String question, text or language phrase]
  -- @param callback [Function called with the player and the answer]
  -- @param options=nil [Map settings of the request]
  -- @return [Number request ID, nil if the target is not a human player]
  local function ask(target, kind, title, message, callback, options)
    if !IsValid(target) or !target:IsPlayer() or target:IsBot() then return end

    options = options or {}

    local id = Flux.Prompt.last_id + 1
    local timeout = tonumber(options.timeout) or 300

    Flux.Prompt.last_id = id

    pending[id] = {
      id          = id,
      kind        = kind,
      target      = target,
      callback    = callback,
      max_length  = tonumber(options.max_length) or 256
    }

    Cable.send(target, 'fl_prompt_request', id, kind, title, message, options.default, options.arguments)

    if timeout > 0 then
      timer.Create('fl_prompt_'..id, timeout, 1, function()
        Flux.Prompt:cancel(id)
      end)
    end

    return id
  end

  --- Asks a player to type a text. The callback is called with the player and the text
  -- they submitted (which may be empty), or with false if they cancelled, did not answer
  -- in time or left. Serverside only.
  -- @param target [Player the player to ask; bots cannot be asked]
  -- @param title [String title of the dialog, text or language phrase]
  -- @param message [String question shown above the text field, text or language phrase]
  -- @param callback [Function called with the player and the answer (String, or false)]
  -- @param options=nil [Map optional settings: default (String text the field starts
  --   with), max_length (Number longest answer in characters, 256 by default; a longer
  --   one is cut), timeout (Number seconds to wait for the answer, 300 by default, 0 to
  --   wait until the player leaves) and arguments (Map values to substitute into the
  --   title and the message)]
  -- @return [Number request ID, nil if the player cannot be asked]
  function Flux.Prompt:request_string(target, title, message, callback, options)
    return ask(target, 'string', title, message, callback, options)
  end

  --- Asks a player a yes or no question. The callback is called with the player and true
  -- if they agreed, or false if they declined, did not answer in time or left.
  -- Serverside only.
  -- @param target [Player the player to ask; bots cannot be asked]
  -- @param title [String title of the dialog, text or language phrase]
  -- @param message [String question, text or language phrase]
  -- @param callback [Function called with the player and the answer (Boolean)]
  -- @param options=nil [Map optional settings: timeout (Number seconds to wait for the
  --   answer, 300 by default, 0 to wait until the player leaves) and arguments (Map
  --   values to substitute into the title and the message)]
  -- @return [Number request ID, nil if the player cannot be asked]
  function Flux.Prompt:request_confirmation(target, title, message, callback, options)
    return ask(target, 'confirmation', title, message, callback, options)
  end

  --- Closes a pending request: removes its dialog from the screen of the player and calls
  -- its callback with false. Serverside only.
  -- @param id [Number request ID]
  -- @return [Boolean true if the request was pending]
  function Flux.Prompt:cancel(id)
    local entry = pending[id]

    if !entry then return false end

    if IsValid(entry.target) then
      Cable.send(entry.target, 'fl_prompt_close', id)
    end

    return resolve(id, false)
  end

  Cable.receive('fl_prompt_answer', function(actor, id, answer)
    local entry = isnumber(id) and pending[id]

    if !entry or entry.target != actor then return end

    if entry.kind == 'string' then
      if isstring(answer) then
        local length = utf8.len(answer)

        if !length then
          answer = string.sub(answer, 1, entry.max_length)
        elseif length > entry.max_length then
          answer = answer:utf8sub(1, entry.max_length)
        end
      else
        answer = false
      end
    else
      answer = (answer == true)
    end

    resolve(id, answer)
  end)

  --- Hook handlers of the prompts library, registered as `FLPrompts`.
  local hooks = {}

  --- Closes the requests that a leaving player has not answered.
  -- @param actor [Player]
  function hooks:PlayerDisconnected(actor)
    local ids = {}

    for id, entry in pairs(pending) do
      if entry.target == actor then
        ids[#ids + 1] = id
      end
    end

    for i = 1, #ids do
      resolve(ids[i], false)
    end
  end

  Plugin.add_hooks('FLPrompts', hooks)

  local player_meta = FindMetaTable('Player')

  --- Asks the player to type a text. Serverside only.
  -- @param title [String title of the dialog, text or language phrase]
  -- @param message [String question shown above the text field, text or language phrase]
  -- @param callback [Function called with the player and the answer (String, or false if
  --   there is none)]
  -- @param options=nil [Map default, max_length, timeout and arguments, see
  --   Flux.Prompt#request_string]
  -- @return [Number request ID, nil if the player cannot be asked]
  -- @see [Flux.Prompt#request_string]
  function player_meta:request_string(title, message, callback, options)
    return Flux.Prompt:request_string(self, title, message, callback, options)
  end

  --- Asks the player a yes or no question. Serverside only.
  -- @param title [String title of the dialog, text or language phrase]
  -- @param message [String question, text or language phrase]
  -- @param callback [Function called with the player and the answer (Boolean)]
  -- @param options=nil [Map timeout and arguments, see Flux.Prompt#request_confirmation]
  -- @return [Number request ID, nil if the player cannot be asked]
  -- @see [Flux.Prompt#request_confirmation]
  function player_meta:request_confirmation(title, message, callback, options)
    return Flux.Prompt:request_confirmation(self, title, message, callback, options)
  end
else
  local windows = {}

  --- Sends the answer of the local player to the server and forgets the dialog.
  -- @param id [Number request ID]
  -- @param answer [String/Boolean the entered text, the choice, or false if cancelled]
  local function send_answer(id, answer)
    windows[id] = nil

    Cable.send('fl_prompt_answer', id, answer)
  end

  Cable.receive('fl_prompt_request', function(id, kind, title, message, default, arguments)
    local window

    title = isstring(title) and (t(title, arguments)) or ''
    message = isstring(message) and (t(message, arguments)) or ''

    if kind == 'string' then
      window = Derma_StringRequest(title, message, isstring(default) and default or '', function(text)
        send_answer(id, text)
      end, function()
        send_answer(id, false)
      end, t'ui.ok', t'ui.cancel')
    else
      window = Derma_Query(message, title, t'ui.yes', function()
        send_answer(id, true)
      end, t'ui.no', function()
        send_answer(id, false)
      end)
    end

    windows[id] = window
  end)

  Cable.receive('fl_prompt_close', function(id)
    local window = windows[id]

    windows[id] = nil

    if IsValid(window) then
      window:Remove()
    end
  end)
end
