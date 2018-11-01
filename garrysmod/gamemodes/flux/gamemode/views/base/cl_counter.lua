local PANEL = {}
PANEL.value = 1
PANEL.max = 0
PANEL.min = 100
PANEL.font = 'flRoboto'
PANEL.color = Color('white')

function PANEL:Init()
  self.label = vgui.Create('DLabel', self)
  self.label:SetText(self.title)
  self.label:SetFont(self.font)
  self.label:SetTextColor(self.color)

  self.inc = vgui.Create('fl_button', self)
  self.inc:set_icon('fa-chevron-up')
  self.inc:set_icon_size(16)
  self.inc:set_centered(true)
  self.inc:SetDrawBackground(false)
  self.inc.DoClick = function(btn)
    self:increase()
  end

  self.dec = vgui.Create('fl_button', self)
  self.dec:set_icon('fa-chevron-down')
  self.dec:set_icon_size(16)
  self.dec:set_centered(true)
  self.dec:SetDrawBackground(false)
  self.dec.DoClick = function(btn)
    self:decrease()
  end
end

function PANEL:PerformLayout(w, h)
  self.label:SizeToContents()
  self.label:SetPos(w * 0.5 - self.label:GetWide() * 0.5, 2)

  self.inc:SetPos(2, self.label:GetTall() + 2)
  self.inc:SetSize(w - 4, h * 0.25 - 2)

  self.dec:SetPos(2, h * 0.75 + 2)
  self.dec:SetSize(w - 4, h * 0.25 - 2)

  self:check_buttons(self.value)
end

function PANEL:Paint(w, h)
  local x, y = util.text_size(self.value, self.font)
  draw.SimpleText(self.value, self.font, w * 0.5 - x * 0.5, h * 0.66 - y * 0.5, self.color)
end

function PANEL:set_text(text)
  self.title = text

  self.label:SetText(self.title)
end

function PANEL:set_max(max)
  self.max = max
end

function PANEL:set_min(min)
  self.min = min
end

function PANEL:set_min_max(min, max)
  self.min = min
  self.max = max
end

function PANEL:set_value(value)
  self.value = value
end

function PANEL:set_font(font)
  self.font = font

  self.label:SetFont(self.font)
end

function PANEL:set_color(color)
  self.color = color

  self.label:SetTextColor(self.color)
end

function PANEL:get_value()
  return self.value
end

function PANEL:increase(button)
  self.value = math.Clamp(self.value + 1, self.min, self.max)

  self:on_click(self.value)
  self:check_buttons(self.value)
end

function PANEL:decrease(button)
  self.value = math.Clamp(self.value - 1, self.min, self.max)

  self:on_click(self.value)
  self:check_buttons(self.value)
end

function PANEL:check_buttons(value)
  if value == self.max then
    self.inc:set_enabled(false)
    self.inc:set_active(false)
  elseif value == self.min then
    self.dec:set_enabled(false)
    self.dec:set_active(false)
  else
    self.inc:set_enabled(true)
    self.inc:set_active(true)
    self.dec:set_enabled(true)
    self.dec:set_active(true)
  end
end

function PANEL:on_click(value)
end

vgui.Register('fl_counter', PANEL, 'fl_base_panel')
