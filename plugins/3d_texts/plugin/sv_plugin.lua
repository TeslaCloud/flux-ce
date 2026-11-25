--- Server side of the 3D Texts plugin: saving and loading the texts and pictures, adding and
-- removing them by ID, and asking a client which one its player looks at to remove it.

local insert = table.insert
local cable_send = Cable.send

--- Writes all 3D texts and pictures to the plugin data storage. Serverside only.
function SurfaceText:save()
  Data.save_plugin('3d_texts', SurfaceText.texts)
  Data.save_plugin('3dpictures', SurfaceText.pictures)
end

--- Gives an ID to every entry of a list that does not have one.
-- @param list [List<Map> texts or pictures]
-- @return [Number the largest ID in the list, 0 for an empty list]
local function assign_ids(list)
  local last_id = 0

  for _, entry in ipairs(list) do
    if isnumber(entry.id) then
      last_id = math.max(last_id, entry.id)
    end
  end

  for _, entry in ipairs(list) do
    if !isnumber(entry.id) then
      last_id += 1
      entry.id = last_id
    end
  end

  return last_id
end

--- Reads the 3D texts and pictures from the plugin data storage,
-- replacing the currently stored ones, and gives an ID to every entry that has none.
-- Serverside only.
function SurfaceText:load()
  self.texts = Data.load_plugin('3d_texts', {})
  self.pictures = Data.load_plugin('3dpictures', {})
  self.last_text_id = assign_ids(self.texts)
  self.last_picture_id = assign_ids(self.pictures)
end

--- Clamps a number to the range of two of the limits, or returns the fallback for a value
-- that is not a number.
-- @param value [Any]
-- @param min [Number]
-- @param max [Number]
-- @param fallback [Number]
-- @return [Number]
local function clamp_number(value, min, max, fallback)
  value = tonumber(value)

  if !value or value != value then return fallback end

  return math.Clamp(value, min, max)
end

--- Adds a 3D text, saves it and broadcasts it to all clients. Serverside only.
-- Does nothing unless text, pos, normal and angle are present. The style is rounded and the
-- numbers are clamped to `SurfaceText.limits`, and the text is cut to its length.
-- fade_offset defaults to 0: the text is drawn up to 1024 units away and fades out from 768
-- units on, and the offset moves both distances.
-- ```
-- local trace = actor:GetEyeTrace()
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
--   angle       = SurfaceText:surface_angle(trace.HitNormal)
-- })
-- ```
-- @param data [Map text data: text, pos, normal, angle and the optional style=1, scale=1,
--   color=white, extra_color=Color(255, 0, 0, 100) and fade_offset=0]
-- @return [Map the stored text with its `id`, or nil if a required field is missing]
function SurfaceText:add_text(data)
  if !istable(data) or !isstring(data.text) or data.text == '' then return end
  if !isvector(data.pos) or !isvector(data.normal) or !isangle(data.angle) then return end

  local limits = self.limits

  data.text = utf8.sub(data.text, 1, limits.text_length)
  data.style = math.Round(clamp_number(data.style, limits.min_style, limits.max_style, 1))
  data.scale = clamp_number(data.scale, limits.min_scale, limits.max_scale, 1)
  data.fade_offset = clamp_number(data.fade_offset, limits.min_fade, limits.max_fade, 0)
  data.color = istable(data.color) and data.color or Color(255, 255, 255)
  data.extra_color = istable(data.extra_color) and data.extra_color or Color(255, 0, 0, 100)

  self.last_text_id = (self.last_text_id or assign_ids(self.texts)) + 1
  data.id = self.last_text_id

  insert(self.texts, data)

  self:save()

  cable_send(nil, 'fl_surface_text_add', data)

  return data
end

--- Adds a 3D picture, saves it and broadcasts it to all clients. Serverside only.
-- Does nothing unless the URL is an `https://` link to a png or jpg image and pos, normal and
-- angle are present. The width, the height and the fade offset are clamped to
-- `SurfaceText.limits`; fade_offset defaults to 0, as for texts.
-- ```
-- SurfaceText:add_picture({
--   url         = 'https://example.com/poster.png',
--   width       = 512,
--   height      = 512,
--   fade_offset = 0,
--   pos         = trace.HitPos,
--   normal      = trace.HitNormal,
--   angle       = SurfaceText:surface_angle(trace.HitNormal)
-- })
-- ```
-- @param data [Map picture data: url, pos, normal, angle and the optional width=512,
--   height=512 and fade_offset=0]
-- @return [Map the stored picture with its `id`, or nil if a required field is missing or
--   the URL is not allowed]
-- @see [SurfaceText:is_picture_url]
function SurfaceText:add_picture(data)
  if !istable(data) or !self:is_picture_url(data.url) then return end
  if !isvector(data.pos) or !isvector(data.normal) or !isangle(data.angle) then return end

  local limits = self.limits

  data.width = clamp_number(data.width, limits.min_size, limits.max_size, 512)
  data.height = clamp_number(data.height, limits.min_size, limits.max_size, 512)
  data.fade_offset = clamp_number(data.fade_offset, limits.min_fade, limits.max_fade, 0)

  self.last_picture_id = (self.last_picture_id or assign_ids(self.pictures)) + 1
  data.id = self.last_picture_id

  insert(self.pictures, data)

  self:save()

  cable_send(nil, 'fl_surface_picture_add', data)

  return data
end

--- Removes the 3D text with an ID, saves the texts and tells all clients. Serverside only.
-- @param id [Number ID of the text]
-- @return [Boolean true if there was a text with that ID]
function SurfaceText:delete_text(id)
  local index = self:find_index(self.texts, id)

  if !index then return false end

  table.remove(self.texts, index)

  self:save()

  cable_send(nil, 'fl_surface_text_remove', id)

  return true
end

--- Removes the 3D picture with an ID, saves the pictures and tells all clients. Serverside
-- only.
-- @param id [Number ID of the picture]
-- @return [Boolean true if there was a picture with that ID]
function SurfaceText:delete_picture(id)
  local index = self:find_index(self.pictures, id)

  if !index then return false end

  table.remove(self.pictures, index)

  self:save()

  cable_send(nil, 'fl_surface_picture_remove', id)

  return true
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
