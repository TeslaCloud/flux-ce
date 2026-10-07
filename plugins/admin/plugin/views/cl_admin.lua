local PANEL = {}
PANEL.cur_panel = nil
PANEL.panels = {}

--- Sizes and centers the admin panel, creates its sidebar and lets plugins add their pages
-- through the AddAdminMenuItems hook.
function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()
  local width, height = self:get_menu_size()

  self:SetTitle('Admin')
  self:SetSize(width, height)
  self:SetPos(scrw * 0.5 - width * 0.5, scrh * 0.5 - height * 0.5)

  self.sidebar = vgui.Create('fl_sidebar', self)
  self.sidebar:SetSize(width / 5 - 8, height)
  self.sidebar:SetPos(0, 0)
  self.sidebar.Paint = function(pnl, w, h)
  end

  self:SetKeyboardInputEnabled(true)

  hook.Run('AddAdminMenuItems', self, self.sidebar)
end

--- Draws the outlined, translucent background.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  DisableClipping(true)

  draw.box_outlined(0, -4, -4, w + 8, h + 24, 2, Theme.get_color('background'))

  DisableClipping(false)

  draw.RoundedBox(0, 0, 0, w, h, Theme.get_color('background'):alpha(150))
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
  button:SetWide(self.sidebar:GetWide())
  button:SetDrawBackground(true)
  button:SetFont(Theme.get_font('text_normal'))
  button:set_text(title)
  button:set_text_autoposition(true)
  button:SizeToContentsY()
  button:set_centered(true)
  button.DoClick = function(btn)
    if !self.cur_panel or self.cur_panel.id != id then
      self:open_panel(id)
    end
  end

  self.sidebar:add_panel(button)
  self.sidebar:add_space(2)
end

--- Unregisters a page. Its sidebar button is left in place.
-- @param id [String page ID]
function PANEL:remove_panel(id)
  self.panels[id] = nil
end

--- Closes the current page and opens the one with the given ID, provided the local player has
-- the permission it requires.
-- @param id [String page ID]
function PANEL:open_panel(id)
  local panel = self.panels[id]

  if IsValid(self.cur_panel) then
    self.cur_panel:safe_remove()
  end

  if istable(panel) then
    if panel.permission and !PLAYER:can(panel.permission) then return end

    local sw, sh = self.sidebar:GetWide(), self.sidebar:GetTall()

    self.cur_panel = Theme.create_panel(panel.id, self, unpack(panel.arguments))
    self.cur_panel:SetPos(sw, 0)
    self.cur_panel:SetSize(self:GetWide() - sw, self:GetTall())
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
    self.sidebar:MoveTo(-self.sidebar:GetWide(), 0, 0.3)
    self:SetTitle('')

    self.back_button = vgui.Create('DButton', self)
    self.back_button:SetPos(0, 0)
    self.back_button:SetSize(100, 0)
    self.back_button:set_text('')

    self.back_button.Paint = function(btn, w, h)
      local font = Flux.fonts:GetSize(Theme.get_font('text_small'), 16)
      local font_size = util.font_size(font)

      FontAwesome:draw('fa-chevron-left', math.scale(6), math.scale(5), math.scale(14), Color(255, 255, 255))
      draw.SimpleText('Go Back', font, 24, 3 * (16 / font_size), Color(255, 255, 255))
    end

    self.back_button.DoClick = function(btn)
      self:set_fullscreen(false)
    end
  else
    self.sidebar:MoveTo(0, 0, 0.3)
    self:SetTitle('Admin')

    self.back_button:safe_remove()
  end
end

--- Returns the size of the admin panel, scaled to the screen.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return math.scale(1280), math.scale(900)
end

vgui.Register('fl_admin_panel', PANEL, 'fl_base_panel')
