concommand.Add('fl_third_person', function(actor)
  actor:set_nv('fl_third_person', !actor:get_nv('fl_third_person', false))
end)
