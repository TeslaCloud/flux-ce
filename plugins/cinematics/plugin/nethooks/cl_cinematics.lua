--- Client-side receivers of the Cinematics plugin: the cinematics that the server sends,
-- queued once the local player has initialized and loaded a character, and the order to
-- clear the queue.

Cable.receive('fl_cinematic_show', function(cinematic)
  local client = PLAYER

  if !IsValid(client) or !client:has_initialized() then return end
  if client.is_character_loaded and !client:is_character_loaded() then return end

  Cinematics:add(cinematic)
end)

Cable.receive('fl_cinematic_clear', function()
  Cinematics:clear()
end)
