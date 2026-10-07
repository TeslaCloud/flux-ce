--- Provides the default icon that is displayed before the name of the player
-- in their chat messages.
-- @param speaker [Player the speaker]
-- @param text [String the message]
-- @param team_chat [Boolean whether the message was sent to the team chat]
-- @return [Map icon piece for Chatbox.add_text]
function Chatbox:ChatboxGetPlayerIcon(speaker, text, team_chat)
  return { icon = 'fa-shield-alt', size = 14, margin = 8, is_data = true }
end

--- Provides the default color of the player's name in their chat messages.
-- @param speaker [Player the speaker]
-- @param text [String the message]
-- @param team_chat [Boolean whether the message was sent to the team chat]
-- @return [Color the color of the player's team]
function Chatbox:ChatboxGetPlayerColor(speaker, text, team_chat)
  return team.GetColor(speaker:Team()) or Color(255, 255, 255)
end

--- Provides the default color of the text of chat messages.
-- @param speaker [Player the speaker]
-- @param text [String the message]
-- @param team_chat [Boolean whether the message was sent to the team chat]
-- @return [Color white]
function Chatbox:ChatboxGetMessageColor(speaker, text, team_chat)
  return Color(255, 255, 255)
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
