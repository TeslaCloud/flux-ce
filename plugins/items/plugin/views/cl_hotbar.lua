--- The `fl_hotbar` panel shows the hotbar of the local player at the bottom center of the
-- screen: an `fl_hotbar_slot` for every slot that they are shown, in the order of the bar (see
-- `Hotbar.build_layout`). `Hotbar.create_panel` creates it and `Hotbar.refresh` updates every
-- one that exists. While the shown slots stay the same, the bar keeps its slot panels and
-- updates them in place; it creates and removes them only when the layout changes, and ends
-- a drag of a slot before its panel is removed. An entry or an item dropped onto the bar
-- between its slots stays where it is.

local IsValid = IsValid
local math_scale = math.scale

local base_panel = baseclass.Get('fl_base_panel')

--- Marks an entry dropped onto the bar between its slots as handled, so that it stays on the
-- hotbar.
-- @param _receiver [Panel the fl_hotbar]
-- @param dropped [List<Panel> the dragged fl_hotbar_slot panels]
-- @param is_dropped [Boolean]
local function receive_entry(_receiver, dropped, is_dropped)
  local source = dropped[1]

  if is_dropped and IsValid(source) then
    source.drop_handled = true
  end
end

local PANEL = {}

--- Registers the panel with the Hotbar library, which updates it, and makes the bar catch what
-- is dropped between its slots.
function PANEL:Init()
  self.title = nil
  self.slot_panels = {}

  Hotbar.panels[self] = true

  self:Receiver('fl_hotbar', receive_entry)
  self:Receiver('fl_item', Hotbar.receive_inventory_item)
end

--- Checks whether the slot panels of the bar show the slots of the layout of the hotbar.
-- @return [Boolean]
function PANEL:has_layout()
  local slot_panels = self.slot_panels
  local count = Hotbar.layout_count
  local layout = Hotbar.layout

  if #slot_panels != count then return false end

  for i = 1, count do
    local slot_panel = slot_panels[i]

    if !IsValid(slot_panel) or slot_panel.slot != layout[i] then
      return false
    end
  end

  return true
end

--- Removes the slot panels of the bar, ending a drag of any of them first, and creates one for
-- every slot of the layout of the hotbar.
function PANEL:create_slots()
  local slot_panels = self.slot_panels

  for i = #slot_panels, 1, -1 do
    local slot_panel = slot_panels[i]

    if IsValid(slot_panel) then
      slot_panel:end_drag()
      slot_panel:Remove()
    end

    slot_panels[i] = nil
  end

  local layout = Hotbar.layout

  for i = 1, Hotbar.layout_count do
    local slot_panel = vgui.Create('fl_hotbar_slot', self)
    slot_panel:set_slot(layout[i])

    slot_panels[i] = slot_panel
  end
end

--- Updates the slots of the bar from the state that `Hotbar.refresh` has worked out, removing
-- and creating slot panels only when the layout has changed, and puts the bar at the bottom
-- center of the screen.
function PANEL:rebuild()
  if !self:has_layout() then
    self:create_slots()
  end

  local size, padding = math_scale(80), math_scale(8)
  local slot_panels = self.slot_panels
  local count = #slot_panels

  for i = 1, count do
    local slot_panel = slot_panels[i]
    slot_panel:SetSize(size, size)
    slot_panel:SetPos((i - 1) * (size + padding), 0)
    slot_panel:update()
  end

  local w = math.max(count * (size + padding) - padding, size)

  self:SetSize(w, size)
  self:SetPos((ScrW() - w) * 0.5, ScrH() - size - math_scale(16))
end

--- Ends a drag of any slot of the bar as the bar is removed, without taking its entry off the
-- hotbar.
function PANEL:OnRemove()
  local slot_panels = self.slot_panels

  for i = 1, #slot_panels do
    local slot_panel = slot_panels[i]

    if IsValid(slot_panel) then
      slot_panel:end_drag()
    end
  end

  base_panel.OnRemove(self)
end

--- Draws the card of the bar using the theme.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  Theme.hook('PaintInventoryBackground', self, w, h)
end

--- Draws the title of the bar, if it has one, using the theme.
-- @param w [Number]
-- @param h [Number]
function PANEL:PaintOver(w, h)
  Theme.hook('PaintOverInventoryBackground', self, w, h)
end

vgui.Register('fl_hotbar', PANEL, 'fl_base_panel')
