--- Server-side receiver of the Area Display plugin: a client's report that its player has
-- entered a one-time area, which shows the area to the player unless they have seen it. A
-- player can send one report every `request_interval` seconds; the others are dropped.

local CurTime = CurTime

local request_interval = 0.2

Cable.receive('fl_area_display_request', function(actor, area_id)
  if !IsValid(actor) or !actor.record then return end

  local cur_time = CurTime()

  if (actor.fl_next_area_display_request or 0) > cur_time then return end

  actor.fl_next_area_display_request = cur_time + request_interval

  local area = AreaDisplay:find_text_area(area_id)

  if !area or !area.once or AreaDisplay:has_seen(actor, area) then return end

  AreaDisplay:set_seen(actor, area)
  AreaDisplay:show_area(actor, area)
end)
