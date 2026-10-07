concommand.Add('fl_third_person', function(actor)
  local old_val = actor:get_nv('third_person')

  if old_val == nil then
    old_val = false
  end

  actor:set_nv('third_person', !old_val)
end)
