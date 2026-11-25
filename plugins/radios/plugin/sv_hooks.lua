--- Server-side hooks of the Radios plugin: lets radio messages reach the players who are
-- tuned in and follows a transmission through the chatbox.

--- Makes radio messages reach their listeners wherever they are: the speaker and, while
-- `Radios.speak_radio` is sending the message, the listeners of that transmission;
-- for any other message with a frequency, the players with an enabled radio tuned to it in
-- their hotbar. Everyone else is left to the other handlers and to the radius of the message,
-- which is how the players near the speaker overhear it.
-- @param listener [Player player that would hear the message]
-- @param message_data [Map message data, radio messages have a frequency field]
-- @return [Boolean true if the listener receives the radio message over the radio, nil
--   otherwise]
function Radios:PlayerCanHearChat(listener, message_data)
  local frequency = message_data.frequency

  if !frequency then return end

  if message_data.sender == listener then
    return true
  end

  local transmission = self.transmission

  if transmission and transmission.speaker == message_data.sender then
    return transmission.listeners[listener] == true or nil
  end

  return Radios.is_tuned_to(listener, frequency) or nil
end

--- Notes who has received the radio message that `Radios.speak_radio` is sending,
-- which also tells it that the message has not been canceled.
-- @param message_data [Map message data, radio messages have a frequency field]
-- @param receivers [List<Player> the players the message has been sent to]
function Radios:ChatMessageSent(message_data, receivers)
  local transmission = self.transmission

  if transmission and message_data.frequency and transmission.speaker == message_data.sender then
    transmission.receivers = receivers
  end
end
