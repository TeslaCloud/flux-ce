local PANEL = {}
PANEL.menu_items = {}
PANEL.buttons = {}
PANEL.active_panel = nil

function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  self:SetPos(0, 0)
  self:SetSize(scrw, scrh)

  local cur_x, cur_y = hook.run('AdjustMenuItemPositions', self)
  cur_x = cur_x or 42
  cur_y = cur_y or 200

  self.closeButton = vgui.Create('fl_button', self)
  self.closeButton:SetFont(theme.get_font('menu_large'))
  self.closeButton:SetText(string.utf8upper(t'tab_menu.close_menu'))
  self.closeButton:SetPos(6, cur_y)
  self.closeButton:SetSizeEx(200, 38)
  self.closeButton:SetDrawBackground(false)
  self.closeButton:SetTextAutoposition(true)
  self.closeButton.DoClick = function(btn)
    surface.PlaySound('garrysmod/ui_click.wav')
    self:SetVisible(false)
    self:Remove()
  end

  cur_y = cur_y + font.Scale(52)

  self.menu_items = {}

  hook.run('AddTabMenuItems', self)

  for k, v in ipairs(self.menu_items) do
    local button = vgui.Create('fl_button', self)
    button:SetDrawBackground(false)
    button:SetPos(6, cur_y)
    button:SetSizeEx(200, 30)
    button:SetText(v.title)
    button:SetIcon(v.icon)
    button:SetCentered(false)
    button:SetFont(v.font or theme.get_font('menu_normal'))

    button.DoClick = function(btn)
      if v.override then
        v.override(self, btn)

        return
      end

      if v.panel then
        surface.PlaySound('garrysmod/ui_hover.wav')

        if IsValid(self.active_panel) then
          self.active_panel:safe_remove()

          self.activeBtn:SetTextColor(nil)
        end

        self.active_panel = vgui.Create(v.panel, self)

        if self.active_panel.GetMenuSize then
          self.active_panel:SetSize(self.active_panel:GetMenuSize())
        else
          self.active_panel:SetSize(scrw * 0.5, scrh * 0.5)
        end

        self.activeBtn = btn
        self.activeBtn:SetTextColor(theme.get_color('accent_light'))

        if self.active_panel.Rebuild then
          self.active_panel:Rebuild()
        end

        hook.run('OnMenuPanelOpen', self, self.active_panel)
      end

      if v.callback then
        v.callback(self, button)
      end
    end

    cur_y = cur_y + font.Scale(38)

    self.buttons[k] = button
  end

  draw.set_blur_size(1)
  fl.blur_update_fps = 0

  self.lerpStart = SysTime()
end

function PANEL:Think()
  if !IsValid(self.active_panel) and IsValid(self.activeBtn) then
    self.activeBtn:SetTextColor(nil)
  end
end

function PANEL:AddMenuItem(id, data, index)
  data.id = id
  data.title = string.utf8upper(data.title or 'error')
  data.icon = data.icon or false

  if isnumber(index) then
    table.insert(self.menu_items, index, data)
  else
    table.insert(self.menu_items, data)
  end
end

function PANEL:CloseMenu()
  self:SetVisible(false)
  self:Remove()
  draw.set_blur_size(12)
  fl.blur_update_fps = 8
end

function PANEL:OnMousePressed()
  if IsValid(self.active_panel) then
    self.active_panel:SetVisible(false)
    self.active_panel:Remove()
  end
end

function PANEL:Paint(w, h)
  theme.hook('PaintTabMenu', self, w, h)
end

vgui.Register('fl_tab_menu', PANEL, 'EditablePanel')
