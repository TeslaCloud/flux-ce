--- Client-side receivers of the 3D Texts plugin: the texts and pictures that the server
-- sends, adds and removes by ID, and its requests to find the text or picture that the local
-- player looks at.

local insert = table.insert
local remove = table.remove

Cable.receive('fl_surface_text_load', function(data)
  SurfaceText.texts = data or {}
end)

Cable.receive('fl_surface_text_add', function(data)
  insert(SurfaceText.texts, data)
end)

Cable.receive('fl_surface_text_remove', function(id)
  local index = SurfaceText:find_index(SurfaceText.texts, id)

  if index then
    remove(SurfaceText.texts, index)
  end
end)

Cable.receive('fl_surface_picture_load', function(data)
  SurfaceText.pictures = data or {}
end)

Cable.receive('fl_surface_picture_add', function(data)
  insert(SurfaceText.pictures, data)
end)

Cable.receive('fl_surface_picture_remove', function(id)
  local index = SurfaceText:find_index(SurfaceText.pictures, id)

  if index then
    remove(SurfaceText.pictures, index)
  end
end)

Cable.receive('fl_surface_text_calculate', function()
  if !SurfaceText:trace_remove_text(PLAYER:GetEyeTraceNoCursor()) then
    PLAYER:notify('error.3d_text.nothing_aimed')
  end
end)

Cable.receive('fl_surface_picture_calculate', function()
  if !SurfaceText:trace_remove_picture(PLAYER:GetEyeTraceNoCursor()) then
    PLAYER:notify('error.3d_picture.nothing_aimed')
  end
end)
