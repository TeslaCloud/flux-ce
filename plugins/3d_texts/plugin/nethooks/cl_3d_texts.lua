--- Client-side receivers of the 3D Texts plugin: the texts and pictures that the server
-- sends, adds and removes, and its requests to find the text or picture that the local
-- player looks at.

local insert = table.insert
local remove = table.remove

Cable.receive('fl_surface_text_load', function(data)
  SurfaceText.texts = data or {}
end)

Cable.receive('fl_surface_text_add', function(data)
  insert(SurfaceText.texts, data)
end)

Cable.receive('fl_surface_text_remove', function(idx)
  remove(SurfaceText.texts, idx)
end)

Cable.receive('fl_surface_picture_load', function(data)
  SurfaceText.pictures = data or {}
end)

Cable.receive('fl_surface_picture_add', function(data)
  insert(SurfaceText.pictures, data)
end)

Cable.receive('fl_surface_picture_remove', function(idx)
  remove(SurfaceText.pictures, idx)
end)

Cable.receive('fl_surface_text_calculate', function()
  SurfaceText:trace_remove_text(PLAYER:GetEyeTraceNoCursor())
end)

Cable.receive('fl_surface_picture_calculate', function()
  SurfaceText:trace_remove_picture(PLAYER:GetEyeTraceNoCursor())
end)
