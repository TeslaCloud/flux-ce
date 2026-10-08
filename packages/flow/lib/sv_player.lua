--- Sends notifications from the server to the players. `Flux.Player:notify` notifies one
-- player and `Flux.Player:broadcast` notifies everyone. The message can be a language phrase
-- with arguments; it is translated on the client of each recipient and displayed there with
-- `Flux.Notification`. `Player:notify` is the shorter way to notify a single player.

mod 'Flux::Player'

--- Sends a notification to a player. If the player is not valid (e.g. the server console)
-- the message is written to the server log instead.
-- @param target [Player]
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
-- @param color=nil [Color]
function Flux.Player:notify(target, message, arguments, color)
  if !IsValid(target) then
    ServerLog(t(message, arguments))
    return
  end

  Cable.send(target, 'fl_notification', message, arguments, color)
end

--- Sends a notification to every player and writes it to the server log.
-- @param message [String text or language phrase]
-- @param arguments=nil [Map values to substitute into the phrase]
function Flux.Player:broadcast(message, arguments)
  ServerLog('Notification: '..t(message, arguments))

  Cable.send(nil, 'fl_notification', message, arguments)
end
