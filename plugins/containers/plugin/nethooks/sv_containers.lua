--- Server-side receiver of the Containers plugin: a player's request to open the container
-- they use, taken twice a second at most.

local request_delay = 0.5

Cable.receive('fl_container_open', function(actor, entity)
  local cur_time = CurTime()

  if actor.next_container_request and actor.next_container_request > cur_time then return end

  actor.next_container_request = cur_time + request_delay

  Containers:request_open(actor, entity)
end)
