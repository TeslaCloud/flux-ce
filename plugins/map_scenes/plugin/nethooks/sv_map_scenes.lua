--- Server-side receiver of the MapScenes plugin: the request of staff with the
-- 'manage_map_scenes' permission to remove a mapscene point.

local cable_send = Cable.send

Cable.receive('fl_mapscene_remove', function(actor, id)
  if !actor:can('manage_map_scenes') then return end
  if !isnumber(id) or !MapScenes.points[id] then return end

  table.remove(MapScenes.points, id)

  cable_send(nil, 'fl_mapscene_delete', id)

  MapScenes:save()
end)
