--- Sends notifications and sounds from the server to the players. `Flux.Player:notify`
-- notifies one player and `Flux.Player:broadcast` notifies everyone. The message can be a
-- language phrase with arguments; it is translated on the client of each recipient and
-- displayed there with `Flux.Notification`. `Player:notify` is the shorter way to notify a
-- single player.
--
-- `Flux.Player:play_sound` plays a sound once on the clients of the given players, and
-- `Flux.Player:start_sound` and `Flux.Player:stop_sound` control named looping sounds
-- there, such as an ambience or an alarm that only some players should hear. `Player` has
-- methods of the same names for a single player.

mod 'Flux::Player'

local isstring = isstring

Cable.check_networked_string('fl_sound_play')
Cable.check_networked_string('fl_sound_start')
Cable.check_networked_string('fl_sound_stop')

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

--- Plays a sound once on the clients of the given players. The sound has no position in
-- the world and is heard at full volume, like an interface sound.
-- ```
-- Flux.Player:play_sound(target, 'buttons/button15.wav')
-- ```
-- @param target [Player/List<Player> who hears the sound; everyone if nil]
-- @param path [String path of the sound file, relative to the sound/ folder]
function Flux.Player:play_sound(target, path)
  if !isstring(path) then return end

  Cable.send(target, 'fl_sound_play', path)
end

--- Starts a named looping sound on the clients of the given players. The sound keeps
-- playing until it is stopped with `Flux.Player:stop_sound` under the same name. Starting
-- another sound under a name that is in use replaces the old one, and starting the same
-- sound again does nothing. Whether the sound loops is up to the sound file: a file
-- without loop points plays once.
-- ```
-- Flux.Player:start_sound(target, 'heartbeat', 'player/heartbeat1.wav', 0.5)
-- ```
-- @param target [Player/List<Player> who hears the sound; everyone if nil]
-- @param id [String name to stop the sound by]
-- @param path [String path of the sound file, relative to the sound/ folder]
-- @param volume=0.75 [Number volume from 0 to 1]
function Flux.Player:start_sound(target, id, path, volume)
  if !isstring(id) or !isstring(path) then return end

  Cable.send(target, 'fl_sound_start', id, path, math.Clamp(tonumber(volume) or 0.75, 0, 1))
end

--- Stops a named sound on the clients of the given players. Does nothing for players who
-- do not have a sound under that name.
-- ```
-- Flux.Player:stop_sound(target, 'heartbeat', 2)
-- ```
-- @param target [Player/List<Player> whose sound stops; everyone if nil]
-- @param id [String name the sound was started under]
-- @param fade_out=0 [Number seconds over which the sound fades out; 0 cuts it off]
function Flux.Player:stop_sound(target, id, fade_out)
  if !isstring(id) then return end

  Cable.send(target, 'fl_sound_stop', id, math.max(tonumber(fade_out) or 0, 0))
end
