TOOL.Category = 'Flux'
TOOL.Name = 'Picture Placer'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'pictures'

TOOL.ClientConVar['url'] = ''
TOOL.ClientConVar['width'] = '512'
TOOL.ClientConVar['height'] = '512'
TOOL.ClientConVar['fade'] = '0'

--- Places a 3D picture built from the tool's settings on the surface that was hit.
-- The URL must end with png, jpg or jpeg.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if the picture was placed (always true clientside), false if the
--   URL is invalid, nil if the owner lacks the 'textadd' permission]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('textadd') then return end

  local url = self:GetClientInfo('url')
  local width = self:GetClientNumber('width')
  local height = self:GetClientNumber('height')
  local fade_offset = self:GetClientNumber('fade')

  if !url or url == '' then return false end
  if !url:end_with('.png') and !url:end_with('jpeg') and !url:end_with('jpg') then return false end

  local angle = trace.HitNormal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  local data = {
    url = url,
    width = width,
    height = height,
    fade_offset = fade_offset,
    angle = angle,
    pos = trace.HitPos,
    normal = trace.HitNormal
  }

  SurfaceText:add_picture(data)

  owner:notify('notification.3d_picture.placed')

  return true
end

--- Requests removal of the 3D picture the tool owner is looking at.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean always true]
function TOOL:RightClick(trace)
  if CLIENT then return true end

  SurfaceText:remove_picture(self:GetOwner())

  return true
end

--- Builds the tool's settings panel: picture URL, width, height and fade offset.
-- @param CPanel [Panel the tool's control panel]
function TOOL.BuildCPanel(CPanel)
  CPanel:AddControl('Header',  { Description = t'tool.pictures.desc' })
  CPanel:AddControl('TextBox', { Label = t'tool.pictures.url', Command = 'pictures_url', MaxLenth = '256' })
  CPanel:AddControl('Slider',  { Label = t'tool.pictures.width', Command = 'pictures_width', Type = 'Integer', Min = 1, Max = 4000 })
  CPanel:AddControl('Slider',  { Label = t'tool.pictures.height', Command = 'pictures_height', Type = 'Integer', Min = 1, Max = 4000 })
  CPanel:AddControl('Slider',  { Label = t'tool.pictures.fade', Command = 'pictures_fade', Type = 'Integer', Min = -1024, Max = 10000 })
end
