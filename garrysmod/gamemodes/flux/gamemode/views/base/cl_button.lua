local PANEL = {}

PANEL.m_Title = ''
PANEL.m_Icon = false
PANEL.m_Autopos = true
PANEL.m_CurAmt = 0
PANEL.m_Active = false
PANEL.m_IconSize = nil
PANEL.m_IconLeft = true
PANEL.m_Enabled = true
PANEL.m_Centered = false

function PANEL:Paint(w, h)
  theme.Hook('PaintButton', self, w, h)
end

function PANEL:Think()
  self.BaseClass.Think(self)

  local frameTime = FrameTime() / 0.006

  if self:IsHovered() then
    self.m_CurAmt = math.Clamp(self.m_CurAmt + 1 * frameTime, 0, 40)
  else
    self.m_CurAmt = math.Clamp(self.m_CurAmt - 1 * frameTime, 0, 40)
  end

  if !self.m_IconSizeOverride then
    self.m_IconSize = self:GetTall() - 6
  end
end

function PANEL:SetCentered(bCentered)
  self.m_Centered = bCentered
end

function PANEL:SetActive(active)
  self.m_Active = active
end

function PANEL:IsActive()
  return self.m_Active
end

function PANEL:Toggle()
  self.m_Active = !self.m_Active
end

function PANEL:SetEnabled(enabled)
  self.m_Enabled = enabled
  self.m_TextColorOverride = (!enabled and theme.GetColor('text'):darken(50)) or nil

  self:SetMouseInputEnabled(enabled)
end

function PANEL:SetTextColor(color)
  self.m_TextColorOverride = color
end

function PANEL:SetText(newText)
  return self:SetTitle(newText)
end

function PANEL:SetTextOffset(pos)
  self.m_TextPos = pos or 0
end

function PANEL:SetIcon(icon, bRight)
  self.m_Icon = tostring(icon) or false

  if bRight then
    self.m_IconLeft = false
  end
end

function PANEL:SetIconSize(size)
  self.m_IconSize = size
  self.m_IconSizeOverride = true
end

function PANEL:OnMousePressed(key)
  if key == MOUSE_LEFT then
    if self.DoClick then
      self:DoClick()
    end
  elseif key == MOUSE_RIGHT then
    if self.DoRightClick then
      self:DoRightClick()
    end
  end
end

function PANEL:SetTextAutoposition(bAutoposition)
  self.m_Autopos = bAutoposition
end

function PANEL:SizeToContents()
  local w, h = util.text_size(self.m_Title, self.m_Font)
  local add = 0

  if self.m_Icon then
    add = h * 1.5 - 2
  end

  self:SetSize(w * 1.15 + add, h * 1.5)
end

vgui.Register('fl_button', PANEL, 'fl_base_panel')
