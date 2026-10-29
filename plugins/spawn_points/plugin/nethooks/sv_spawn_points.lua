--- Server-side receiver of the Spawn Points plugin: the request of a client for the list of
-- spawn points, for players with the 'manage_spawn_points' permission, once a second at most.

Cable.receive('fl_spawn_points_request', function(actor)
  if !actor:can('manage_spawn_points') then return end

  local cur_time = CurTime()

  if (actor.next_spawn_points_request or 0) > cur_time then return end

  actor.next_spawn_points_request = cur_time + 1

  SpawnPoints:sync(actor)
end)
