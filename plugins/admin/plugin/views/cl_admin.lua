--- The admin panel shown by the Admin entry of the tab menu: a sidebar of page buttons and
-- the page that is currently open.
-- Pages are added from the `AddAdminMenuItems` hook with `add_panel`, may require a
-- permission, and are created through the theme when their button is clicked.

local PANEL = {}
PANEL.cur_panel = nil
PANEL.panels = {}

--- Sizes and centers the admin panel, creates its sidebar and lets plugins add their pages
-- through the AddAdminMenuItems hook.
function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()
  local width, height = self:get_menu_size()
  local padding = math.scale(8)

  self:SetTitle('Admin')
  self:SetSize(width, height)
  self:SetPos(scrw * 0.5 - width * 0.5, scrh * 0.5 - height * 0.5)

  self.sidebar_width = math.floor(width * 0.2)
  self.buttons = {}

  self.sidebar = vgui.Create('fl_sidebar', self)
  self.sidebar:SetSize(self.sidebar_width - padding * 2, height - padding * 2)
  self.sidebar:SetPos(padding, padding)
  self.sidebar:set_margin(math.scale(4))
  self.sidebar.Paint = function(pnl, w, h)
  end

  self:SetKeyboardInputEnabled(true)

  --- Called on the client when the admin panel is created. Add pages to it here with
  -- `panel:add_panel(id, title, permission)`; the page itself must be registered with the
  -- theme under the same ID, as `Bolt:OnThemeLoaded` does.
  -- @param panel [Panel The admin panel, an `fl_admin_panel`]
  -- @param sidebar [Panel The sidebar of the admin panel, which holds the page buttons]
  hook.Run('AddAdminMenuItems', self, self.sidebar)
end

--- Draws the card of the panel and the divider between the sidebar and the page.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('PaintSurface', self, w, h)
  Theme.hook('PaintSectionTitle', self, t'ui.tab_menu.admin', w, h)

  local sidebar_x = self.sidebar:GetPos()

  if sidebar_x >= 0 then
    surface.SetDrawColor(Theme.get_color('border'))
    surface.DrawRect(self.sidebar_width, math.scale(8), 1, h - math.scale(16))
  end
end

--- Lets the active theme draw over the panel through its AdminPanelPaintOver hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PaintOver(w, h)
  Theme.call('AdminPanelPaintOver', self, w, h)
end

--- Registers a page and adds a sidebar button that opens it.
-- @param id [String page ID; must match a panel registered with the theme]
-- @param title [String button text]
-- @param permission=nil [String permission needed to open the page]
-- @param ... [Vararg extra arguments passed to Theme.create_panel when the page is opened]
function PANEL:add_panel(id, title, permission, ...)
  self.panels[id] = {
    id = id,
    title = title,
    permission = permission,
    arguments = { ... }
  }

  local button = vgui.Create('fl_button')
  button:SetSize(self.sidebar:GetWide(), math.scale(36))
  button:SetDrawBackground(true)
  button:SetFont(Theme.get_font('text_small'))
  button:set_text(title)
  button:set_text_offset(math.scale(12))
  button:set_text_autoposition(true)
  button:set_centered(false)
  button.DoClick = function(btn)
    if !self.cur_panel or self.cur_panel.id != id then
      self:open_panel(id)
    end
  end

  self.buttons[id] = button

  self.sidebar:add_panel(button)
end

--- Unregisters a page. Its sidebar button is left in place.
-- @param id [String page ID]
function PANEL:remove_panel(id)
  self.panels[id] = nil
end

--- Closes the current page and opens the one with the given ID, provided the local player has
-- the permission it requires. The button of the page becomes the active one.
-- @param id [String page ID]
function PANEL:open_panel(id)
  local panel = self.panels[id]

  if IsValid(self.cur_panel) then
    self.cur_panel:safe_remove()
  end

  if istable(panel) then
    if panel.permission and !PLAYER:can(panel.permission) then return end

    local padding = math.scale(8)
    local x = self.sidebar_width + padding

    for k, v in pairs(self.buttons) do
      if IsValid(v) then
        v:set_active(k == id)
      end
    end

    self.cur_panel = Theme.create_panel(panel.id, self, unpack(panel.arguments))
    self.cur_panel:SetPos(x, padding)
    self.cur_panel:SetSize(self:GetWide() - x - padding, self:GetTall() - padding * 2)
    self.cur_panel:SetParent(self)
    self.cur_panel.id = id

    if self.cur_panel.on_opened then
      self.cur_panel:on_opened(self, panel)
    end
  end
end

--- Slides the sidebar out of view and shows a 'Go Back' button, or restores the normal layout.
-- @param fullscreen [Boolean]
function PANEL:set_fullscreen(fullscreen)
  if fullscreen then
    self.sidebar:MoveTo(-self.sidebar:GetWide() - math.scale(16), self.sidebar.y, 0.3)
    self:SetTitle('')

    self.back_button = vgui.Create('fl_button', self)
    self.back_button:SetPos(math.scale(8), math.scale(8))
    self.back_button:SetSize(math.scale(120), math.scale(32))
    self.back_button:SetDrawBackground(true)
    self.back_button:set_draw_outline(true)
    self.back_button:SetFont(Theme.get_font('text_small'))
    self.back_button:set_text(t'ui.tab_menu.close_menu')
    self.back_button:set_icon('fa-chevron-left')
    self.back_button:set_icon_size(math.scale(14))
    self.back_button:set_centered(true)
    self.back_button.DoClick = function(btn)
      self:set_fullscreen(false)
    end
  else
    self.sidebar:MoveTo(math.scale(8), self.sidebar.y, 0.3)
    self:SetTitle('Admin')

    if IsValid(self.back_button) then
      self.back_button:safe_remove()
    end
  end
end

--- Returns the size of the admin panel, scaled to the screen.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(1280), math.scale(900)
end

vgui.Register('fl_admin_panel', PANEL, 'fl_base_panel')
