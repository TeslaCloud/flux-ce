--- Server-side receiver of soft undo requests, at most four a second for each player.

Cable.receive('fl_undo_soft', function(actor)
  if !IsValid(actor) then return end

  local cur_time = CurTime()

  if (actor.fl_next_undo or 0) > cur_time then return end

  actor.fl_next_undo = cur_time + 0.25

  Flux.Undo:do_player(actor)
end)
