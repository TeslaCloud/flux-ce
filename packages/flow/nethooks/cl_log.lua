--- Client-side receiver of the log entries that the server replicates with `Log:replicate`,
-- which outputs them the way the server has.

Cable.receive('fl_log_replicate', function(message, action, object, subject, data)
  --- Called on the client when a log entry sent with `Log:replicate` arrives, before it is
  -- output. Gamemode (`GM`) handlers are not called.
  -- @param message [String Text of the entry]
  -- @param action [String Type of the logged event in snake_case; empty if there is none]
  -- @param object [String/Number Who or what performed the action]
  -- @param subject [String/Number Who or what the action was performed on]
  -- @param data [Map How the server has output the entry: `type` is 'print', 'colored' or
  --   'write' (an entry without output), and `color` is the console color of a colored
  --   entry]
  -- @return [Any Return any non-nil value to prevent the default output of the entry]
  if Plugin.call('LogReplicate', message, action, object, subject, data) != nil then
    return
  elseif data.type == 'colored' then
    Log:colored(data.color, message, action, object, subject)
  elseif Log[data.type] then
    Log[data.type](Log, message, action, object, subject)
  end
end)
