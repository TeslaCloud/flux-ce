--- Client-side receivers of the Areas API plugin: the areas that the server sends, registers
-- and removes, and the local player entering and leaving them, which runs the callback of
-- the area's type.

Cable.receive('fl_player_entered_area', function(area_idx, pos)
  local area = Areas.all()[area_idx]

  if !istable(area) then return end

  try(Areas.get_callback(area.type), PLAYER, area, true, pos, CurTime())
end)

Cable.receive('fl_player_left_area', function(area_idx, pos)
  local area = Areas.all()[area_idx]

  if !istable(area) then return end

  try(Areas.get_callback(area.type), PLAYER, area, false, pos, CurTime())
end)

Cable.receive('fl_areas_load', function(area_storage)
  Areas.set_stored(area_storage)
end)

Cable.receive('fl_area_remove', function(id)
  Areas.remove(id)
end)

Cable.receive('fl_area_register', function(id, data)
  Areas.register(id, data)
end)
