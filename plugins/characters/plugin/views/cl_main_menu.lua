--- The main menu (`fl_main_menu`): a fullscreen panel with a sidebar of buttons and at most
-- one submenu open at a time.
-- The buttons are added with `add_button` from the AddMainMenuItems hook; a button either runs
-- a callback or opens a theme panel as the submenu. The theme draws the menu and supplies its
-- music.

local PANEL = {}
PANEL.prev_button = nil
PANEL.schema_logo_offset = math.scale(450)
PANEL.max_wide = 0

--- Covers the screen, builds the sidebar and starts the theme's menu music unless the
-- framework runs in development mode.
function PANEL:Init()
  self:SetPos(0, 0)
  self:SetSize(ScrW(), ScrH())

  self:RecreateSidebar(true)

  self:MakePopup()

  if !Flux.development then
    local menu_music = Theme.get_sound('menu_music')

    if !Flux.menu_music and menu_music and menu_music != '' then
      sound.PlayFile(menu_music, '', function(station)
        if IsValid(station) then
          station:Play()

          Flux.menu_music = station
        end
      end)
    end
  end

  Theme.hook('CreateMainMenu', self)

  Flux.blur_update_fps = 0
end

--- Restores the blur update rate that was lowered while the menu was open.
function PANEL:OnRemove()
  Flux.blur_update_fps = 8
end

--- Draws the menu through the theme's PaintMainMenu hook.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  if self:IsVisible() then
    Theme.hook('PaintMainMenu', self, w, h)
  end
end

--- Animates the schema logo offset toward zero while a submenu is open and back otherwise.
function PANEL:Think()
  local menu_valid = IsValid(self.menu)
  local offset = self.schema_logo_offset

  if offset > 0 and menu_valid then
    self.schema_logo_offset = Lerp(FrameTime() * 8, offset, 0)
  elseif !menu_valid then
    local full_offset = math.scale(450)

    if offset < full_offset then
      self.schema_logo_offset = Lerp(FrameTime() * 8, offset, full_offset)
    end
  end
end

--- Recreates the sidebar, optionally filling it through the AddMainMenuItems hook.
-- @param create_buttons=false [Boolean add the menu buttons and center them]
function PANEL:RecreateSidebar(create_buttons)
  if IsValid(self.sidebar) then
    self.sidebar:safe_remove()
  end

  self.sidebar = vgui.Create('fl_sidebar', self)
  self.sidebar:SetPos(Theme.get_option('menu_sidebar_x'), Theme.get_option('menu_sidebar_y'))
  self.sidebar:SetSize(0, Theme.get_option('menu_sidebar_height'))
  self.sidebar:set_margin(Theme.get_option('menu_sidebar_margin'))
  self.sidebar:add_space(math.scale(16))

  self.sidebar.Paint = function(pnl, w, h)
  end

  if create_buttons then
    --- Lets plugins add buttons to the main menu. Called on the client whenever the menu fills
    -- its sidebar: when it is created and when a submenu is closed.
    -- @param panel [Panel the fl_main_menu panel; add buttons with its add_button method]
    -- @param sidebar [Panel the newly created sidebar that the buttons go into]
    hook.Run('AddMainMenuItems', self, self.sidebar)

    local x, y = self.sidebar:GetPos()

    self.sidebar:SetWide(self.max_wide)
    self.sidebar:SetPos(x - self.max_wide * 0.5, y)
    self.sidebar:center_items()
  end
end

--- Opens a theme panel as the submenu, closing the currently open submenu first.
-- @param panel [String theme panel ID]
-- @param data=nil [Any passed to the set_data method of the new panel, if it has one]
function PANEL:OpenMenu(panel, data)
  if !IsValid(self.menu) then
    self.menu = Theme.create_panel(panel, self)

    if self.menu.set_data then
      self.menu:set_data(data)
    end
  else
    if self.menu.close then
      self.menu:close(function()
        self:OpenMenu(panel, data)
      end)
    else
      self.menu:safe_remove()
      self:OpenMenu(panel, data)
    end
  end
end

--- Slides the open submenu away and closes it, bringing the sidebar back in.
-- @param from_right=false [Boolean bring the sidebar in from the right instead of the left]
function PANEL:to_main_menu(from_right)
  local scrw = ScrW()

  if !self.hide_sidebar then
    self:RecreateSidebar(true)

    self.sidebar:SetPos(from_right and scrw or -self.sidebar:GetWide(), Theme.get_option('menu_sidebar_y'))
    self.sidebar:SetDisabled(true)
    self.sidebar:MoveTo(
      Theme.get_option('menu_sidebar_x') - self.max_wide * 0.5,
      Theme.get_option('menu_sidebar_y'),
      Theme.get_option('menu_anim_duration'),
      0,
      0.5,
      function()
        self.sidebar:SetDisabled(false)
      end
    )
  end

  self.menu:MoveTo(
    from_right and -self.menu:GetWide() or scrw,
    0,
    Theme.get_option('menu_anim_duration'),
    0,
    0.5,
    function()
      if self.menu.close then
        self.menu:close()
      else
        self.menu:safe_remove()
      end
    end
  )
end

--- Shows a notification near the bottom of the menu unless one is already visible.
-- @param text [String]
function PANEL:notify(text)
  if IsValid(self.notification) then return end

  self.notification = vgui.Create('fl_notification', self)
  self.notification:set_text(text)
  self.notification:set_lifetime(6)
  self.notification:set_background_color(Theme.get_color('warning'))

  local w, h = self.notification:GetSize()
  self.notification:SetPos(ScrW() * 0.5 - w * 0.5, ScrH() - math.scale(128))

  --- Keeps the notification above the main menu.
  function self.notification:PostThink() self:MoveToFront() end
end

--- Adds a button to the sidebar.
-- @param text [String button title, displayed in upper case]
-- @param callback [Function/String function that receives the clicked button, or the ID of
--   a theme panel to open as the submenu]
-- @return [Panel the created button]
function PANEL:add_button(text, callback)
  local button = vgui.Create('fl_button', self)
  button:SetTall(Theme.get_option('menu_sidebar_button_height'))
  button:SetDrawBackground(false)
  button:SetFont(Theme.get_font('main_menu_large'))
  button:set_text(string.utf8upper(text))
  button:set_text_autoposition(false)
  button:set_centered(Theme.get_option('menu_sidebar_button_centered'))
  button:set_text_offset(math.scale(8))

  button:SizeToContents()

  button.DoClick = function(btn)
    local cur_time = CurTime()

    if self.next_click and self.next_click > cur_time then return end

    surface.PlaySound(Theme.get_sound('button_click_success_sound'))

    btn:set_active(true)

    if IsValid(self.prev_button) and self.prev_button != btn then
      self.prev_button:set_active(false)
    end

    self.prev_button = btn

    if isfunction(callback) then
      callback(btn)
    elseif isstring(callback) then
      self:OpenMenu(callback)
    end

    self.next_click = cur_time + 1
  end

  local wide = button:GetWide()

  if self.max_wide < wide then
    self.max_wide = wide
  end

  self.sidebar:add_panel(button)
  self.sidebar:add_space(math.scale(6))

  return button
end

vgui.Register('fl_main_menu', PANEL, 'EditablePanel')
