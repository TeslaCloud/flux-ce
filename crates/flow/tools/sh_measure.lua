TOOL.Category               = 'Flux'
TOOL.Name                   = 'Measure Tool'
TOOL.Command                = nil
TOOL.ConfigName             = ''
TOOL.ClientConVar['system'] = 'imperial'

function TOOL:LeftClick(trace)
  if SERVER then return true end

  self.first = trace.HitPos

  return true
end

function TOOL:RightClick(trace)
  if SERVER then return true end

  self.second = trace.HitPos

  return true
end

function TOOL:Reload(trace)
  if SERVER then return true end

  self.first = nil
  self.second = nil

  return true
end

function TOOL:DrawHUD()
  local system = self:GetClientInfo('system')

  if self.first and self.second then
    cam.Start3D()
      render.DrawLine(self.first, self.second, color_white)
    cam.End3D()

    local text = Unit:format(self.first:Distance(self.second), system)
    local font = Theme.get_font('tooltip_normal')
    local text_w, text_h = util.text_size(text, font)
    local x, y = ScrC()

    draw.SimpleTextOutlined(text, font, x - text_w * 0.5, y + text_h * 2, color_white, nil, nil, 1, color_black)
  end
end

local units = {
  'imperial',
  'metric',
  'units'
}

function TOOL.BuildCPanel(CPanel)
  local options = {}

  for _, unit_name in ipairs(units) do
    options[t('ui.unit.'..unit_name)] = { ['measure_system'] = unit_name }
  end

  local units = CPanel:AddControl('ComboBox', { MenuButton = 1, Folder = 'units', Options = options, CVars = { 'measure_system' } })
end
