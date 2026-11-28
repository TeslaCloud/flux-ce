--- The `fl_hotbar_slot` panel is one slot of an `fl_hotbar` panel. It builds upon the
-- `fl_inventory_item` slot for the icon of the item and the labels, and shows the state that
-- `Hotbar.refresh` has worked out for its slot: the key number, the item of the entry with the
-- amount of a pinned item, dimmed when the player has none of it, the fixed icons of the hands,
-- the physgun and the tool gun, and a ring around the selected or hovered slot, drawn over
-- everything else. `PANEL:update` compares that state with what the slot shows and recreates
-- the icon or the model of the item only when the item or the kind of the entry has changed.
--
-- An item dragged from an inventory onto one of the item slots is put on it and an entry
-- dragged onto another item slot is moved there. An entry dragged onto an inventory of the
-- storage of the player, or right-clicked, is taken off; one dragged onto the world outside the
-- card of its bar, or onto the bare background of the inventory tab or of the tab menu outside
-- that card, has its item dropped, and one dragged onto any other panel stays (see
-- `lib/cl_hotbar_input.lua`). Each of these is a request to the server. A left click selects
-- the slot. A press or a drag of the slot whose drag state is cleared under it, as
-- `fl_inventory:rebuild` does, ends with its release or with a press of the other button, and
-- neither that press nor the releases that follow do anything. While the cursor is over an
-- entry, the number keys move it and the drop key drops its item.

local IsValid = IsValid
local math_scale = math.scale
local draw_rounded_box = draw.RoundedBox
local surface_set_draw_color = surface.SetDrawColor
local surface_set_material = surface.SetMaterial
local surface_draw_textured_rect = surface.DrawTexturedRect
local get_color = Theme.get_color
local get_option = Theme.get_option
local draw_box_outlined = draw.box_outlined

local slot_color = Color(30, 33, 44, 200)
local slot_color_empty = Color(22, 24, 33, 170)
local selected_ring_color = Color(236, 186, 86)
local hovered_ring_color = Color(120, 150, 220)
local dimmed_color = Color(10, 12, 17, 170)
local key_texts = {}

for slot = 0, 9 do
  key_texts[slot] = tostring(slot)
end

--- The icons and the tooltips of the slots that hold no item.
local fixed_slots = {
  [Hotbar.hands_slot] = { icon = 'entities/weapon_fists.png', name = 'ui.hotbar.hands' },
  [Hotbar.physgun_slot] = { icon = 'entities/weapon_physgun.png', name = 'ui.hotbar.physgun' },
  [Hotbar.toolgun_slot] = { icon = 'entities/gmod_tool.png', name = 'ui.hotbar.toolgun' }
}

local dpanel = baseclass.Get('DPanel')

--- Puts an item that has been dragged from an inventory onto the slot, after what
-- `Hotbar.receive_inventory_item` does for the bar and every slot.
-- @param receiver [Panel the fl_hotbar_slot]
-- @param dropped [List<Panel> the dragged fl_inventory_item panels]
-- @param is_dropped [Boolean]
local function receive_item(receiver, dropped, is_dropped)
  local item_obj = Hotbar.receive_inventory_item(receiver, dropped, is_dropped)

  if item_obj and Hotbar.is_item_slot(receiver.slot) then
    Cable.send('fl_hotbar_place', receiver.slot, item_obj.instance_id)
  end
end

--- Moves an entry that has been dragged from another slot of the bar onto the slot.
-- @param receiver [Panel the fl_hotbar_slot]
-- @param dropped [List<Panel> the dragged fl_hotbar_slot panels]
-- @param is_dropped [Boolean]
local function receive_entry(receiver, dropped, is_dropped)
  local source = dropped[1]

  if !is_dropped or !IsValid(source) then return end

  source.drop_handled = true

  if source.slot != receiver.slot and Hotbar.is_item_slot(receiver.slot) then
    Cable.send('fl_hotbar_move', source.slot, receiver.slot)
  end
end

local PANEL = {}

--- Makes the slot accept items from inventories and entries from other slots.
function PANEL:Init()
  self:Receiver('fl_item', receive_item)
  self:Receiver('fl_hotbar', receive_entry)
end

--- Sets the slot of the hotbar that the panel shows, with its key number and, for slots 8, 9
-- and 0, its fixed icon and tooltip. `PANEL:update` fills in the rest.
-- @param slot [Number]
function PANEL:set_slot(slot)
  local fixed = fixed_slots[slot]

  self.slot = slot
  self.key_text = key_texts[slot]
  self.fixed_name = fixed and fixed.name
  self.fixed_icon = fixed and util.get_material(fixed.icon, 'smooth') or nil
  self.badge_margin = math_scale(3)
  self.ring_width = math.max(math_scale(2), 2)

  self:rebuild()
