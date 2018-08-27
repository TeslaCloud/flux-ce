library.new('player', fl)

function fl.player:Notify(player, message)
  if (!IsValid(player)) then
    ServerLog(message)

    return
  end

  netstream.Start(player, 'flNotification', message)
end

function fl.player:NotifyAll(message)
  ServerLog('Notification: '..message)

  netstream.Start(nil, 'flNotification', message)
end
