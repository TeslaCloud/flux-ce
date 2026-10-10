--- Extensions of the `Panel` metatable: removal that hides the panel first, positions and
-- sizes that scale with the screen resolution, and a way to make a panel undraggable.
-- The file also replaces the paint function of `DModelPanel` so that models stay visible
-- on top of blurred backgrounds.
-- @module [Panel]

local panel_meta = FindMetaTable('Panel')
local scale = math.scale
local suppress_engine_lighting = render.SuppressEngineLighting
local set_model_lighting = render.SetModelLighting
local color_scale = 1 / 255

-- Seriously, Newman? I have to write this myself?

--- Makes the panel no longer draggable.
function panel_meta:undraggable()
  self.m_DragSlot = nil
end

--- Hides the panel and then removes it.
function panel_meta:safe_remove()
  self:SetVisible(false)
  self:Remove()
end

--- Sets the position of the panel, scaling the coordinates to the screen resolution.
-- @param x [Number x coordinate at 1080p]
-- @param y [Number y coordinate at 1080p]
function panel_meta:set_pos_ex(x, y)
  self:SetPos(scale(x), scale(y))
end

--- Sets the size of the panel, scaling it to the screen resolution.
-- @param w [Number width at 1080p]
-- @param h [Number height at 1080p]
function panel_meta:set_size_ex(w, h)
  self:SetSize(scale(w), scale(h))
end

local model_panel = vgui.GetControlTable('DModelPanel')

--- Replaces the paint function of DModelPanel with one that keeps the model visible
-- on top of blurred backgrounds.
-- @param w [Number width of the panel]
-- @param h [Number height of the panel]
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

  local ignore_z = Flux.should_render_blur
  local ambient, color = self.colAmbientLight, self.colColor
  local directional_light = self.DirectionalLight

  -- Fix for models being behind the blur texture in the Z-buffer.
  if ignore_z then cam.IgnoreZ(true) end

  suppress_engine_lighting(true)
  render.SetLightingOrigin(ent:GetPos())
  render.ResetModelLighting(ambient.r * color_scale, ambient.g * color_scale, ambient.b * color_scale)
  render.SetColorModulation(color.r * color_scale, color.g * color_scale, color.b * color_scale)
  render.SetBlend((self:GetAlpha() * color_scale) * (color.a * color_scale))

  for i = 0, 6 do
    local col = directional_light[i]

    if col then
      set_model_lighting(i, col.r * color_scale, col.g * color_scale, col.b * color_scale)
    end
  end

  self:DrawModel()

  suppress_engine_lighting(false)

  -- End fix
  if ignore_z then cam.IgnoreZ(false) end

  cam.End3D()

  self.LastPaint = RealTime()
end