end

--- Shows the state of the slot that `Hotbar.refresh` has worked out. The amount of a pinned
-- item is updated in place; the icon or the model of the item is recreated, and a drag of
-- the slot ended without taking the entry off, only when the item that the slot shows or the
-- kind of its entry has changed.
function PANEL:update()
  local state = Hotbar.get_slot_state(self.slot)
  local item_obj, kind = state?.item, state?.kind

  self.amount_text = state?.amount_text
  self.is_empty_pin = kind == 'pin' and state.amount == 0

  if item_obj == self.item_data and kind == self.kind then return end

  self:end_drag()

  self.item_data = item_obj
  self.kind = kind

  self:rebuild()
end

--- Recreates the icon or the model of the item of the slot along with its tooltip, and removes
-- them when the slot shows no item. A slot with an entry can be dragged. The tooltip of a
-- hovered slot is shown again, so that it does not keep naming an item that has left it.
function PANEL:rebuild()
  self:undraggable()
  self:remove_icon()

  local item_obj = self.item_data

  if item_obj then
    self:Droppable('fl_hotbar')
    self:create_icon()
    self:SetTooltip(t(item_obj:get_name())..'\n'..t(item_obj:get_description()))
  else
    self:SetTooltip(self.fixed_name and t(self.fixed_name) or false)
  end

  if self:IsHovered() then
    ChangeTooltip(self)
  end
end

--- Returns what the keys of the hotbar act on while the cursor is over the slot: its entry (see
-- `Hotbar.get_hover_target`).
-- @return [Item the item that the slot shows, Number the slot, Item the instance that the drop
--   key drops, nil for a pin that the player has none of; nothing for a slot without an entry]
function PANEL:get_hover_target()
  if !self.kind then return end

  return self.item_data, self.slot, Hotbar.get_slot_state(self.slot)?.instance
end

--- Removes the icon or the model of the item of the slot.
function PANEL:remove_icon()
  if IsValid(self.icon_panel) then
    self.icon_panel:Remove()
  end

  if IsValid(self.model_panel) then
    self.model_panel:Remove()
  end

  self.icon_panel, self.model_panel = nil, nil
end

--- Forgets the button that the slot was pressed with, so that its release does nothing, and
-- gives up the mouse capture of that press. Ends a drag of the slot, or the wait for one that
-- the press has started, which keeps its entry on the hotbar, and stops showing the slot as
-- dragged when its drag state has been cleared under it.
function PANEL:end_drag()
  local is_pressed = self.pressed_code != nil
  local is_dragged = dragndrop.m_DraggingMain == self or dragndrop.m_DragWatch == self

  self.pressed_code = nil
  self.Dragging = false

  if !is_pressed and !is_dragged then return end

  self:MouseCapture(false)

  if is_dragged then
    dragndrop.StopDragging()
  end
end

--- Draws the slot: its background, the background color of its item, the fixed icon of the
-- hands, the physgun or the tool gun, and what the theme and the paint_slot callback of the
-- item draw.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  local radius = get_option('corner_radius_small', math_scale(4))
  local item_obj = self.item_data
  local background = (item_obj or self.fixed_icon) and get_color('surface_raised', slot_color)
    or get_color('surface_sunken', slot_color_empty)

  draw_rounded_box(radius, 0, 0, w, h, background)

  if self:IsDragging() then return end

  self:paint_item_background(w, h, radius)

  local icon = self.fixed_icon

  if icon then
    local size = h * 0.6

    surface_set_draw_color(255, 255, 255, 255)
    surface_set_material(icon)
    surface_draw_textured_rect((w - size) * 0.5, (h - size) * 0.5, size, size)
  end

  Theme.hook('PaintItemSlot', self, w, h)

  if item_obj and item_obj.paint_slot then
    item_obj:paint_slot(w, h)
  end
end

