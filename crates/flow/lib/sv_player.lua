mod 'Flux::Player'

--- Sends a notification to a player. If the player is not valid (e.g. the server console)
-- the message is written to the server log instead.
-- @param player [Player]
-- @param message [String text or language phrase]
-- @param arguments=nil [Hash values to substitute into the phrase]
-- @param color=nil [Color]
function Flux.Player:notify(player, message, arguments, color)
  if !IsValid(player) then
    ServerLog(t(message, arguments))
    return
  end

  Cable.send(player, 'fl_notification', message, arguments, color)
end

--- Sends a notification to every player and writes it to the server log.
-- @param message [String text or language phrase]
-- @param arguments=nil [Hash values to substitute into the phrase]
function Flux.Player:broadcast(message, arguments)
  ServerLog('Notification: '..t(message, arguments))

  Cable.send(nil, 'fl_notification', message, arguments)
end
