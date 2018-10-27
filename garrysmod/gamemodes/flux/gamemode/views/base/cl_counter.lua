local PANEL = {}
PANEL.m_value = 1
PANEL.m_max = 0
PANEL.m_min = 100
PANEL.m_font = 'flRoboto'
PANEL.m_color = Color('white')

function PANEL:Init()
  self.label = vgui.Create('DLabel', self)
  self.label:SetText(self.m_Title)
  self.label:SetFont(self.m_font)
  self.label:SetTextColor(self.m_color)

  self.inc = vgui.Create('fl_button', self)
  self.inc:SetIcon('fa-chevron-up')
  self.inc:SetIconSize(16)
  self.inc:SetCentered(true)
  self.inc:SetDrawBackground(false)
  self.inc.DoClick = function(button)
    self:OnIncrease()
  end

  self.dec = vgui.Create('fl_button', self)
  self.dec:SetIcon('fa-chevron-down')
  self.dec:SetIconSize(16)
  self.dec:SetCentered(true)
  self.dec:SetDrawBackground(false)
  self.dec.DoClick = function(button)
    self:OnDecrease()
  end
end

function PANEL:PerformLayout(w, h)
  self.label:SizeToContents()
  self.label:SetPos(w * 0.5 - self.label:GetWide() * 0.5, 2)

  self.inc:SetPos(2, self.label:GetTall() + 2)
  self.inc:SetSize(w - 4, h * 0.25 - 2)

  self.dec:SetPos(2, h * 0.75 + 2)
  self.dec:SetSize(w - 4, h * 0.25 - 2)

  self:CheckButtons(self.m_value)
end

function PANEL:Paint(w, h)
  local x, y = util.text_size(self.m_value, self.m_font)
  draw.SimpleText(self.m_value, self.m_font, w * 0.5 - x * 0.5, h * 0.66 - y * 0.5, self.m_color)
end

function PANEL:SetText(text)
  self.m_Title = text

  self.label:SetText(self.m_Title)
end

function PANEL:SetMax(max)
  self.m_max = max
end

function PANEL:SetMin(min)
  self.m_min = min
end

function PANEL:SetMinMax(min, max)
  self.m_min = min
  self.m_max = max
end

function PANEL:SetValue(value)
  self.m_value = value
end

function PANEL:SetFont(font)
  self.m_font = font

  self.label:SetFont(self.m_font)
end

function PANEL:SetColor(color)
  self.m_color = color

  self.label:SetTextColor(self.m_color)
end

function PANEL:GetValue()
  return self.m_value
end

function PANEL:OnIncrease(button)
  self.m_value = math.Clamp(self.m_value + 1, self.m_min, self.m_max)

  self:OnClick(self.m_value)
  self:CheckButtons(self.m_value)
end

function PANEL:OnDecrease(button)
  self.m_value = math.Clamp(self.m_value - 1, self.m_min, self.m_max)

  self:OnClick(self.m_value)
  self:CheckButtons(self.m_value)
end

function PANEL:CheckButtons(value)
  if value == self.m_max then
    self.inc:SetEnabled(false)
    self.inc:SetActive(false)
  elseif value == self.m_min then
    self.dec:SetEnabled(false)
    self.dec:SetActive(false)
  else
    self.inc:SetEnabled(true)
    self.inc:SetActive(true)
    self.dec:SetEnabled(true)
    self.dec:SetActive(true)
  end
end

function PANEL:OnClick(value)

end

vgui.Register('fl_counter', PANEL, 'fl_base_panel')
