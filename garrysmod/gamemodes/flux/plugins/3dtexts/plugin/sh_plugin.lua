PLUGIN:set_global('SurfaceText')

SurfaceText.texts = SurfaceText.texts or {}
SurfaceText.pictures = SurfaceText.pictures or {}

util.include('cl_hooks.lua')

if SERVER then
  function SurfaceText:Save()
    data.save_plugin('3dtexts', SurfaceText.texts)
    data.save_plugin('3dpictures', SurfaceText.pictures)
  end

  function SurfaceText:Load()
    local loaded = data.load_plugin('3dtexts', {})
    local loaded_pics = data.load_plugin('3dpictures', {})

    self.texts = loaded
    self.pictures = loaded_pics
  end

  function SurfaceText:PlayerInitialized(player)
    cable.send(player, 'flLoad3DTexts', self.texts)
    cable.send(player, 'flLoad3DPictures', self.pictures)
  end

  function SurfaceText:LoadData()
    self:Load()
  end

  function SurfaceText:SaveData()
    self:Save()
  end

  function SurfaceText:AddText(data)
    if !data or !data.text or !data.pos or !data.angle or !data.style or !data.scale then return end

    table.insert(SurfaceText.texts, data)

    self:Save()

    cable.send(nil, 'SurfaceText_Add', data)
  end

  function SurfaceText:AddPicture(data)
    if !data or !data.url or !data.width or !data.height then return end

    table.insert(SurfaceText.pictures, data)

    self:Save()

    cable.send(nil, 'fl3DPicture_Add', data)
  end

  function SurfaceText:Remove(player)
    if player:can('textremove') then
      cable.send(player, 'SurfaceText_Calculate', true)
    end
  end

  function SurfaceText:RemovePicture(player)
    if player:can('textremove') then
      cable.send(player, 'fl3DPicture_Calculate', true)
    end
  end

  cable.receive('SurfaceText_Remove', function(player, idx)
    if player:can('textremove') then
      table.remove(SurfaceText.texts, idx)

      SurfaceText:Save()

      cable.send(nil, 'SurfaceText_Remove', idx)

      fl.player:notify(player, t'3d_text.text_removed')
    end
  end)

  cable.receive('fl3DPicture_Remove', function(player, idx)
    if player:can('textremove') then
      table.remove(SurfaceText.pictures, idx)

      SurfaceText:Save()

      cable.send(nil, 'fl3DPicture_Remove', idx)

      fl.player:notify(player, t'3d_picture.removed')
    end
  end)
else
  cable.receive('flLoad3DTexts', function(data)
    SurfaceText.texts = data or {}
  end)

  cable.receive('SurfaceText_Add', function(data)
    table.insert(SurfaceText.texts, data)
  end)

  cable.receive('SurfaceText_Remove', function(idx)
    table.remove(SurfaceText.texts, idx)
  end)

  cable.receive('flLoad3DPictures', function(data)
    SurfaceText.pictures = data or {}
  end)

  cable.receive('fl3DPicture_Add', function(data)
    table.insert(SurfaceText.pictures, data)
  end)

  cable.receive('fl3DPicture_Remove', function(idx)
    table.remove(SurfaceText.pictures, idx)
  end)

  cable.receive('SurfaceText_Calculate', function()
    SurfaceText:RemoveAtTrace(fl.client:GetEyeTraceNoCursor())
  end)

  cable.receive('fl3DPicture_Calculate', function()
    SurfaceText:RemovePictureAtTrace(fl.client:GetEyeTraceNoCursor())
  end)

  function SurfaceText:RemoveAtTrace(trace)
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
          cable.send('SurfaceText_Remove', k)

          return true
        end
      end
    end

    return false
  end

  function SurfaceText:RemovePictureAtTrace(trace)
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
          cable.send('fl3DPicture_Remove', k)

          return true
        end
      end
    end

    return false
  end
end
