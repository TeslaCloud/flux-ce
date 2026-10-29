--- Client-side receiver of the Voice Lines plugin: the sound of the lines heard over the radio.

Cable.receive('fl_voice_line_radio', function(sound_path, volume)
  if !isstring(sound_path) then return end

  EmitSound(sound_path, vector_origin, -2, CHAN_STATIC, math.Clamp(tonumber(volume) or 0.5, 0, 1), 0)
end)
