concommand.Add('fl_third_person', function(player)
  local old_val = player:get_nv('third_person')

  if old_val == nil then
    old_val = false
  end

  player:set_nv('third_person', !old_val)
end)
