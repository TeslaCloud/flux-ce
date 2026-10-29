--- Network handlers of the Voice Lines plugin on the server: says a line that a player has
-- picked on the Voice Lines page, once `VoiceLines:say` has checked it.

Cable.receive('fl_voice_line_say', function(actor, category_id, line_id)
  VoiceLines:say(actor, category_id, line_id)
end)
