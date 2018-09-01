library.new('player', fl)

function fl.player:notify(player, message, arguments)
  if (!IsValid(player)) then
    ServerLog(t(message, arguments))
    return
  end

  netstream.Start(player, 'flNotification', message, arguments)
end

function fl.player:broadcast(message, arguments)
  ServerLog('Notification: '..t(message, arguments))

  netstream.Start(nil, 'flNotification', message, arguments)
end
