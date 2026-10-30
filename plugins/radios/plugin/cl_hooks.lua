--- Client-side hooks of the Radios plugin: tells the Display Typing plugin when a player is
-- typing a radio message.

--- Shows players who are typing a message with a radio prefix as 'radioing'. The text may be
-- the outline of what is typed (see `DisplayTyping:outline`), which is matched the same way.
-- @param _target [Player player that is typing]
-- @param text [String text being typed, or its outline]
-- @return [String 'radioing' for a radio message, nil for anything else]
function Radios:GetTypingKind(_target, text)
  if Chatbox.find_prefix(text) == 'radio' then
    return 'radioing'
  end
end
