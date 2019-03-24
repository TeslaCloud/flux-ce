class 'Log' extends 'ActiveRecord::Base'

local last_log = nil
local replication_data = nil

function Log:write(message, action, object, subject, io)
  action = isstring(action) and action:underscore() or ''

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

function Log:to_discord(message, webhook)
  if SERVER and webhook then
    webhook:push(message)
  end
end

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

function Log:colored(color, message, action, object, subject)
  return self:write(message, action, object, subject, function(message, action, object, subject)
    MsgC(color, (isstring(action) and action:capitalize()..' - ' or '')..message)
    
    replication_data = { type = 'colored', color = color }

    if !message:ends('\n') then
      Msg('\n')
    end
  end)
end

function Log:notify(message, arguments)
  self:write(message, arguments.action, arguments.object, arguments.subject)
  Flux.Player:broadcast(message, arguments)
  return self
end

function Log:replicate(condition)
  if !last_log or !replication_data then return self end

  condition = isfunction(condition) and condition or function() return true end

  for k, v in ipairs(player.all()) do
    if condition(v) then
      Cable.send('log_replicate', last_log.message, last_log.action, last_log.object, last_log.subject, last_log.data)
    end
  end

  last_log = nil
  replication_data = nil

  return self
end

if CLIENT then
  Cable.receive('log_replicate', function(message, action, object, subject, data)
    if Plugin.call('LogReplicate', message, action, object, subject, data) != nil then
      return
    elseif data.type == 'colored' then
      Log:colored(data.color, message, action, object, subject)
    elseif Log[data.type] then
      Log[data.type](Log, message, action, object, subject)
    end
  end)
end
