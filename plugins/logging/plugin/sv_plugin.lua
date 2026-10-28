--- Sending logs to the staff and to the server console, serverside.

local log_text_color = Color(255, 255, 255)

--- Sends a log line to the players with the 'staff' permission and prints it to the server
-- console with its tag color.
-- @param log_type [Table log type with the tag text at index 1 and its Color at index 2]
-- @param text [String log message]
function Logging:print_admin_log(log_type, text)
  local viewers = {}

  for _, target in player.Iterator() do
    if target:can('staff') then
      viewers[#viewers + 1] = target
    end
  end

  if #viewers > 0 then
    Cable.send(viewers, 'AdminLog', log_type, text)
  end

  MsgC(log_type[2], log_type[1]..' ', log_text_color, text..'\n')
end
