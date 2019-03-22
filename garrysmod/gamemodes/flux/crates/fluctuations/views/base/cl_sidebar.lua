local PANEL = {}
PANEL.last_pos = 0
PANEL.margin = 0

function PANEL:Init()
  self.VBar.Paint = function() return true end
  self.VBar.btnUp.Paint = function() return true end
  self.VBar.btnDown.Paint = function() return true end
  self.VBar.btnGrip.Paint = function() return true end

  self:PerformLayout()

  function self:OnScrollbarAppear() return true end
end

function PANEL:Paint(width, height)
  Theme.hook('PaintSidebar', self, width, height)
end

function PANEL:Clear()
  self.BaseClass.Clear(self)
  self.last_pos = 0
end

-- 'borrowed' from lua/vgui/dscrollpanel.lua
function PANEL:PerformLayout()
  local old_height = self.pnlCanvas:GetTall()
  local old_width = self:GetWide()
  local ypos = 0

  self:Rebuild()

  self.VBar:SetUp(self:GetTall(), self.pnlCanvas:GetTall())
  ypos = self.VBar:GetOffset()

  self.pnlCanvas:SetPos(0, ypos)
  self.pnlCanvas:SetWide(old_width)

  self:Rebuild()

  if old_height != self.pnlCanvas:GetTall() then
    self.VBar:SetScroll(self.VBar:GetScroll())
  end
end

function PANEL:add_panel(panel, center)
  local x, y = panel:GetPos()

  if center then
    x = self:GetWide() * 0.5 - panel:GetWide() * 0.5
  end

  panel:SetPos(x, self.last_pos)

  self:AddItem(panel)

  self.last_pos = self.last_pos + self.margin + panel:GetTall()
end

function PANEL:add_button(text, callback)
  local button = vgui.Create('fl_button', self)
  button:SetSize(self:GetWide(), Theme.get_option('menu_sidebar_height'))
  button:SetDrawBackground(true)
  button:SetFont(Theme.get_font('text_normal_smaller'))
  button:set_text(text)
  button:set_text_autoposition(true)
  button.DoClick = function(btn)
    btn:set_active(true)

    if IsValid(self.prev_button) and self.prev_button != btn then
      self.prev_button:set_active(false)
    end
     self.prev_button = btn

    if isfunction(callback) then
      callback(btn)
    end
  end

  self:add_panel(button)

  return button
end

function PANEL:add_space(px)
  self.last_pos = self.last_pos + px
end

function PANEL:set_margin(margin)
  self.margin = tonumber(margin) or 0
end

function PANEL:center_items()
  for k, v in ipairs(self:GetCanvas():GetChildren()) do
    local x, y = v:GetPos()

    v:SetPos(self:GetWide() / 2 - v:GetWide() / 2, y)
  end
end

vgui.Register('fl_sidebar', PANEL, 'DScrollPanel')
