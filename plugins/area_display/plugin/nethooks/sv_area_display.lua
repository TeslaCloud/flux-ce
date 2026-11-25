--- Server-side receiver of the Area Display plugin: a client's report that its player has
-- entered a one-time area, which shows the area to the player unless they have seen it. A
-- player can report each area once every `request_interval` seconds. The time is noted only
-- for reports of one-time text areas the player has not seen, so reports of other or unknown
-- areas cost a lookup and leave nothing behind.

local CurTime = CurTime

local request_interval = 0.2

Cable.receive('fl_area_display_request', function(actor, area_id)
  if !IsValid(actor) or !actor.record then return end

  local area = AreaDisplay:find_text_area(area_id)

  if !area or !area.once or AreaDisplay:has_seen(actor, area) then return end

  local cur_time = CurTime()
  local next_requests = actor.fl_next_area_display_requests

  if !next_requests then
    next_requests = {}
    actor.fl_next_area_display_requests = next_requests
  end

  if (next_requests[area.id] or 0) > cur_time then return end

  next_requests[area.id] = cur_time + request_interval

  AreaDisplay:set_seen(actor, area)
  AreaDisplay:show_area(actor, area)
end)
