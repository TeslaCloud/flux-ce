--- A vertical list of panels (`fl_sidebar`) that scrolls without a visible scrollbar, drawn by
-- the active theme's `PaintSidebar` hook.
-- Fill it from top to bottom with `add_button` and `add_panel`, spaced with `set_margin` and
-- `add_space`; `Clear` empties it again. Buttons added with `add_button` behave like tabs: the
-- clicked one becomes active and the previously clicked one is deactivated. The main menu and
-- the admin menu use it for their navigation. Derives from `DScrollPanel`.

local PANEL = {}
PANEL.last_pos = 0
PANEL.margin = 0

--- Hides the scrollbar graphics and performs the initial layout.
function PANEL:Init()
  self.VBar.Paint = function() return true end
  self.VBar.btnUp.Paint = function() return true end
  self.VBar.btnDown.Paint = function() return true end
  self.VBar.btnGrip.Paint = function() return true end

  self:PerformLayout()

  --- Suppresses the default handling of the scrollbar appearing.
  -- @return [Boolean true]
  function self:OnScrollbarAppear() return true end
end

--- Delegates drawing of the sidebar to the active theme's PaintSidebar hook.
-- @param width [Number panel width]
-- @param height [Number panel height]
function PANEL:Paint(width, height)
  Theme.hook('PaintSidebar', self, width, height)
end

--- Removes all items from the sidebar and resets the position of the next item to the top.
function PANEL:Clear()
  self.BaseClass.Clear(self)
  self.last_pos = 0
end

-- 'borrowed' from lua/vgui/dscrollpanel.lua

--- Rebuilds the canvas and updates the scrollbar while keeping the canvas as wide as the
-- sidebar itself.
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

--- Adds a panel below the previously added item, followed by the configured margin.
-- @param panel [Panel]
-- @param center=false [Boolean center the panel horizontally instead of keeping its x position]
function PANEL:add_panel(panel, center)
  local x, y = panel:GetPos()

  if center then
    x = self:GetWide() * 0.5 - panel:GetWide() * 0.5
  end

  panel:SetPos(x, self.last_pos)

  self:AddItem(panel)

  self.last_pos = self.last_pos + self.margin + panel:GetTall()
end

--- Creates an fl_button as wide as the sidebar and adds it as the next item. Clicking it
-- marks it as active and deactivates the previously clicked button.
-- @param text [String title of the button]
-- @param callback=nil [Function called with the button when it is clicked]
-- @return [Panel the created fl_button]
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

--- Adds empty vertical space before the next item.
-- @param px [Number height of the gap in pixels]
function PANEL:add_space(px)
  self.last_pos = self.last_pos + px
end

--- Sets the vertical gap left after each item that is added from now on.
-- @param margin [Number gap in pixels; values tonumber cannot convert become 0]
function PANEL:set_margin(margin)
  self.margin = tonumber(margin) or 0
end

--- Centers every item horizontally within the sidebar.
function PANEL:center_items()
  for k, v in ipairs(self:GetCanvas():GetChildren()) do
    local x, y = v:GetPos()

    v:SetPos(self:GetWide() / 2 - v:GetWide() / 2, y)
  end
end

vgui.Register('fl_sidebar', PANEL, 'DScrollPanel')
