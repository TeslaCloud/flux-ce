--- Server-side receiver of the MapScenes plugin: the request of staff with the
-- 'manage_map_scenes' permission to remove a mapscene point by its ID.

Cable.receive('fl_mapscene_remove', function(actor, id)
  if !IsValid(actor) or !isnumber(id) or !actor:can('manage_map_scenes') then return end

  MapScenes:remove_point(id)
end)
