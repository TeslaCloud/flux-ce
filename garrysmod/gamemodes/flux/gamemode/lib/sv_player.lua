library.new('player', fl)

function fl.player:notify(player, message, arguments)
  if !IsValid(player) then
    ServerLog(t(message, arguments))
    return
  end

  cable.send(player, 'fl_notification', message, arguments)
end

function fl.player:broadcast(message, arguments)
  ServerLog('Notification: '..t(message, arguments))

  cable.send(nil, 'fl_notification', message, arguments)
end
