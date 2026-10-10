--- 3D Texts lets staff put texts and pictures on the surfaces of the map.
-- They are placed and removed with the Text Tool and the Picture Placer of the tool gun, or
-- from code with `SurfaceText:add_text` and `SurfaceText:add_picture`. The server keeps
-- them in `SurfaceText.texts` and `SurfaceText.pictures`, saves them with the plugin data
-- and sends them to every client, which draws them in the world and fades them out with
-- distance.

PLUGIN:set_global('SurfaceText')

SurfaceText.texts = SurfaceText.texts or {}
SurfaceText.pictures = SurfaceText.pictures or {}

require_relative 'cl_hooks'

local insert = table.insert
local remove = table.remove
local abs = math.abs
local cable_send = Cable.send

--- Registers the 'texts' and 'pictures' level design permissions.
function SurfaceText:RegisterPermissions()
  Bolt:register_permission(
    'texts',
    'Place / delete texts',
    'Grants access to place and delete texts.',
    'permission.categories.level_design',
    'assistant'
  )
  Bolt:register_permission(
    'pictures',
    'Place / delete pictures',
    'Grants access to place and delete pictures.',
    'permission.categories.level_design',
    'assistant'
  )
end

if SERVER then
  --- Sends all stored 3D texts and pictures to the player who has just initialized.
  -- @param actor [Player]
  function SurfaceText:PlayerInitialized(actor)
    cable_send(actor, 'fl_surface_text_load', self.texts)
    cable_send(actor, 'fl_surface_picture_load', self.pictures)
  end

  --- Loads the stored 3D texts and pictures when the framework loads its data.
  function SurfaceText:LoadData()
    self:load()
  end

  --- Saves the 3D texts and pictures when the framework saves its data.
  function SurfaceText:SaveData()
    self:save()
  end

  --- Writes all 3D texts and pictures to the plugin data storage. Serverside only.
  function SurfaceText:save()
    Data.save_plugin('3dtexts', SurfaceText.texts)
    Data.save_plugin('3dpictures', SurfaceText.pictures)
  end

  --- Reads the 3D texts and pictures from the plugin data storage,
  -- replacing the currently stored ones. Serverside only.
  function SurfaceText:load()
    local loaded = Data.load_plugin('3dtexts', {})
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
  -- Serverside only; does nothing if the player lacks the 'texts' permission.
  -- @param actor [Player]
  function SurfaceText:remove_text(actor)
    if actor:can('texts') then
      cable_send(actor, 'fl_surface_text_calculate', true)
    end
  end

  --- Asks the player's client to find the 3D picture they are looking at and request its
  -- removal. Serverside only; does nothing if the player lacks the 'pictures' permission.
  -- @param actor [Player]
  function SurfaceText:remove_picture(actor)
    if actor:can('pictures') then
      cable_send(actor, 'fl_surface_picture_calculate', true)
    end
  end

  Cable.receive('fl_surface_text_remove', function(actor, idx)
    if actor:can('texts') then
      remove(SurfaceText.texts, idx)

      SurfaceText:save()

      cable_send(nil, 'fl_surface_text_remove', idx)

      actor:notify(t'notification.3d_text.text_removed')
    end
  end)

  Cable.receive('fl_surface_picture_remove', function(actor, idx)
    if actor:can('pictures') then
      remove(SurfaceText.pictures, idx)

      SurfaceText:save()

      cable_send(nil, 'fl_surface_picture_remove', idx)

      actor:notify(t'notification.3d_picture.removed')
    end
  end)
else
  --- Finds the 3D text hit by the trace and asks the server to remove it. Clientside only.
  -- @param trace [Map trace result, e.g. from Player:GetEyeTraceNoCursor]
  -- @return [Boolean true if a text was hit and its removal was requested]
  function SurfaceText:trace_remove_text(trace)
    if !trace then return false end

    local hit_pos = trace.HitPos - trace.HitNormal
    local hit_z = abs(hit_pos.z)
    local trace_start = trace.StartPos
    local font = Theme.get_font('text_3d2d')

    for k, v in pairs(self.texts) do
      local pos = v.pos
      local normal = v.normal
      local ang = normal:Angle()
      local w, h = util.text_size(v.text, font)
      local scale = v.scale
      local offset = -ang:Right() * (w * 0.05) * scale
      local start_pos = pos - offset
      local end_pos = pos + offset

      if abs(hit_z - abs(pos.z)) < 4 * scale then
        if util.vectors_intersect(trace_start, hit_pos, start_pos, end_pos) then
          cable_send('fl_surface_text_remove', k)

          return true
        end
      end
    end

    return false
  end

  --- Finds the 3D picture hit by the trace and asks the server to remove it. Clientside only.
  -- @param trace [Map trace result, e.g. from Player:GetEyeTraceNoCursor]
  -- @return [Boolean true if a picture was hit and its removal was requested]
  function SurfaceText:trace_remove_picture(trace)
    if !trace then return false end

    local hit_pos = trace.HitPos - trace.HitNormal
    local hit_z = abs(hit_pos.z)
    local trace_start = trace.StartPos

    for k, v in pairs(self.pictures) do
      local pos = v.pos
      local normal = v.normal
      local ang = normal:Angle()
      local width, height = v.width, v.height
      local offset = -ang:Right() * (width * 0.05)
      local start_pos = pos - offset
      local end_pos = pos + offset

      if abs(hit_z - abs(pos.z)) < height * 0.05 then
        if util.vectors_intersect(trace_start, hit_pos, start_pos, end_pos) then
          cable_send('fl_surface_picture_remove', k)

          return true
        end
      end
    end

    return false
  end

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
end
