concommand.Add('fl_third_person', function(player)
  player:set_nv('fl_third_person', !player:get_nv('fl_third_person', false))
end)
