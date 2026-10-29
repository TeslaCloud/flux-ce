--- Server-side receivers of the Animations plugin: a player's requests to play an animation,
-- which ends the one they are playing instead, and to leave the one they are playing.

Cable.receive('fl_animations_play', function(actor, id)
  if !isstring(id) then return end

  if actor.animation_data then
    Animations:leave(actor)

    return
  end

  local started, reason, arguments = Animations:play(actor, id)

  if !started and reason then
    actor:notify(reason, arguments)
  end
end)

Cable.receive('fl_animations_leave', function(actor)
  Animations:leave(actor)
end)
