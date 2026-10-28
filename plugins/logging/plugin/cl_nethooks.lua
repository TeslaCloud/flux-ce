--- Client-side receiver of the Logging plugin: prints the logs that the server sends to the
-- console of players with the 'staff' permission.

Cable.receive('AdminLog', function(log_type, text)
  if PLAYER:can('staff') then
    MsgC(log_type[2], log_type[1]..' ', Color(255, 255, 255), text..'\n')
  end
end)
