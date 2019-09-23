mod 'Flux::Player'

function Flux.Player:notify(player, message, arguments, color)
  if !IsValid(player) then
    ServerLog(t(message, arguments))
    return
  end

  Cable.send(player, 'fl_notification', message, arguments, color)
end

function Flux.Player:broadcast(message, arguments)
  ServerLog('Notification: '..t(message, arguments))

  Cable.send(nil, 'fl_notification', message, arguments)
end
