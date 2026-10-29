--- Server-side receiver of the Area Display plugin: a client's report that its player has
-- entered a one-time area, which shows the area to the player unless they have seen it.

Cable.receive('fl_area_display_request', function(actor, area_id)
  if !actor.record then return end

  local area = AreaDisplay:find_text_area(area_id)

  if !area or !area.once or AreaDisplay:has_seen(actor, area) then return end

  AreaDisplay:set_seen(actor, area)
  AreaDisplay:show_area(actor, area)
end)
