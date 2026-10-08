--- Server side of the Display Typing plugin: networks the text each player is typing into the
-- chatbox.

Cable.receive('display_typing_text_changed', function(actor, new_text)
  if IsValid(actor) then
    actor:set_nv('chat_text', new_text)
  end
end)
