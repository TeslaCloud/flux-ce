TOOL.Category = 'Flux'
TOOL.Name = 'Text Tool'
TOOL.Command = nil
TOOL.ConfigName = ''

TOOL.ClientConVar['text'] = 'Sample Text'
TOOL.ClientConVar['style'] = '1'
TOOL.ClientConVar['scale'] = '1'
TOOL.ClientConVar['fade'] = '0'
TOOL.ClientConVar['r'] = 255
TOOL.ClientConVar['g'] = 255
TOOL.ClientConVar['b'] = 255
TOOL.ClientConVar['a'] = 255
TOOL.ClientConVar['r2'] = 255
TOOL.ClientConVar['g2'] = 0
TOOL.ClientConVar['b2'] = 0
TOOL.ClientConVar['a2'] = 100

function TOOL:LeftClick(trace)
  if CLIENT then return true end

  local player = self:GetOwner()

  if !IsValid(player) or !player:can('textadd') then return end

  local text = self:GetClientInfo('text')
  local style = self:GetClientNumber('style')
  local scale = self:GetClientNumber('scale')
  local color = Color(self:GetClientNumber('r', 0), self:GetClientNumber('g', 0), self:GetClientNumber('b', 0), self:GetClientNumber('a', 0))
  local extra_color = Color(self:GetClientNumber('r2', 0), self:GetClientNumber('g2', 0), self:GetClientNumber('b2', 0), self:GetClientNumber('a2', 0))
  local fade_offset = self:GetClientNumber('fade')

  if !text or text == '' then return false end

  local angle = trace.HitNormal:Angle()
  angle:RotateAroundAxis(angle:Forward(), 90)
  angle:RotateAroundAxis(angle:Right(), 270)

  local data = {
    text = text,
    style = style,
    color = color,
    extra_color = extra_color,
    angle = angle,
    pos = trace.HitPos,
    normal = trace.HitNormal,
    scale = scale,
    fade_offset = fade_offset
  }

  SurfaceText:AddText(data)

  fl.player:notify(player, '3d_text.text_added')

  return true
end

function TOOL:RightClick(trace)
  if CLIENT then return true end

  SurfaceText:Remove(self:GetOwner())

  return true
end

local textStyles = {
  ['tool.texts.opt1'] = 1,
  ['tool.texts.opt2'] = 2,
  ['tool.texts.opt3'] = 3,
  ['tool.texts.opt4'] = 4,
  ['tool.texts.opt5'] = 5,
  ['tool.texts.opt6'] = 6,
  ['tool.texts.opt7'] = 7,
  ['tool.texts.opt8'] = 8,
  ['tool.texts.opt9'] = 9,
  ['tool.texts.opt91'] = 10
}

function TOOL.BuildCPanel(CPanel)
  local options = {}

  for k, v in pairs(textStyles) do
    options[t(k)] = {['texts_style'] = v}
  end

  CPanel:AddControl('Header', { Description = t'tool.texts.desc' })

  local control_resets = CPanel:AddControl('ComboBox', { MenuButton = 1, Folder = 'textstyle', Options = options, CVars = {'texts_style'} })
  control_resets.Button:SetVisible(false)
  control_resets.DropDown:SetValue('Please Choose')

  CPanel:AddControl('TextBox', { Label = t'tool.texts.text', Command = 'texts_text', MaxLenth = '128' })
  CPanel:AddControl('Color', { Label = t'tool.texts.color', Red = 'texts_r', Green = 'texts_g', Blue = 'texts_b', Alpha = 'texts_a' })
  CPanel:AddControl('Color', { Label = t'tool.texts.extra_color', Red = 'texts_r2', Green = 'texts_g2', Blue = 'texts_b2', Alpha = 'texts_a2' })
  CPanel:AddControl('Slider', { Label = t'tool.texts.scale', Command = 'texts_scale', Type = 'Float', Min = 0.01, Max = 10 })
  CPanel:AddControl('Slider', { Label = t'tool.texts.fade', Command = 'texts_fade', Type = 'Integer', Min = -1024, Max = 10000 })
end
