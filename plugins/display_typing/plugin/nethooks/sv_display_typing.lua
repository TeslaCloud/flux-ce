--- Server-side receiver of the Display Typing plugin: the typing reports of the clients, at
-- most four times the longest chat message long and taken as often as
-- `DisplayTyping:accept_report` allows.

Cable.receive('fl_typing_report', function(actor, text, exact, kind_id)
  if !IsValid(actor) or !isstring(text) then return end

  if text == '' then
    DisplayTyping:stop_typing(actor)

    return
  end

  if #text > Config.get('chatbox_max_message_length', 512) * 4 then return end
  if !DisplayTyping:accept_report(actor, CurTime()) then return end

  DisplayTyping:set_typing(actor, text, exact, kind_id)
end)
