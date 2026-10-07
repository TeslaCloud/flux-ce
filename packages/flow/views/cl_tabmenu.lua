local PANEL = {}
PANEL.menu_items = {}
PANEL.buttons = {}
PANEL.active_panel = nil

--- Builds the full screen tab menu: slides the button bar in, collects the menu items
-- through the AddTabMenuItems hook, creates a button for each of them and opens the panel
-- that was open last time, or the default one.
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
  local icon_size = 20

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
  self.close_button:SetFont(Theme.get_font('main_menu_titles'))
  self.close_button:set_text(t'ui.tab_menu.close_menu')
  self.close_button:set_centered(false)
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
    button:SetDrawBackground(true)
    button:SetPos(cur_x, cur_y)
    button:SetTooltip(v.title)
    button:SetFont(Theme.get_font('main_menu_titles'))
    button:set_text_offset(math.scale_x(16))
    button:set_text(v.title)
    button:set_icon(v.icon)
    button:set_centered(true)
    button:set_icon_size(icon_size)
    button:set_background_color(nil)
    button:SizeToContentsX()

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

          self.active_button:set_background_color(nil)
        end

        self.active_panel = vgui.Create(v.panel, self)

        if self.active_panel.get_menu_size then
          self.active_panel:SetSize(self.active_panel:get_menu_size())
        else
          self.active_panel:SetSize(scrw * 0.5, scrh * 0.5)
        end

        self.active_button = btn
        self.active_button:set_background_color(Theme.get_color('accent'))

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

    cur_x = cur_x + button:GetWide()

    if cur_x >= ScrW() - button:GetWide() then
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

--- Clears the text color override of the active button once its panel is gone.
function PANEL:Think()
  if !IsValid(self.active_panel) and IsValid(self.active_button) then
    self.active_button:set_text_color(nil)
  end
end

--- Closes the menu when the TAB key is pressed.
-- @param key [Number key code, one of the KEY_ enums]
function PANEL:OnKeyCodePressed(key)
  if key == KEY_TAB then
    self:close_menu()
  end
end

--- Delegates drawing of the menu to the active theme's PaintTabMenu hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('PaintTabMenu', self, w, h)
end

--- Registers an item in the tab menu: a button that can open a panel. Meant to be called
-- from the AddTabMenuItems hook; buttons are ordered by ascending priority.
-- The opened panel may define get_menu_size, rebuild, on_change and on_close, which the
-- menu calls when appropriate.
-- ```
-- function Inventories:AddTabMenuItems(menu)
--   menu:add_menu_item('inventory', {
--     title = 'Inventory',
--     panel = 'fl_inventory_menu',
--     icon = 'fa-briefcase',
--     default = true,
--     priority = 30,
--     callback = function(menu_panel, button)
--       local inv = menu_panel.active_panel
--       inv:SetTitle('Inventory')
--     end
--   })
-- end
-- ```
-- @param id [String unique ID of the item]
-- @param data [Map item options. priority (Number) is required. Optional: title (String),
--   icon (String FontAwesome ID), panel (String VGUI class to open on click),
--   default (Boolean open this item when none was open before),
--   callback (Function(menu_panel, button) called after the click was handled),
--   override (Function(menu_panel, button) called instead of opening a panel)]
-- @param index=nil [Number unused]
function PANEL:add_menu_item(id, data, index)
  data.id = id
  data.title = data.title or 'error'
  data.icon = data.icon or false

  table.insert(self.menu_items, data)
  table.sort(self.menu_items, function(a, b) return a.priority < b.priority end)
end

--- Closes the menu: fades the active panel out, remembers it for the next time the menu
-- opens, calls its on_close method and slides the button bar away before removing the menu.
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
