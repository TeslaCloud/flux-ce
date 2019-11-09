local PANEL = {}
PANEL.value = 1
PANEL.max = 0
PANEL.min = 100
PANEL.font = 'flRoboto'
PANEL.color = Color('white')
PANEL.title = ''

function PANEL:Init()
  local fa_icon_size = math.scale(16)

  self.label = vgui.Create('DLabel', self)
  self.label:SetText(self.title)
  self.label:SetFont(self.font)
  self.label:SetTextColor(self.color)

  self.inc = vgui.Create('fl_button', self)
  self.inc:set_icon('fa-chevron-up')
  self.inc:set_icon_size(fa_icon_size)
  self.inc:set_centered(true)
  self.inc:SetDrawBackground(false)
  self.inc.DoClick = function(btn)
    self:increase()
  end

  self.dec = vgui.Create('fl_button', self)
  self.dec:set_icon('fa-chevron-down')
  self.dec:set_icon_size(fa_icon_size)
  self.dec:set_centered(true)
  self.dec:SetDrawBackground(false)
  self.dec.DoClick = function(btn)
    self:decrease()
  end
end

function PANEL:PerformLayout(w, h)
  self.label:SizeToContents()
  self.label:SetPos(w * 0.5 - self.label:GetWide() * 0.5, math.scale(4))

  local button_height = (h - self.label:GetTall()) * 0.5
  local offset = self.label:GetValue() != '' and self.label:GetTall() or 0

  self.inc:SetSize(w, button_height)
  self.inc:SetPos(w * 0.5 - self.inc:GetWide() * 0.5, offset + math.scale(2))
  self.inc:set_icon_size(button_height * 0.75)

  self.dec:SetSize(w, button_height)
  self.dec:SetPos(w * 0.5 - self.dec:GetWide() * 0.5, h - button_height)
  self.dec:set_icon_size(button_height * 0.75)

  self:check_buttons()
end

function PANEL:Paint(w, h)
  local x, y = util.text_size(self.value, self.font)
  local offset = self.label:GetValue() != '' and self.label:GetTall() or 0
  draw.SimpleText(self.value, self.font, w * 0.5 - x * 0.5, h * 0.5 - y * 0.5 + offset * 0.5, self.color)
end

function PANEL:set_text(text)
  self.title = text

  self.label:SetText(self.title)
end

function PANEL:set_max(max)
  self.max = max
  self:check_buttons()
end

function PANEL:set_min(min)
  self.min = min
  self:check_buttons()
end

function PANEL:set_min_max(min, max)
  self.min = min
  self.max = max
  self:check_buttons()
end

function PANEL:set_value(value)
  self.value = value
  self:check_buttons()
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

function PANEL:increase()
  local old_value = self.value
  local new_value = math.clamp(self.value + 1, self.min, self.max)

  if self:on_click(new_value, old_value) != false then
    self.value = new_value
    self:check_buttons()
    self:post_click()
  end
end

function PANEL:decrease()
  local old_value = self.value
  local new_value = math.clamp(self.value - 1, self.min, self.max)

  if self:on_click(new_value, old_value) != false then
    self.value = new_value
    self:check_buttons()
    self:post_click()
  end
end

function PANEL:check_buttons()
  local value = self.value

  if value == self.max then
    self.inc:set_enabled(false)
    self.inc:set_active(false)
  else
    self.inc:set_enabled(true)
    self.inc:set_active(true)
  end

  if value == self.min then
    self.dec:set_enabled(false)
    self.dec:set_active(false)
  else
    self.dec:set_enabled(true)
    self.dec:set_active(true)
  end
end

function PANEL:on_click(value)
end

function PANEL:post_click()
end

vgui.Register('fl_counter', PANEL, 'fl_base_panel')
