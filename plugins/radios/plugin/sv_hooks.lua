--- Server-side hooks of the Radios plugin: lets radio messages reach the players who are
-- tuned in, follows a transmission through the chatbox and registers the chat prefixes
-- that players speak on the radio with.

--- Makes radio messages reach their listeners wherever they are: the speaker and, while
-- `Communications.speak_radio` is sending the message, the listeners of that transmission;
-- for any other message with a frequency, the players with an enabled radio tuned to it in
-- their hotbar.
--
-- The chatbox only lets this hook force a message through, so the false returned for
-- everyone else does not block anything: those players are still checked against the radius
-- of the message, which is how the players near the speaker overhear it. That is intended.
-- @param listener [Player player that would hear the message]
-- @param message_data [Map message data, radio messages have a frequency field]
-- @return [Boolean true if the listener receives the radio message over the radio, false if
--   they can only overhear it, nil for other messages]
function Communications:PlayerCanHear(listener, message_data)
  local frequency = message_data.frequency

  if !frequency then return end

  if message_data.sender == listener then
    return true
  end

  local transmission = self.transmission

  if transmission and transmission.speaker == message_data.sender then
    return transmission.listeners[listener] == true
  end

  return Communications.is_tuned_to(listener, frequency)
end

--- Keeps the list of the players a radio message is sent to out of the copy of the message
-- that each of them receives, so that a client cannot tell who else is listening.
-- @param listener [Player player the copy of the message is for]
-- @param message_data [Map the copy of the message data, radio messages have a frequency
--   field]
function Communications:AdjustMessageData(listener, message_data)
  if message_data.frequency then
    message_data.listeners = nil
  end
end

--- Notes who has received the radio message that `Communications.speak_radio` is sending,
-- which also tells it that the message has not been cancelled.
-- @param message_data [Map message data, radio messages have a frequency field]
-- @param receivers [List<Player> the players the message has been sent to]
function Communications:ChatboxMessageSent(message_data, receivers)
  local transmission = self.transmission

  if transmission and message_data.frequency and transmission.speaker == message_data.sender then
    transmission.receivers = receivers
  end
end

Prefixes:add('radio', {
  prefix = Communications.prefixes,
  callback = function(actor, text, team_chat)
    if !IsValid(actor) then return end

    Communications.say_radio(actor, text)
  end
})
