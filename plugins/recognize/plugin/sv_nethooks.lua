--- Server-side network handlers of the Recognize plugin: the 'fl_recognize' and
-- 'fl_recognize_forget' messages, with which players introduce themselves and forget
-- someone.

Cable.receive('fl_recognize', function(actor, kind, name, target)
  if Recognizes:accept_request(actor) then
    Recognizes:introduce(actor, kind, name, target)
  end
end)

Cable.receive('fl_recognize_forget', function(actor, target)
  if Recognizes:accept_request(actor) then
    Recognizes:player_forget(actor, target)
  end
end)
