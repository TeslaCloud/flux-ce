--- Client-side receiver of the Spawn Points plugin: the list of spawn points that the server
-- sends.

Cable.receive('fl_spawn_points_load', function(points)
  SpawnPoints:set_points(points)
end)
