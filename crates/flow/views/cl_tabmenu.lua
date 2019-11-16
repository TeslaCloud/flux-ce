local PANEL = {}
PANEL.menu_items = {}
PANEL.buttons = {}
PANEL.active_panel = nil

function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  draw.set_blur_size(1)
  Flux.blur_update_fps = 0
  self.blur_target = 6

  self:SetPos(0, 0)
  self:SetSize(scrw, scrh)

  local cur_x, cur_y = hook.run('AdjustMenuItemPositions', self)
  local offset = math.scale(4)
  local size_x, size_y = math.scale(72), math.scale(72)
  local icon_size = math.scale(40)

  self.button_panel = vgui.create('EditablePanel', self)
  self.button_panel:SetPos(0, -size_y)
  self.button_panel:SetSize(scrw, size_y)
  self.button_panel.Paint = function(p, w, h)
    Theme.hook('PaintTabMenuButtonPanel', self, w, h)
  end

  self.button_panel:MoveTo(0, 0, Theme.get_option('menu_anim_duration'), 0, 0.5)

  cur_x = cur_x or 0
  cur_y = cur_y or 0

  self.close_button = vgui.Create('fl_button', self.button_panel)
  self.close_button:SetPos(cur_x, cur_y)
  self.close_button:SetDrawBackground(false)
  self.close_button:SetFont(Theme.get_font('menu_larger'))
  self.close_button:set_text(t'ui.tab_menu.close_menu')
  self.close_button:set_centered(true)
  self.close_button:set_text_offset(offset)
  self.close_button:SizeToContents()
  self.close_button:SetTall(size_y)
  self.close_button.DoClick = function(btn)
    self:close_menu()
  end

  cur_x = cur_x + self.close_button:GetWide() + size_x

  self.menu_items = {}

  hook.run('AddTabMenuItems', self)

  for k, v in ipairs(self.menu_items) do
    local button = vgui.Create('fl_button', self.button_panel)
    button:SetSize(size_x, size_y)
    button:SetDrawBackground(false)
    button:SetPos(cur_x, cur_y)
    button:SetTooltip(v.title)
    button:set_icon(v.icon)
    button:set_icon_size(icon_size)
    button:set_centered(true)

    button.DoClick = function(btn)
      if IsValid(self.active_panel) and v.id == self.active_panel.id then return end

      if v.override then
        v.override(self, btn)

        return
      end

      if v.panel then
        surface.PlaySound('garrysmod/ui_hover.wav')

        if IsValid(self.active_panel) then
          if self.active_panel.on_change then
            self.active_panel:on_change()
          end

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
        self.active_button:set_text_color(Theme.get_color('accent'))

        if self.active_panel.rebuild then
          self.active_panel:rebuild()
        end

        self.active_panel.id = v.id

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

    self.buttons[v.id] = button

    if v.default then
      self.default_panel = v.id
    end
  end

  local panel_id = PLAYER.tab_panel or self.default_panel

  if panel_id then
    self.buttons[panel_id]:DoClick()
  end
end

function PANEL:Think()
  if !IsValid(self.active_panel) and IsValid(self.active_button) then
    self.active_button:set_text_color(nil)
  end
end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_TAB then
    self:close_menu()
  end
end

function PANEL:Paint(w, h)
  Theme.hook('PaintTabMenu', self, w, h)
end

function PANEL:add_menu_item(id, data, index)
  data.id = id
  data.title = data.title or 'error'
  data.icon = data.icon or false

  table.insert(self.menu_items, data)
  table.sort(self.menu_items, function(a, b) return a.priority < b.priority end)
end

function PANEL:close_menu()
  self.blur_target = 0

  if IsValid(self.active_panel) then
    self.active_panel:AlphaTo(0, Theme.get_option('menu_anim_duration'), 0)

    PLAYER.tab_panel = self.active_panel.id

    if self.active_panel.on_close then
      self.active_panel:on_close()
    end
  end

  self.button_panel:MoveTo(0, -self.button_panel:GetTall(), Theme.get_option('menu_anim_duration'), 0, 0.5, function()
    self:safe_remove()

    Flux.blur_update_fps = 8
  end)
end

vgui.Register('fl_tab_menu', PANEL, 'EditablePanel')
