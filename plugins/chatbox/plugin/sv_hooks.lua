--- Default handlers of the server-side hooks of the Chatbox plugin: the icon and the colors of
-- what players say, the rule that the sender of a message always receives it, and the handler
-- that takes the `say` console command over so that it goes through the same guard as the
-- chatbox and hands the messages that start with a chat prefix to that prefix.

--- Provides the default icon that is displayed before the name of the player
-- in their chat messages.
-- @param _speaker [Player the speaker]
-- @param _text [String the message]
-- @param _team_chat [Boolean whether the message was sent to the team chat]
-- @return [Map icon piece for Chatbox.add_text]
function Chatbox:ChatboxGetPlayerIcon(_speaker, _text, _team_chat)
  return { icon = 'fa-shield-alt', size = 14, margin = 8, is_data = true }
end

--- Provides the default color of the player's name in their chat messages.
-- @param speaker [Player the speaker]
-- @param _text [String the message]
-- @param _team_chat [Boolean whether the message was sent to the team chat]
-- @return [Color the color of the player's team]
function Chatbox:ChatboxGetPlayerColor(speaker, _text, _team_chat)
  return team.GetColor(speaker:Team()) or Color(255, 255, 255)
end

--- Provides the default color of the text of chat messages.
-- @param _speaker [Player the speaker]
-- @param _text [String the message]
-- @param _team_chat [Boolean whether the message was sent to the team chat]
-- @return [Color white]
function Chatbox:ChatboxGetMessageColor(_speaker, _text, _team_chat)
  return Color(255, 255, 255)
end

--- Takes over what a player says through the `say` and `say_team` console commands, which
-- the engine runs this hook for and would otherwise broadcast itself: the text goes through
-- `Chatbox.submit`, so that the flood guard and the length limit apply to it as they do to
-- the chatbox, and the engine is told to say nothing. A command is left to the gamemode
-- handler. The text that `Chatbox.submit` itself passes to `Chatbox.player_say`, which runs
-- this hook again, goes to the chat prefix it starts with, if any (see `Chatbox.use_prefix`).
-- @param actor [Player the speaker]
-- @param text [String the text as it was typed]
-- @param team_chat [Boolean whether the text is meant for the team chat]
-- @return [String an empty string once the text has been taken over or handed to a chat
--   prefix, nil otherwise]
function Chatbox:PlayerSay(actor, text, team_chat)
  text = tostring(text)

  if Chatbox.is_submitting() then
    return Chatbox.use_prefix(actor, text, team_chat) ? '' : nil
  end

  if Flux.Command:is_command(text) then return end

  Chatbox.submit(actor, text, team_chat)

  return ''
end

--- Makes sure that the sender of a message always receives it.
-- @param listener [Player the listener]
-- @param message_data [Map message data, see Chatbox.add_text]
-- @return [Boolean true if the player is the sender of the message, nil otherwise]
function Chatbox:PlayerCanHear(listener, message_data)
  if listener == message_data.sender then
    return true
  end
end
