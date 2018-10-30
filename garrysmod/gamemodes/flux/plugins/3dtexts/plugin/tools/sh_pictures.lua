TOOL.Category = 'Flux'
TOOL.Name = 'Picture Placer'
TOOL.Command = nil
TOOL.ConfigName = ''

TOOL.ClientConVar['url'] = ''
TOOL.ClientConVar['width'] = '512'
TOOL.ClientConVar['height'] = '512'
TOOL.ClientConVar['fade'] = '0'

function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  if !IsValid(player) or !player:can('textadd') then return end

  local url = self:GetClientInfo('url')
  local width = self:GetClientNumber('width')
  local height = self:GetClientNumber('height')
  local fade_offset = self:GetClientNumber('fade')

  if !url or url == '' then return false end
  if !url:ends('.png') and !url:ends('jpeg') and !url:ends('jpg') then return false end

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

  SurfaceText:AddPicture(data)

  fl.player:notify(player, '3d_picture.placed')

  return true
end

function TOOL:RightClick(trace)
  if CLIENT then return true end

  SurfaceText:RemovePicture(self:GetOwner())

  return true
end

function TOOL.BuildCPanel(CPanel)
  CPanel:AddControl('Header',  { Description = t'tool.texts.desc' })
  CPanel:AddControl('TextBox', { Label = t'tool.pictures.url', Command = 'pictures_url', MaxLenth = '256' })
  CPanel:AddControl('Slider',  { Label = t'tool.pictures.width', Command = 'pictures_width', Type = 'Integer', Min = 1, Max = 4000 })
  CPanel:AddControl('Slider',  { Label = t'tool.pictures.height', Command = 'pictures_height', Type = 'Integer', Min = 1, Max = 4000 })
  CPanel:AddControl('Slider',  { Label = t'tool.pictures.fade', Command = 'pictures_fade', Type = 'Integer', Min = -1024, Max = 10000 })
end
