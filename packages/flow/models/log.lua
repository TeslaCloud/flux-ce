--- Log entries, stored in the `logs` table of the database.
-- The class methods record an entry and output it in one go: `Log:print` and
-- `Log:colored` write to the console, `Log:notify` notifies every player, `Log:to_discord`
-- pushes the last message to Discord webhooks and `Log:replicate` repeats the last
-- console entry on the clients. They return the class, so the calls can be chained.

class 'Log' extends 'ActiveRecord::Base'

local last_log = nil
local replication_data = nil

--- Records a log entry. On the server the entry is saved to the logs table. The entry is
-- also remembered so that it can be passed on with Log:replicate.
-- @param message [String text of the entry]
-- @param action=nil [String type of the logged event; stored in snake_case]
-- @param object=nil [String/Number who or what performed the action, e.g. a user ID]
-- @param subject=nil [String/Number who or what the action was performed on]
-- @param io=nil [Function outputs the entry; called with (message, action in CamelCase,
--   object, subject)]
-- @return [Log the Log class, for chaining]
function Log:write(message, action, object, subject, io)
  action = isstring(action) and action:underscore() or ''

  self.last_message = message

  if SERVER then
    local log = Log.new()
      log.body = message
      log.action = action
      log.object = object
      log.subject = subject
    log:save()
  end

  if isfunction(io) then
    io(message, action:camel_case(), object, subject)
  end

  last_log = {
    message = message,
    action = action,
    object = object,
    subject = subject,
    io = io,
    data = replication_data or { type = 'write' }
  }

  return self
end

--- Pushes a message to every Discord webhook registered for the given type. Does nothing
-- on the client.
-- @param type='all' [String webhook type]
-- @param message=nil [String text to push; defaults to the last message given to Log:write]
-- @return [Log the Log class, for chaining]
function Log:to_discord(type, message)
  if SERVER then
    message = message or self.last_message
    type = type or 'all'

    local hooks = Webhook:get_type(string.lower(type))

    for k, v in ipairs(hooks) do
      v:push(message)
    end
  end

  return self
end

--- Records a log entry and prints it, prefixed with the action, to the server log on the
-- server or to the console on the client.
-- @param message [String text of the entry]
-- @param action=nil [String type of the logged event]
-- @param object=nil [String/Number who or what performed the action]
-- @param subject=nil [String/Number who or what the action was performed on]
-- @return [Log the Log class, for chaining]
-- @see [Log:write]
function Log:print(message, action, object, subject)
  return self:write(message, action, object, subject, function(message, action, object, subject)
    local prefix = (isstring(action) and action:capitalize()..' - ' or '')

    replication_data = { type = 'print' }

    if SERVER then
      ServerLog(prefix..message)
    else
      print(prefix..message)
    end
  end)
end

--- Records a log entry and prints it to the console in the given color, prefixed with
-- the action.
-- ```
-- Log:colored(
--   command_log_color,
--   message,
--   'PlayerRunCommand',
--   IsValid(actor) and actor.record.id or 'console'
-- ):replicate(function(listener)
--   return listener:is_staff() and listener:can(cmd_table.id)
-- end)
-- ```
-- @param color [Color color of the console output]
-- @param message [String text of the entry]
-- @param action=nil [String type of the logged event]
-- @param object=nil [String/Number who or what performed the action]
-- @param subject=nil [String/Number who or what the action was performed on]
-- @return [Log the Log class, for chaining]
-- @see [Log:write]
function Log:colored(color, message, action, object, subject)
  return self:write(message, action, object, subject, function(message, action, object, subject)
    MsgC(color, (isstring(action) and action:capitalize()..' - ' or '')..message)

    replication_data = { type = 'colored', color = color }

    if !message:end_with('\n') then
      Msg('\n')
    end
  end)
end

--- Records a log entry and shows the message to every player as a notification.
-- Server only.
-- @param message [String text or language phrase of the notification]
-- @param arguments [Map arguments of the phrase; its action, object and subject fields are
--   used for the log entry]
-- @return [Log the Log class, for chaining]
function Log:notify(message, arguments)
  self:write(message, arguments.action, arguments.object, arguments.subject)
  Flux.Player:broadcast(message, arguments)
  return self
end

--- Sends the most recent entry made with Log:print or Log:colored to the clients, where it
-- is output the same way. Does nothing if there is no such entry since the last call.
-- Server only.
-- @param condition=nil [Function called with each Player; return true to send the entry to
--   them. Everyone receives it when omitted]
-- @return [Log the Log class, for chaining]
function Log:replicate(condition)
  if !last_log or !replication_data then return self end

  condition = isfunction(condition) and condition or function() return true end

  for k, v in player.Iterator() do
    if condition(v) then
      Cable.send(
        v,
        'log_replicate',
        last_log.message,
        last_log.action,
        last_log.object,
        last_log.subject,
        last_log.data
      )
    end
  end

  last_log = nil
  replication_data = nil

  return self
end

if CLIENT then
  Cable.receive('log_replicate', function(message, action, object, subject, data)
    --- Called on the client when a log entry sent with `Log:replicate` arrives, before it is
    -- output. Gamemode (`GM`) handlers are not called.
    -- @param message [String Text of the entry]
    -- @param action [String Type of the logged event in snake_case; empty if there is none]
    -- @param object [String/Number Who or what performed the action]
    -- @param subject [String/Number Who or what the action was performed on]
    -- @param data [Map How the server has output the entry: `type` is 'print' or 'colored',
    --   and `color` is the console color of a colored entry]
    -- @return [Any Return any non-nil value to prevent the default output of the entry]
    if Plugin.call('LogReplicate', message, action, object, subject, data) != nil then
      return
    elseif data.type == 'colored' then
      Log:colored(data.color, message, action, object, subject)
    elseif Log[data.type] then
      Log[data.type](Log, message, action, object, subject)
    end
  end)
end