--- Draws over the slot and the icon or the model of its item: a shade over a pinned item that
-- the player has none of, the key number, the amount of a pinned item, what the theme and the
-- paint_over_slot callback of the item draw, and last the ring around the selected or hovered
-- slot, which keeps its color whatever is under it.
-- @param w [Number]
-- @param h [Number]
function PANEL:PaintOver(w, h)
  local radius = get_option('corner_radius_small', math_scale(4))

  if !self:IsDragging() then
    local margin = self.badge_margin

    if self.kind == 'pin' then
      if self.is_empty_pin then
        draw_rounded_box(radius, 0, 0, w, h, dimmed_color)
      end

      self:draw_badge(self.amount_text, w - margin, h - self:get_badge_height() - margin, get_color('text'), true)
    end

    self:draw_badge(self.key_text, margin, margin, get_color('text_muted'))

    Theme.hook('PaintOverItemSlot', self, w, h)

    local item_obj = self.item_data

    if item_obj and item_obj.paint_over_slot then
      item_obj:paint_over_slot(w, h)
    end
  end

  local ring_color = self.slot == Hotbar.selected and get_color('accent', selected_ring_color)
    or self:IsHovered() and get_color('accent_light', hovered_ring_color)

  if ring_color then
    draw_box_outlined(radius, 0, 0, w, h, self.ring_width, ring_color)
  end
end

--- Remembers the button, takes the mouse capture, so that the release of the button comes back
-- to the slot, starts watching for the slot being dragged and shows the slot as not dragged. A
-- press during a drag is not remembered and takes no capture; on a slot with an entry it
-- cancels the drag, which keeps the dragged entry on the hotbar. A press while the drag state
-- has been cleared under an earlier press or drag of the slot (see `PANEL:is_drag_cut`) ends
-- that one through `PANEL:end_drag` and is neither remembered nor watched for a drag, so that
-- neither its release nor the release of the earlier button selects, clears or drops anything.
-- @param mouse_code [Number MOUSE_ enumerator]
function PANEL:OnMousePressed(mouse_code)
  if self:is_drag_cut() then
    self:end_drag()

    return
  end

  local is_dragging = dragndrop.IsDragging()

  self.pressed_code = !is_dragging ? mouse_code : nil

  if !is_dragging then
    self.Dragging = false
    self:MouseCapture(true)
  end

  dpanel.OnMousePressed(self, mouse_code)
end

--- Checks whether the slot has been pressed with an entry, which starts the wait for a drag of
-- it, and the drag state has been cleared since, so that neither the wait nor a drag of the
-- slot is going on any more.
-- @return [Boolean]
function PANEL:is_drag_cut()
  return self.pressed_code != nil and self:IsDraggable() and dragndrop.m_DragWatch != self
    and dragndrop.m_DraggingMain != self
end

--- Forgets the button that the slot was pressed with and, when the released button is that one
-- and the cursor is still over the slot, selects the slot on a left click and takes its entry
-- off the hotbar on a right click. A release that ends a drag does neither: when the slot is
-- the one being dragged and the button is the one that drags it, the release drops it, and the
-- slot is marked as dropping while it does, for `PANEL:OnStopDragging`. A release after the
-- drag state has been cleared under a press or a drag of the slot (see `PANEL:is_drag_cut`)
-- does neither, wherever the cursor is: it gives up the mouse capture and shows the slot as not
-- dragged.
-- @param mouse_code [Number MOUSE_ enumerator]
function PANEL:OnMouseReleased(mouse_code)
  local was_dragging = dragndrop.IsDragging()
  local is_cut = self:is_drag_cut()
  local pressed_code = self.pressed_code

  self.pressed_code = nil
  self.is_dropping = was_dragging and dragndrop.m_DraggingMain == self and dragndrop.m_MouseCode == mouse_code

  if is_cut then
    self.Dragging = false
  end

  dpanel.OnMouseReleased(self, mouse_code)

  self.is_dropping = nil

  if is_cut or was_dragging or pressed_code != mouse_code or !self:IsHovered() then return end

  if mouse_code == MOUSE_LEFT then
    Hotbar.select(self.slot)
  elseif mouse_code == MOUSE_RIGHT and self.kind then
    Cable.send('fl_hotbar_clear', self.slot)
  end
end

--- Drops the item of the entry of the slot into the world when the drag of the slot ends with
-- the drop that its own release makes, no receiver has handled that drop, the world is under
-- the cursor (see `Hotbar.is_world_panel`) and the cursor is outside the card that the theme
-- draws around the bar (see `Hotbar.is_cursor_on_card`). Every other end of the drag keeps the
-- entry; the receivers of the bar, of the inventory panels, of the inventory tab and of the tab
-- menu handle the drops onto them.
function PANEL:OnStopDragging()
  self.Dragging = false

  if self.is_dropping and !self.drop_handled and self.kind and Hotbar.is_world_panel(vgui.GetHoveredPanel())
    and !Hotbar.is_cursor_on_card(self:GetParent()) then
    Hotbar.drop_entry(self.slot)
  end

  self.is_dropping = nil
  self.drop_handled = nil
end

vgui.Register('fl_hotbar_slot', PANEL, 'fl_inventory_item')
