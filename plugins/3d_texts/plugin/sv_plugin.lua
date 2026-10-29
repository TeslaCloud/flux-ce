--- Server side of the 3D Texts plugin: saving and loading the texts and pictures, adding
-- them and asking a client which one its player looks at to remove it.

local insert = table.insert
local cable_send = Cable.send

--- Writes all 3D texts and pictures to the plugin data storage. Serverside only.
function SurfaceText:save()
  Data.save_plugin('3d_texts', SurfaceText.texts)
  Data.save_plugin('3dpictures', SurfaceText.pictures)
end

--- Reads the 3D texts and pictures from the plugin data storage,
-- replacing the currently stored ones. Serverside only.
function SurfaceText:load()
  local loaded = Data.load_plugin('3d_texts', {})
  local loaded_pics = Data.load_plugin('3dpictures', {})

  self.texts = loaded
  self.pictures = loaded_pics
end

--- Adds a 3D text, saves it and broadcasts it to all clients. Serverside only.
-- Does nothing unless text, pos, angle, style and scale are all present.
-- ```
-- local trace = actor:GetEyeTrace()
-- local angle = trace.HitNormal:Angle()
-- angle:RotateAroundAxis(angle:Forward(), 90)
-- angle:RotateAroundAxis(angle:Right(), 270)
--
-- SurfaceText:add_text({
--   text        = 'Sample Text',
--   style       = 5,                      -- 1 to 10, see the texts tool
--   scale       = 1,
--   color       = Color(255, 255, 255),
--   extra_color = Color(255, 0, 0, 100),  -- background / shadow color
--   fade_offset = 0,
--   pos         = trace.HitPos,
--   normal      = trace.HitNormal,
--   angle       = angle
-- })
-- ```
-- @param data [Map text data: text, style, scale, color, extra_color, pos, normal, angle
--   and optional fade_offset]
function SurfaceText:add_text(data)
  if !data or !data.text or !data.pos or !data.angle or !data.style or !data.scale then return end

  insert(SurfaceText.texts, data)

  self:save()

  cable_send(nil, 'fl_surface_text_add', data)
end

--- Adds a 3D picture, saves it and broadcasts it to all clients. Serverside only.
-- Does nothing unless url, width and height are all present.
-- ```
-- SurfaceText:add_picture({
--   url         = 'https://example.com/poster.png',
--   width       = 512,
--   height      = 512,
--   fade_offset = 0,
--   pos         = trace.HitPos,
--   normal      = trace.HitNormal,
--   angle       = angle -- built the same way as for SurfaceText:add_text
-- })
-- ```
-- @param data [Map picture data: url, width, height, pos, normal, angle
--   and optional fade_offset]
function SurfaceText:add_picture(data)
  if !data or !data.url or !data.width or !data.height then return end

  insert(SurfaceText.pictures, data)

  self:save()

  cable_send(nil, 'fl_surface_picture_add', data)
end

--- Asks the player's client to find the 3D text they are looking at and request its removal.
-- Serverside only; does nothing if the player lacks the 'manage_texts' permission.
-- @param actor [Player]
function SurfaceText:remove_text(actor)
  if actor:can('manage_texts') then
    cable_send(actor, 'fl_surface_text_calculate', true)
  end
end

--- Asks the player's client to find the 3D picture they are looking at and request its
-- removal. Serverside only; does nothing if the player lacks the 'manage_pictures' permission.
-- @param actor [Player]
function SurfaceText:remove_picture(actor)
  if actor:can('manage_pictures') then
    cable_send(actor, 'fl_surface_picture_calculate', true)
  end
end
