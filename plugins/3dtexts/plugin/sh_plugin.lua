PLUGIN:set_global('SurfaceText')

SurfaceText.texts = SurfaceText.texts or {}
SurfaceText.pictures = SurfaceText.pictures or {}

require_relative 'cl_hooks'

function SurfaceText:RegisterPermissions()
  Bolt:register_permission('texts', 'Place / delete texts', 'Grants access to place and delete texts.', 'permission.categories.level_design', 'assistent')
  Bolt:register_permission('pictures', 'Place / delete pictures', 'Grants access to place and delete pictures.', 'permission.categories.level_design', 'assistent')
end

if SERVER then
  function SurfaceText:PlayerInitialized(player)
    Cable.send(player, 'fl_surface_text_load', self.texts)
    Cable.send(player, 'fl_surface_picture_load', self.pictures)
  end

  function SurfaceText:LoadData()
    self:load()
  end

  function SurfaceText:SaveData()
    self:save()
  end

  function SurfaceText:save()
    Data.save_plugin('3dtexts', SurfaceText.texts)
    Data.save_plugin('3dpictures', SurfaceText.pictures)
  end

  function SurfaceText:load()
    local loaded = Data.load_plugin('3dtexts', {})
    local loaded_pics = Data.load_plugin('3dpictures', {})

    self.texts = loaded
    self.pictures = loaded_pics
  end

  function SurfaceText:add_text(data)
    if !data or !data.text or !data.pos or !data.angle or !data.style or !data.scale then return end

    table.insert(SurfaceText.texts, data)

    self:save()

    Cable.send(nil, 'fl_surface_text_add', data)
  end

  function SurfaceText:add_picture(data)
    if !data or !data.url or !data.width or !data.height then return end

    table.insert(SurfaceText.pictures, data)

    self:save()

    Cable.send(nil, 'fl_surface_picture_add', data)
  end

  function SurfaceText:remove_text(player)
    if player:can('textremove') then
      Cable.send(player, 'fl_surface_text_calculate', true)
    end
  end

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

      Flux.Player:notify(player, t'notification.3d_text.text_removed')
    end
  end)

  Cable.receive('fl_surface_picture_remove', function(player, idx)
    if player:can('textremove') then
      table.remove(SurfaceText.pictures, idx)

      SurfaceText:save()

      Cable.send(nil, 'fl_surface_picture_remove', idx)

      Flux.Player:notify(player, t'notification.3d_picture.removed')
    end
  end)
else
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
