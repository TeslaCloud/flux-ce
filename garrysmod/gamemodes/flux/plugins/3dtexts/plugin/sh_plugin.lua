PLUGIN:set_alias('fl3DText')

fl3DText.texts = fl3DText.texts or {}
fl3DText.pictures = fl3DText.pictures or {}

util.include('cl_hooks.lua')

if SERVER then
  function fl3DText:Save()
    data.SavePlugin('3dtexts', fl3DText.texts)
    data.SavePlugin('3dpictures', fl3DText.pictures)
  end

  function fl3DText:Load()
    local loaded = data.LoadPlugin('3dtexts', {})
    local loaded_pics = data.LoadPlugin('3dpictures', {})

    self.texts = loaded
    self.pictures = loaded_pics
  end

  function fl3DText:PlayerInitialized(player)
    netstream.Start(player, 'flLoad3DTexts', self.texts)
    netstream.Start(player, 'flLoad3DPictures', self.pictures)
  end

  function fl3DText:LoadData()
    self:Load()
  end

  function fl3DText:SaveData()
    self:Save()
  end

  function fl3DText:AddText(data)
    if !data or !data.text or !data.pos or !data.angle or !data.style or !data.scale then return end

    table.insert(fl3DText.texts, data)

    self:Save()

    netstream.Start(nil, 'fl3DText_Add', data)
  end

  function fl3DText:AddPicture(data)
    if !data or !data.url or !data.width or !data.height then return end

    table.insert(fl3DText.pictures, data)

    self:Save()

    netstream.Start(nil, 'fl3DPicture_Add', data)
  end

  function fl3DText:Remove(player)
    if player:can('textremove') then
      netstream.Start(player, 'fl3DText_Calculate', true)
    end
  end

  function fl3DText:RemovePicture(player)
    if player:can('textremove') then
      netstream.Start(player, 'fl3DPicture_Calculate', true)
    end
  end

  netstream.Hook('fl3DText_Remove', function(player, idx)
    if player:can('textremove') then
      table.remove(fl3DText.texts, idx)

      fl3DText:Save()

      netstream.Start(nil, 'fl3DText_Remove', idx)

      fl.player:notify(player, t'3d_text.text_removed')
    end
  end)

  netstream.Hook('fl3DPicture_Remove', function(player, idx)
    if player:can('textremove') then
      table.remove(fl3DText.pictures, idx)

      fl3DText:Save()

      netstream.Start(nil, 'fl3DPicture_Remove', idx)

      fl.player:notify(player, t'3d_picture.removed')
    end
  end)
else
  netstream.Hook('flLoad3DTexts', function(data)
    fl3DText.texts = data or {}
  end)

  netstream.Hook('fl3DText_Add', function(data)
    table.insert(fl3DText.texts, data)
  end)

  netstream.Hook('fl3DText_Remove', function(idx)
    table.remove(fl3DText.texts, idx)
  end)

  netstream.Hook('flLoad3DPictures', function(data)
    fl3DText.pictures = data or {}
  end)

  netstream.Hook('fl3DPicture_Add', function(data)
    table.insert(fl3DText.pictures, data)
  end)

  netstream.Hook('fl3DPicture_Remove', function(idx)
    table.remove(fl3DText.pictures, idx)
  end)

  netstream.Hook('fl3DText_Calculate', function()
    fl3DText:RemoveAtTrace(fl.client:GetEyeTraceNoCursor())
  end)

  netstream.Hook('fl3DPicture_Calculate', function()
    fl3DText:RemovePictureAtTrace(fl.client:GetEyeTraceNoCursor())
  end)

  function fl3DText:RemoveAtTrace(trace)
    if !trace then return false end

    local hit_pos = trace.HitPos - trace.HitNormal
    local trace_start = trace.StartPos

    for k, v in pairs(self.texts) do
      local pos = v.pos
      local normal = v.normal
      local ang = normal:Angle()
      local w, h = util.text_size(v.text, theme.get_font('text_3d2d'))
      local ang_right = -ang:Right()
      local start_pos = pos - ang_right * (w * 0.05) * v.scale
      local end_pos = pos + ang_right * (w * 0.05) * v.scale

      if math.abs(math.abs(hit_pos.z) - math.abs(pos.z)) < 4 * v.scale then
        if util.vectors_intersect(trace_start, hit_pos, start_pos, end_pos) then
          netstream.Start('fl3DText_Remove', k)

          return true
        end
      end
    end

    return false
  end

  function fl3DText:RemovePictureAtTrace(trace)
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
          netstream.Start('fl3DPicture_Remove', k)

          return true
        end
      end
    end

    return false
  end
end
