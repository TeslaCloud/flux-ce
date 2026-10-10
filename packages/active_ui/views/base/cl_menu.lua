--- The Flux context menu: `fl_menu`, a popup list of clickable options, and `fl_menu_item`,
-- the panel of a single option.

local get_color = Theme.get_color
local get_option = Theme.get_option
local color_icon = Color(255, 255, 255)

--- A single option of an `fl_menu`: a `DButton` in the theme's colors with an optional icon.
-- Options are created with the menu's `add_option`; `set_icon` and `set_icon_size` put a
-- material on the left side of one.
local PANEL = {}
PANEL.icon = nil
PANEL.icon_w = 16
PANEL.icon_h = 16
PANEL.hover_amount = 0

--- Applies the theme's menu font and text color to the item.
function PANEL:Init()
  self:SetFont(Theme.get_font('main_menu_small'))
  self:SetTextColor(get_color('text'))
  self:SetTextInset(math.scale(36), 0)
  self:SetContentAlignment(4)
end

--- Fades the hover highlight in and out.
function PANEL:Think()
  local step = FrameTime() * 10

  if self:IsHovered() then
    self.hover_amount = math.min(self.hover_amount + step, 1)
  else
    self.hover_amount = math.max(self.hover_amount - step, 0)
  end
end

--- Draws the highlight of the item while it is hovered, and its icon if one is set.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  if self.hover_amount > 0 then
    local inset = math.scale(4)

    draw.RoundedBox(
      get_option('corner_radius_small'),
      inset,
      1,
      w - inset * 2,
      h - 2,
      ColorAlpha(get_color('main_light'), 255 * self.hover_amount)
    )
  end

  if self.icon then
    draw.textured_rect(self.icon, math.scale(12), h * 0.5 - self.icon_h * 0.5, self.icon_w, self.icon_h, color_icon)
  end
end

--- Calls DoClick on a left or right click, then forwards to DButton.OnMouseReleased.
-- @param mouse [Number mouse button code, one of the MOUSE_ enums]
-- @return [Any result of DButton.OnMouseReleased, normally nil]
function PANEL:OnMousePressed(mouse)
  if mouse == MOUSE_RIGHT or mouse == MOUSE_LEFT then
    if self.DoClick then
      self:DoClick()
    end
  end

  return DButton.OnMouseReleased(self, mouse)
end

--- Sets the icon drawn on the left side of the item.
-- @param icon [String path of the material, as accepted by util.get_material]
function PANEL:set_icon(icon)
  self.icon = util.get_material(icon)
end

--- Sets the size the icon is drawn at.
-- @param w [Number width in pixels]
-- @param h=w [Number height in pixels]
function PANEL:set_icon_size(w, h)
  h = h or w

  self.icon_w = w
  self.icon_h = h
end

vgui.Register('fl_menu_item', PANEL, 'DButton')

--- A popup context menu (`fl_menu`), built on `DScrollPanel`.
-- Create it, add entries with `add_option` and `add_spacer`, then call `open` to show it at
-- the cursor or at a given position. It is registered with Derma's menu system, so it is
-- removed when the Derma menus are closed. The action menu of an item is built with it.
local PANEL = {}
PANEL.last = 0
PANEL.option_height = math.scale(32)
PANEL.count = 0
PANEL.padding = math.scale(4)

--- Starts the menu with the padding that its options are inset by.
function PANEL:Init()
  self.last = self.padding
end

--- Draws the card of the menu.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
  Theme.hook('DrawCard', 0, 0, w, h, get_option('corner_radius'), ColorAlpha(get_color('surface_sunken'), 250))
end

--- Makes the menu and all of its options as wide as the widest option and as tall as the
-- options combined, capped at 75% of the screen height.
function PANEL:PerformLayout()
  local w = 0

  for k, pnl in pairs(self:GetCanvas():GetChildren()) do
    pnl:InvalidateLayout()
    pnl:SizeToContentsX()

    w = math.max(w, pnl:GetWide())
  end

  w = w * 1.2 + math.scale(24)

  self:SetWide(w)

  local y = self.padding * 2

  for k, pnl in pairs(self:GetCanvas():GetChildren()) do
    pnl:SetWide(w)
    pnl:InvalidateLayout(true)
    pnl:MoveToFront()

    y = y + pnl:GetTall()
  end

  self:SetTall(math.min(y, ScrH() * 0.75))

  DScrollPanel.PerformLayout(self)

  self:SetKeyboardInputEnabled(true)
end

--- Tells the Derma menu system to remove this menu when menus are closed.
-- @return [Boolean always true]
function PANEL:GetDeleteSelf()
  return true
end

--- Opens the menu as a popup at the given screen position and registers it to be closed
-- together with other Derma menus.
-- @param x=gui.MouseX() [Number]
-- @param y=gui.MouseY() [Number]
-- @return [Panel the menu itself]
function PANEL:open(x, y)
  x = x or gui.MouseX()
  y = y or gui.MouseY()

  RegisterDermaMenuForClose(self)

  self:SetWide(200)
  self:PerformLayout()

  self:SetPos(x, y)

  self:MakePopup()
  self:SetVisible(true)
  self:SetKeyboardInputEnabled(false)
  self:SetMouseInputEnabled(true)
  self:RequestFocus()

  return self
end

--- Adds a clickable option to the bottom of the menu.
-- ```
-- local item_menu = vgui.Create('fl_menu')
--
-- local use_button = item_menu:add_option(t(item_obj:get_use_text()), function()
--   item_obj:do_menu_action('on_use')
-- end)
--
-- use_button:SetIcon(item_obj.use_icon or 'icon16/accept.png')
--
-- item_menu:open()
-- ```
-- @param name [String text of the option]
-- @param callback=nil [Function called with the option's panel when it is clicked]
-- @return [Panel the created fl_menu_item]
function PANEL:add_option(name, callback)
  local w, h = self:GetSize()

  local panel = vgui.Create('fl_menu_item', self)
  panel:SetPos(0, 0)
  panel:MoveTo(0, self.last, 0.15 * self.count)
  panel:SetSize(self:GetWide(), self.option_height)
  panel:SetTextColor(get_color('text'))
  panel:SetText(name)
  panel:MoveToBack()

  if callback then
    panel.DoClick = callback
  end

  self.last = self.last + self.option_height
  self.count = self.count + 1

  self:AddItem(panel)
  self:SetSize(w, self.last + self.padding)

  return panel
end

--- Adds a thin horizontal divider below the last option.
-- @param px=1 [Number height of the divider in pixels]
-- @return [Panel the created divider]
function PANEL:add_spacer(px)
  px = px or 1

  local panel = vgui.Create('DPanel', self)
  panel:SetSize(self:GetWide(), px)
  panel:SetPos(0, 0)
  panel:MoveToBack()

  panel.Paint = function(pan, w, h)
    local inset = math.scale(12)

    draw.RoundedBox(0, inset, 0, w - inset * 2, h, get_color('border'))
  end

  panel:MoveTo(0, self.last, 0.15 * self.count)

  self:AddItem(panel)

  self.last = self.last + px

  return panel
end

vgui.Register('fl_menu', PANEL, 'DScrollPanel')
