--- Client-side receiver of the Area Display plugin: the area notices that the server sends,
-- with a text of their own or announcing a text area.

Cable.receive('fl_area_display_show', function(info, area_id)
  local area = AreaDisplay:find_text_area(area_id)

  if istable(info) or isstring(info) then
    AreaDisplay:add(info, area)
  elseif area then
    AreaDisplay:announce(area, true)
  end
end)
