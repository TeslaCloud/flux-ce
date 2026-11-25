--- Shared helpers of the 3D Texts plugin: the limits of what can be placed, the angle that
-- lays a text or picture flat on a surface, the check of a picture's URL and the lookup of
-- texts and pictures by their ID.

if !SurfaceText then
  PLUGIN:set_global('SurfaceText')
end

--- The limits that the server holds placed texts and pictures to, and that the tool panels
-- offer.
SurfaceText.limits = {
  text_length = 128,
  min_style = 1,
  max_style = 10,
  min_scale = 0.01,
  max_scale = 10,
  min_fade = -1024,
  max_fade = 10_000,
  min_size = 1,
  max_size = 4000
}

--- Returns the angle that lays a text or picture flat on a surface.
-- @param normal [Vector normal of the surface]
-- @return [Angle]
function SurfaceText:surface_angle(normal)
  local angle = normal:Angle()

  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  return angle
end

--- Checks whether a URL can be placed as a picture: an `https://` link to a png or jpg image.
-- @param url [Any]
-- @return [Boolean]
function SurfaceText:is_picture_url(url)
  if !isstring(url) or !url:start_with('https://') then return false end

  local lower = url:lower()

  return lower:end_with('.png') or lower:end_with('.jpg') or lower:end_with('.jpeg')
end

--- Finds the position of the text or picture with an ID in a list.
-- @param list [List<Map> SurfaceText.texts or SurfaceText.pictures]
-- @param id [Number ID of the text or picture]
-- @return [Number the index in the list, or nil if no entry has that ID]
function SurfaceText:find_index(list, id)
  for index = 1, #list do
    if list[index].id == id then
      return index
    end
  end
end
