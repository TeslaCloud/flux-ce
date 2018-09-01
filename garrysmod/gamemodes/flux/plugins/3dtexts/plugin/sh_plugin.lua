PLUGIN:set_alias("fl3DText")

fl3DText.stored = fl3DText.stored or {}

util.include("cl_hooks.lua")

if SERVER then
  function fl3DText:Save()
    data.SavePlugin("3dtexts", fl3DText.stored)
  end

  function fl3DText:Load()
    local loaded = data.LoadPlugin("3dtexts", {})

    self.stored = loaded
  end

  function fl3DText:PlayerInitialized(player)
    netstream.Start(player, "flLoad3DTexts", self.stored)
  end

  function fl3DText:LoadData()
    self:Load()
  end

  function fl3DText:SaveData()
    self:Save()
  end

  function fl3DText:AddText(data)
    if (!data or !data.text or !data.pos or !data.angle or !data.style or !data.scale) then return end

    table.insert(fl3DText.stored, data)

    self:Save()

    netstream.Start(nil, "fl3DText_Add", data)
  end

  function fl3DText:Remove(player)
    if (player:HasPermission("textremove")) then
      netstream.Start(player, "fl3DText_Calculate", true)
    end
  end

  netstream.Hook("fl3DText_Remove", function(player, idx)
    if (player:HasPermission("textremove")) then
      table.remove(fl3DText.stored, idx)

      fl3DText:Save()

      netstream.Start(nil, "fl3DText_Remove", idx)

      fl.player:Notify(player, t('3d_text.text_removed'))
    end
  end)
else
  netstream.Hook("flLoad3DTexts", function(data)
    fl3DText.stored = data or {}
  end)

  netstream.Hook("fl3DText_Add", function(data)
    table.insert(fl3DText.stored, data)
  end)

  netstream.Hook("fl3DText_Remove", function(idx)
    table.remove(fl3DText.stored, idx)
  end)

  netstream.Hook("fl3DText_Calculate", function()
    fl3DText:RemoveAtTrace(fl.client:GetEyeTraceNoCursor())
  end)

  function fl3DText:RemoveAtTrace(trace)
    if (!trace) then return false end

    local hitPos = trace.HitPos
    local traceStart = trace.StartPos

    for k, v in pairs(self.stored) do
      local pos = v.pos
      local normal = v.normal
      local ang = normal:Angle()
      local w, h = util.text_size(v.text, theme.GetFont("Text_3D2D"))
      local startPos = pos - -ang:Right() * (w * 0.50) * v.scale
      local end_pos = pos + -ang:Right() * (w * 0.50) * v.scale

      if (math.abs(math.abs(hitPos.z) - math.abs(pos.z)) < 4 * v.scale) then
        if (util.vectors_intersect(traceStart, hitPos, startPos, end_pos)) then
          netstream.Start("fl3DText_Remove", k)

          return true
        end
      end
    end

    return false
  end
end
