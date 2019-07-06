local panel_meta = FindMetaTable('Panel')

-- Seriously, Newman? I have to write this myself?
function panel_meta:undraggable()
  self.m_DragSlot = nil
end

function panel_meta:safe_remove()
  self:SetVisible(false)
  self:Remove()
end

function panel_meta:set_pos_ex(x, y)
  self:SetPos(math.scale(x), math.scale(y))
end

function panel_meta:set_size_ex(w, h)
  self:SetSize(math.scale(w), math.scale(h))
end

local model_panel = vgui.GetControlTable('DModelPanel')

function model_panel:Paint(w, h)
  local ent = self.Entity

  if !IsValid(ent) then return end

  local x, y = self:LocalToScreen(0, 0)

  self:LayoutEntity(ent)

  local ang = self.aLookAngle

  if !ang then
    ang = (self.vLookatPos - self.vCamPos):Angle()
  end

  cam.Start3D(self.vCamPos, ang, self.fFOV, x, y, w, h, 5, self.FarZ)

  -- Fix for models being behind blur texture in Z-buffer.
  if Flux.should_render_blur then cam.IgnoreZ(true) end

  render.SuppressEngineLighting(true)
  render.SetLightingOrigin(ent:GetPos())
  render.ResetModelLighting(self.colAmbientLight.r / 255, self.colAmbientLight.g / 255, self.colAmbientLight.b / 255)
  render.SetColorModulation(self.colColor.r / 255, self.colColor.g / 255, self.colColor.b / 255)
  render.SetBlend((self:GetAlpha() / 255) * (self.colColor.a / 255))

  for i = 0, 6 do
    local col = self.DirectionalLight[i]

    if col then
      render.SetModelLighting(i, col.r / 255, col.g / 255, col.b / 255)
    end
  end

  self:DrawModel()

  render.SuppressEngineLighting(false)

  -- End fix
  if Flux.should_render_blur then cam.IgnoreZ(false) end

  cam.End3D()

  self.LastPaint = RealTime()
end
