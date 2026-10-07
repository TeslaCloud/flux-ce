PLUGIN:set_global('SurfaceText')

SurfaceText.texts = SurfaceText.texts or {}
SurfaceText.pictures = SurfaceText.pictures or {}

require_relative 'cl_hooks'

--- Registers the 'texts' and 'pictures' level design permissions.
function SurfaceText:RegisterPermissions()
  Bolt:register_permission('texts', 'Place / delete texts', 'Grants access to place and delete texts.', 'permission.categories.level_design', 'assistent')
  Bolt:register_permission('pictures', 'Place / delete pictures', 'Grants access to place and delete pictures.', 'permission.categories.level_design', 'assistent')
end

if SERVER then
  --- Sends all stored 3D texts and pictures to the player who has just initialized.
  -- @param player [Player]
  function SurfaceText:PlayerInitialized(player)
    Cable.send(player, 'fl_surface_text_load', self.texts)
    Cable.send(player, 'fl_surface_picture_load', self.pictures)
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
  -- local trace = player:GetEyeTrace()
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
  -- @param data [Hash text data: text, style, scale, color, extra_color, pos, normal, angle
  --   and optional fade_offset]
  function SurfaceText:add_text(data)
    if !data or !data.text or !data.pos or !data.angle or !data.style or !data.scale then return end

    table.insert(SurfaceText.texts, data)

    self:save()

    Cable.send(nil, 'fl_surface_text_add', data)
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
  -- @param data [Hash picture data: url, width, height, pos, normal, angle
  --   and optional fade_offset]
  function SurfaceText:add_picture(data)
    if !data or !data.url or !data.width or !data.height then return end

    table.insert(SurfaceText.pictures, data)

    self:save()

    Cable.send(nil, 'fl_surface_picture_add', data)
  end

  --- Asks the player's client to find the 3D text they are looking at and request its removal.
  -- Serverside only; does nothing if the player lacks the 'textremove' permission.
  -- @param player [Player]
  function SurfaceText:remove_text(player)
    if player:can('textremove') then
      Cable.send(player, 'fl_surface_text_calculate', true)
    end
  end

  --- Asks the player's client to find the 3D picture they are looking at and request its
  -- removal. Serverside only; does nothing if the player lacks the 'textremove' permission.
  -- @param player [Player]
  function SurfaceText:remove_picture(player)
    if player:can('textremove') then
      Cable.send(player, 'fl_surface_picture_calculate', true)
    end
  end

  Cable.receive('fl_surface_text_remove', function(player, idx)
    if player:can('textremove') then
      table.remove(SurfaceText.texts, idx)

      SurfaceText:save()

      Cable.send(nil, 'fl_surface_text_remove', idx)

      player:notify(t'notification.3d_text.text_removed')
    end
  end)

  Cable.receive('fl_surface_picture_remove', function(player, idx)
    if player:can('textremove') then
      table.remove(SurfaceText.pictures, idx)

      SurfaceText:save()

      Cable.send(nil, 'fl_surface_picture_remove', idx)

      player:notify(t'notification.3d_picture.removed')
    end
  end)
else
  --- Finds the 3D text hit by the trace and asks the server to remove it. Clientside only.
  -- @param trace [Hash trace result, e.g. from Player:GetEyeTraceNoCursor]
  -- @return [Boolean true if a text was hit and its removal was requested]
  function SurfaceText:trace_remove_text(trace)
    if !trace then return false end

    local hit_pos = trace.HitPos - trace.HitNormal
    local trace_start = trace.StartPos

    for k, v in pairs(self.texts) do
      local pos = v.pos
      local normal = v.normal
      local ang = normal:Angle()
      local w, h = util.text_size(v.text, Theme.get_font('text_3d2d'))
      local ang_right = -ang:Right()
      local start_pos = pos - ang_right * (w * 0.05) * v.scale
      local end_pos = pos + ang_right * (w * 0.05) * v.scale

      if math.abs(math.abs(hit_pos.z) - math.abs(pos.z)) < 4 * v.scale then
        if util.vectors_intersect(trace_start, hit_pos, start_pos, end_pos) then
          Cable.send('fl_surface_text_remove', k)

          return true
        end
      end
    end

    return false
  end

  --- Finds the 3D picture hit by the trace and asks the server to remove it. Clientside only.
  -- @param trace [Hash trace result, e.g. from Player:GetEyeTraceNoCursor]
  -- @return [Boolean true if a picture was hit and its removal was requested]
  function SurfaceText:trace_remove_picture(trace)
    if !trace then return false end

    local hit_pos = trace.HitPos - trace.HitNormal
    local trace_start = trace.StartPos

    for k, v in pairs(self.pictures) do
      local pos = v.pos
      local normal = v.normal
      local ang = normal:Angle()
      local width, height = v.width, v.height
      local ang_right = -ang:Right()
      local start_pos = pos - ang_right * (width * 0.05)
      local end_pos = pos + ang_right * (width * 0.05)

      if math.abs(math.abs(hit_pos.z) - math.abs(pos.z)) < height * 0.05 then
        if util.vectors_intersect(trace_start, hit_pos, start_pos, end_pos) then
          Cable.send('fl_surface_picture_remove', k)

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
    table.insert(SurfaceText.texts, data)
  end)

  Cable.receive('fl_surface_text_remove', function(idx)
    table.remove(SurfaceText.texts, idx)
  end)

  Cable.receive('fl_surface_picture_load', function(data)
    SurfaceText.pictures = data or {}
  end)

  Cable.receive('fl_surface_picture_add', function(data)
    table.insert(SurfaceText.pictures, data)
  end)

  Cable.receive('fl_surface_picture_remove', function(idx)
    table.remove(SurfaceText.pictures, idx)
  end)

  Cable.receive('fl_surface_text_calculate', function()
    SurfaceText:trace_remove_text(PLAYER:GetEyeTraceNoCursor())
  end)

  Cable.receive('fl_surface_picture_calculate', function()
    SurfaceText:trace_remove_picture(PLAYER:GetEyeTraceNoCursor())
  end)
end
