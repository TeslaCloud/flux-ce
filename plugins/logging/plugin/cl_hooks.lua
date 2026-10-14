Cable.receive('AdminLog', function(type, text)
  if PLAYER:can('staff') then
    MsgC(type[2], type[1]..' ', Color(255, 255, 255), text..'\n')
  end
end)
