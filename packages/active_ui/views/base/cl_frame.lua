--- A window panel (`fl_frame`) with a title header and a close button, drawn by the active
-- theme's `PaintFrame` hook.
-- Set the title with `SetTitle`; docked children start below the header. The close button
-- removes the frame, and `set_draggable` lets the player drag it around the screen. The
-- character creation and loading screens and the item icon editor are built on it. Derives
-- from `fl_base_panel`.

local math_clamp = math.clamp

local PANEL = {}
PANEL.draggable = false

--- Sets the default title, reserves space for the header and creates the close button.
function PANEL:Init()
  local padding = Theme.get_option('panel_padding', math.scale(12))
  local header = Theme.get_option('frame_header_size', math.scale(36))

  self:SetTitle('Flux Frame')
  self:DockPadding(padding, header + padding, padding, padding)

  self.button_close = vgui.Create('fl_button', self)
  self.button_close:SetSize(self:get_close_button_size())
  self.button_close:SetPos(0, 0)
  self.button_close:set_icon('fa-times')
  self.button_close:set_icon_size(math.scale(14))
  self.button_close:set_text('')
  self.button_close:set_centered(true)
  self.button_close:SetDrawBackground(false)
  self.button_close:SetTooltip(t'ui.close')
  self.button_close.DoClick = function(btn)
    self:safe_remove()
  end
end

--- Returns the size of the close button, which fits inside the header.
-- @return [Number width, Number height]
function PANEL:get_close_button_size()
  local size = math.max(Theme.get_option('frame_header_size', math.scale(36)) - math.scale(8), math.scale(20))

  return size, size
end

--- Keeps the close button centered in the right end of the header.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PerformLayout(w, h)
  if IsValid(self.button_close) then
    local header = Theme.get_option('frame_header_size', math.scale(36))
    local size = self:get_close_button_size()

    self.button_close:SetSize(size, size)
    self.button_close:SetPos(w - size - math.scale(4), header * 0.5 - size * 0.5)
  end
end

--- Delegates drawing of the frame to the active theme's PaintFrame hook.
-- @param w [Number panel width]
-- @param h [Number panel height]
-- @return [Any whatever the theme hook returns; nil with the factory theme]
function PANEL:Paint(w, h)
  return Theme.hook('PaintFrame', self, w, h)
end

--- Moves the frame with the cursor while it is being dragged, keeping it on the screen,
-- and runs the active theme's FrameThink hook.
function PANEL:Think()
  if self.dragging then
    local scrw, scrh = ScrW(), ScrH()
    local dragging = self.dragging
    local w, h = self:GetSize()
    local mouse_x = math_clamp(gui.MouseX(), 1, scrw - 1)
    local mouse_y = math_clamp(gui.MouseY(), 1, scrh - 1)
    local x = math_clamp(mouse_x - dragging[1], 0, scrw - w)
    local y = math_clamp(mouse_y - dragging[2], 0, scrh - h)

    self:SetPos(x, y)
  end

  Theme.hook('FrameThink')
end

--- Starts dragging the frame if it is draggable.
function PANEL:OnMousePressed()
  if self:is_draggable() then
    self.dragging = { gui.MouseX() - self.x, gui.MouseY() - self.y }
    self:MouseCapture(true)
  end
end

--- Stops dragging the frame if it is draggable.
function PANEL:OnMouseReleased()
  if self:is_draggable() then
    self.dragging = nil
    self:MouseCapture(false)
  end
end

--- Makes the frame draggable with the mouse. The argument is currently ignored: dragging
-- is always turned on and cannot be turned off again through this method.
-- @param bool [Boolean ignored]
function PANEL:set_draggable(bool)
  self.draggable = true
end

--- Checks whether the frame can be dragged with the mouse.
-- @return [Boolean]
function PANEL:is_draggable()
  return self.draggable
end

vgui.Register('fl_frame', PANEL, 'fl_base_panel')
