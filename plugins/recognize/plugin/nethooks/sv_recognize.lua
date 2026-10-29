--- Server-side network handlers of the Recognize plugin: the 'fl_recognize' and
-- 'fl_recognize_forget' messages, with which players introduce themselves and forget
-- someone.

Cable.receive('fl_recognize', function(actor, kind, name, target)
  if Recognition:accept_request(actor) then
    Recognition:introduce(actor, kind, name, target)
  end
end)

Cable.receive('fl_recognize_forget', function(actor, target)
  if Recognition:accept_request(actor) then
    Recognition:player_forget(actor, target)
  end
end)
