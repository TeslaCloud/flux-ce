--- Client-side receivers of the sounds that the server plays, starts and stops for the
-- local player.

local IsValid = IsValid

Cable.receive('fl_sound_play', function(path)
  if isstring(path) then
    surface.PlaySound(path)
  end
end)

Cable.receive('fl_sound_start', function(id, path, volume)
  local client = LocalPlayer()

  if IsValid(client) then
    client:start_sound(id, path, volume)
  end
end)

Cable.receive('fl_sound_stop', function(id, fade_out)
  local client = LocalPlayer()

  if IsValid(client) then
    client:stop_sound(id, fade_out)
  end
end)
