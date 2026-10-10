--- A button that shows an image instead of a title (`fl_image_button`).
-- Set the image with `SetImage`. The image is darkened until the button is hovered, and an
-- accent colored outline is drawn around it while the button is active. Derives from
-- `fl_button`; the faction chooser of the character creation uses it.

local math_clamp = math.Clamp

local PANEL = {}
PANEL.cur_amt = 160

--- Creates the DImage that displays the image of the button.
function PANEL:Init()
  self.Image = vgui.Create('DImage', self)
  self.Image:SetSize(100, 100)
  self.Image:SetPos(0, 0)
end

--- Sets the image displayed on the button.
-- @param img [String path of the image, as accepted by DImage:SetImage]
function PANEL:SetImage(img)
  self.Image:SetImage(img)
end

--- Draws nothing: the image is a child panel and the overlay is drawn in PaintOver.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:Paint(w, h)
end

--- Darkens the image while it is not hovered and draws an accent colored outline while the
-- button is active.
-- @param w [Number panel width]
-- @param h [Number panel height]
function PANEL:PaintOver(w, h)
  local active = self.active

  surface.SetDrawColor(0, 0, 0, (!active and self.cur_amt * 4) or 0)
  surface.DrawRect(0, 0, w, h)

  if active then
    surface.SetDrawColor(Theme.get_color('accent'))
    surface.DrawOutlinedRect(0, 0, w, h)
  end
end

--- Updates the hover fade amount and stretches the image to the size of the button.
function PANEL:Think()
  if self:IsHovered() then
    self.cur_amt = math_clamp(self.cur_amt - 1, 0, 40)
  else
    self.cur_amt = math_clamp(self.cur_amt + 1, 0, 40)
  end

  self.Image:SetSize(self:GetSize())
end

vgui.Register('fl_image_button', PANEL, 'fl_button')
