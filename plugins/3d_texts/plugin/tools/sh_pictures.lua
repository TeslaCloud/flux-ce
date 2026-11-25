--- The Picture Placer tool. Left click places the picture at the given URL (an `https://`
-- link to a png or jpg image) on the surface the owner is looking at, with the chosen width,
-- height and fade offset; right click removes the picture the owner is looking at. The tool
-- requires the `manage_pictures` permission, which placing and removing check as well.

TOOL.Category = 'Flux'
TOOL.Name = 'Picture Placer'
TOOL.Command = nil
TOOL.ConfigName = ''
TOOL.permission = 'manage_pictures'

TOOL.ClientConVar['url'] = ''
TOOL.ClientConVar['width'] = '512'
TOOL.ClientConVar['height'] = '512'
TOOL.ClientConVar['fade'] = '0'

--- Places a 3D picture built from the tool's settings on the surface that was hit.
-- The URL must be an `https://` link that ends with png, jpg or jpeg.
-- @param trace [Map trace result of the tool owner's aim]
-- @return [Boolean true if the picture was placed (always true clientside), false if the
--   URL is invalid, nil if the owner lacks the 'manage_pictures' permission]
function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local owner = self:GetOwner()

  if !IsValid(owner) or !owner:can('manage_pictures') then return end

  local url = self:GetClientInfo('url')
  local width = self:GetClientNumber('width')
  local height = self:GetClientNumber('height')
  local fade_offset = self:GetClientNumber('fade')

  if !SurfaceText:is_picture_url(url) then
    owner:notify('error.3d_picture.invalid_url')

    return false
  end

  local data = {
    url = url,
    width = width,
    height = height,
    fade_offset = fade_offset,
    angle = SurfaceText:surface_angle(trace.HitNormal),
    pos = trace.HitPos,
    normal = trace.HitNormal
  }

  if !SurfaceText:add_picture(data) then return false end

  owner:notify('notification.3d_picture.placed')

  return true
end

--- Requests removal of the 3D picture the tool owner is looking at.
-- @param _trace [Map trace result of the tool owner's aim]
-- @return [Boolean always true]
function TOOL:RightClick(_trace)
  if CLIENT then return true end

  SurfaceText:remove_picture(self:GetOwner())

  return true
end

--- Builds the tool's settings panel: picture URL, width, height and fade offset.
-- @param CPanel [Panel the tool's control panel]
function TOOL.BuildCPanel(CPanel)
  local limits = SurfaceText.limits

  CPanel:AddControl('Header', { Description = t'tool.pictures.desc' })
  CPanel:AddControl('TextBox', { Label = t'tool.pictures.url', Command = 'pictures_url', MaxLenth = '256' })
  CPanel:AddControl('Slider', {
    Label = t'tool.pictures.width',
    Command = 'pictures_width',
    Type = 'Integer',
    Min = limits.min_size,
    Max = limits.max_size
  })
  CPanel:AddControl('Slider', {
    Label = t'tool.pictures.height',
    Command = 'pictures_height',
    Type = 'Integer',
    Min = limits.min_size,
    Max = limits.max_size
  })
  CPanel:AddControl('Slider', {
    Label = t'tool.pictures.fade',
    Command = 'pictures_fade',
    Type = 'Integer',
    Min = limits.min_fade,
    Max = limits.max_fade
  })
end
