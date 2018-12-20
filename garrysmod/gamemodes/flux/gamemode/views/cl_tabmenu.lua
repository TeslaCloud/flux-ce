local PANEL = {}
PANEL.menu_items = {}
PANEL.buttons = {}
PANEL.active_panel = nil

function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  self:SetPos(0, 0)
  self:SetSize(scrw, scrh)

  local cur_x, cur_y = hook.run('AdjustMenuItemPositions', self)
  local offset = font.scale(4)
  local size_x, size_y = font.scale(72), font.scale(72)
  local icon_size = 40

  cur_x = cur_x or 0
  cur_y = cur_y or 0

  self.close_button = vgui.Create('fl_button', self)
  self.close_button:SetPos(cur_x, cur_y)
  self.close_button:SetDrawBackground(false)
  self.close_button:SetFont(theme.get_font('menu_larger'))
  self.close_button:set_text(t'tab_menu.close_menu')
  self.close_button:set_centered(true)
  self.close_button:set_text_offset(offset)
  self.close_button:SizeToContents()
  self.close_button:SetTall(size_y)
  self.close_button.DoClick = function(btn)
    surface.PlaySound('garrysmod/ui_click.wav')

    self:SetVisible(false)
    self:Remove()
  end

  cur_x = cur_x + self.close_button:GetWide() + size_x

  self.menu_items = {}

  hook.run('AddTabMenuItems', self)

  for k, v in ipairs(self.menu_items) do
    local button = vgui.Create('fl_button', self)
    button:SetSize(size_x, size_y)
    button:SetDrawBackground(false)
    button:SetPos(cur_x, cur_y)
    button:SetTooltip(v.title)
    button:set_icon(v.icon)
    button:set_icon_size(icon_size)
    button:set_centered(true)

    button.DoClick = function(btn)
      if v.override then
        v.override(self, btn)

        return
      end

      if v.panel then
        surface.PlaySound('garrysmod/ui_hover.wav')

        if IsValid(self.active_panel) then
          self.active_panel:safe_remove()

          self.active_button:set_text_color(nil)
        end

        self.active_panel = vgui.Create(v.panel, self)

        if self.active_panel.get_menu_size then
          self.active_panel:SetSize(self.active_panel:get_menu_size())
        else
          self.active_panel:SetSize(scrw * 0.5, scrh * 0.5)
        end

        self.active_button = btn
        self.active_button:set_text_color(theme.get_color('accent'))

        if self.active_panel.rebuild then
          self.active_panel:rebuild()
        end

        hook.run('OnMenuPanelOpen', self, self.active_panel)
      end

      if v.callback then
        v.callback(self, button)
      end
    end

    cur_x = cur_x + button:GetWide() + offset

    if cur_x >= ScrW() - button:GetWide() + offset then
      cur_y = cur_y + offset
      cur_x = offset
    end

    self.buttons[k] = button
  end

  draw.set_blur_size(1)
  fl.blur_update_fps = 0

  self.lerpStart = SysTime()
end

function PANEL:Think()
  if !IsValid(self.active_panel) and IsValid(self.active_button) then
    self.active_button:set_text_color(nil)
  end
end

function PANEL:OnMousePressed()
  if IsValid(self.active_panel) then
    self.active_panel:SetVisible(false)
    self.active_panel:Remove()
  end
end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_TAB then
    self.close_button.DoClick()
  end
end

function PANEL:Paint(w, h)
  theme.hook('PaintTabMenu', self, w, h)
end

function PANEL:add_menu_item(id, data, index)
  data.id = id
  data.title = string.utf8upper(data.title or 'error')
  data.icon = data.icon or false

  if isnumber(index) then
    table.insert(self.menu_items, index, data)
  else
    table.insert(self.menu_items, data)
  end
end

function PANEL:close_menu()
  self:SetVisible(false)
  self:Remove()
  draw.set_blur_size(12)
  fl.blur_update_fps = 8
end

vgui.Register('fl_tab_menu', PANEL, 'EditablePanel')
