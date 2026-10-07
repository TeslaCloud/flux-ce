local PANEL = {}
PANEL.title = nil
PANEL.slot_size = math.scale(64)
PANEL.slot_padding = math.scale(1)
PANEL.draw_inventory_slots = false

--- Creates the scrollable grid of slots and makes it accept dragged items.
-- Items dropped onto the parent panel get dropped into the world.
function PANEL:Init()
  self:RequestFocus()
  self.slot_panels = {}

  self.horizontal_scroll = vgui.create('DHorizontalScroller', self)
  self.horizontal_scroll.OnMouseWheeled = function(pnl, dlta)
    if !input.IsKeyDown(KEY_LSHIFT) then return false end

    pnl.OffsetX = pnl.OffsetX + dlta * -30
    pnl:InvalidateLayout(true)

    return true
  end

  self.scroll = vgui.create('DScrollPanel', self)
  self.scroll:GetVBar().OnMouseWheeled = function(pnl, dlta)
    if input.IsKeyDown(KEY_LSHIFT) then return false end

    return pnl:AddScroll(dlta * -2)
  end
  self.scroll:GetCanvas():Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
    dropped = dropped[1]

    if dropped:IsVisible() then
      self:start_dragging(dropped)
    end

    if is_dropped then
      self:on_drop(dropped)
    else
      local slot_w, slot_h = dropped:get_item_size()
      local drop_slot = Flux.inventory_drop_slot
      local is_multislot = self:is_multislot()
      local slot_size = self:get_slot_size()
      local w, h = 0, 0

      if is_multislot and (slot_w > 1 or slot_h > 1) then
        w, h = (slot_w - 1) * 0.5 * slot_size, (slot_h - 1) * 0.5 * slot_size
      end

      local slot = receiver:GetClosestChild(mouse_x - w, mouse_y - h)

      slot.is_hovered = true

      if IsValid(drop_slot) then
        if slot != drop_slot then
          drop_slot.is_hovered = false
        else
          return
        end
      end

      local slot_x, slot_y = slot:get_item_pos()
      local inventory_width, inventory_height = self:get_inventory_size()

      if is_multislot then
        if slot_x + slot_w - 1 > inventory_width or slot_y + slot_h - 1 > inventory_height then
          slot.out_of_bounds = true
        else
          slot.out_of_bounds = false
        end
      end

      Flux.inventory_drop_slot = slot
    end
  end)

  self.horizontal_scroll:AddPanel(self.scroll)

  local parent = self:GetParent()

  if IsValid(parent) then
    parent:Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
      local dropped = dropped[1]

      if is_dropped then
        Cable.send('fl_item_drop', dropped.instance_ids)
      else
        local drop_slot = Flux.inventory_drop_slot

        if IsValid(drop_slot) then
          drop_slot.is_hovered = false
          Flux.inventory_drop_slot = nil
        end
      end
    end)
  end
end

--- Rotates the item that is being dragged when R is pressed.
-- @param key [Number KEY_ enumerator]
function PANEL:OnKeyCodePressed(key)
  local droppable = dragndrop.GetDroppable('fl_item')

  if droppable then
    droppable = droppable[1]

    if key == KEY_R and IsValid(droppable) then
      droppable:turn()

      local drop_slot = Flux.inventory_drop_slot

      if IsValid(drop_slot) then
        drop_slot.is_hovered = false
        Flux.inventory_drop_slot = nil
      end
    end
  end
end

--- Resizes the scroll panels to fit the grid of slots.
-- @param w [Number]
-- @param h [Number]
function PANEL:PerformLayout(w, h)
  local slot_size, slot_padding = self:get_slot_size(), self:get_slot_padding()
  local width = (slot_size + slot_padding) * self:get_inventory_width() - slot_padding
  local height = (slot_size + slot_padding) * self:get_inventory_height() - slot_padding

  if height > h then
    width = width + math.scale_x(16) + slot_padding
  end

  self.scroll:SetWide(width)
  self.horizontal_scroll:SetSize(math.min(w, width), math.min(h, height))
end

--- Draws the background of the inventory using the theme.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  Theme.hook('PaintInventoryBackground', self, w, h)
end

--- Draws over the inventory using the theme.
-- @param w [Number]
-- @param h [Number]
function PANEL:PaintOver(w, h)
  Theme.hook('PaintOverInventoryBackground', self, w, h)
end

--- Resizes the panel so that all slots of the inventory fit in it.
function PANEL:SizeToContents()
  local slot_size, slot_padding = self:get_slot_size(), self:get_slot_padding()
  local width = (slot_size + slot_padding) * self:get_inventory_width() - slot_padding
  local height = (slot_size + slot_padding) * self:get_inventory_height() - slot_padding

  self:SetSize(width, height)
end

--- Hides the item panel that is being dragged and puts empty slots in its place.
-- @param dropped [Panel the fl_inventory_item panel that is being dragged]
function PANEL:start_dragging(dropped)
  local w, h = dropped:get_item_size()
  local x, y = dropped:get_item_pos()
  local slot_size = self:get_slot_size()
  local slot_padding = self:get_slot_padding()
  local drag_inventory_id = dropped:get_inventory_id()
  local panel = self

  if drag_inventory_id != self:get_inventory_id() then
    panel = Inventories.find(drag_inventory_id).panel
  end

  dropped:SetVisible(false)

  for i = y, y + h - 1 do
    for k = x, x + w - 1 do
      if i == y and k == x then
        local slot = vgui.create('fl_inventory_item', panel.scroll)
        slot:SetSize(slot_size, slot_size)
        slot:SetPos((k - 1) * (slot_size + slot_padding), (i - 1) * (slot_size + slot_padding))
        slot.slot_x = k
        slot.slot_y = i
        slot.inventory_id = panel:get_inventory_id()
        slot.multislot = panel:is_multislot()

        local icon = panel:get_icon()

        if icon then
          slot.icon = icon
        end

        if panel:is_disabled() then
          slot.disabled = true
        end

        if panel.draw_inventory_slots == true then
          slot.slot_number = k + (i - 1) * panel:get_inventory_width()
        end
      elseif panel:is_multislot() then
        local slot = panel.slot_panels[i][k]
        slot:reset()
        slot:SetVisible(true)
      end
    end
  end
end

--- Handles an item panel being dropped onto the inventory by asking the server to move
-- its items to the hovered slot. Holding CTRL moves half of the stack, SHIFT a single item.
-- @param dropped [Panel the fl_inventory_item panel that has been dropped]
function PANEL:on_drop(dropped)
  local drop_slot = Flux.inventory_drop_slot

  if drop_slot.out_of_bounds then
    self:rebuild()

    local drag_slot = Flux.inventory_drag_slot

    if IsValid(drag_slot) then
      local drag_inventory_id = drag_slot:get_inventory_id()

      if drag_inventory_id != self:get_inventory_id() then
        local panel = Inventories.find(drag_inventory_id).panel

        if IsValid(panel) then
          panel:rebuild()
        end
      end
    end

    return
  end

  Flux.inventory_drag_slot = nil
  Flux.inventory_drop_slot = nil

  drop_slot.is_hovered = false

  local split = false

  if dropped.item_count > 1 then
    if input.IsKeyDown(KEY_LCONTROL) then
      split = {}

      for i2 = 1, dropped.item_count * 0.5 do
        table.insert(split, dropped.instance_ids[i2])
      end
    elseif input.IsKeyDown(KEY_LSHIFT) then
      split = { dropped.instance_ids[1] }
    end
  end

  local instance_ids = !split and dropped.instance_ids or split

  Cable.send('fl_item_move', instance_ids, self:get_inventory_id(), drop_slot.slot_x, drop_slot.slot_y, dropped:was_rotated())
end

--- Sets the inventory that the panel displays and rebuilds the panel.
-- @param inventory_id [Number id of the inventory]
function PANEL:set_inventory_id(inventory_id)
  self.inventory_id = inventory_id

  self:rebuild()
end

--- Recreates the slot panels based on the current contents of the inventory.
-- Runs the 'OnInventoryRebuild' hook afterwards.
function PANEL:rebuild()
  dragndrop.Clear()
  self.scroll:Clear()

  for i = 1, self:get_inventory_height() do
    self.slot_panels[i] = {}
  end

  local slot_size = self:get_slot_size()
  local slot_padding = self:get_slot_padding()
  local width, height = self:get_inventory_size()

  for i = 1, height do
    for k = 1, width do
      local slot = vgui.create('fl_inventory_item', self.scroll)
      slot:SetSize(slot_size, slot_size)
      slot:SetPos((k - 1) * (slot_size + slot_padding), (i - 1) * (slot_size + slot_padding))
      slot.slot_x = k
      slot.slot_y = i
      slot.inventory_id = self:get_inventory_id()
      slot.multislot = self:is_multislot()

      if self.draw_inventory_slots == true then
        slot.slot_number = k + (i - 1) * width
      end

      local icon = self:get_icon()

      if icon then
        slot.icon = icon
      end

      if self:is_disabled() then
        slot.disabled = true
      end

      if self.slot_panels[i][k] == false then
        slot:SetVisible(false)
      else
        local instance_ids = self:get_slot(k, i)

        if instance_ids and #instance_ids > 0 then
          if #instance_ids == 1 then
            slot:set_item(instance_ids[1])
          else
            slot:set_item_multi(instance_ids)
          end
        end

        if self:is_multislot() and slot:IsVisible() then
          local w, h = slot:get_item_size()

          if w > 1 or h > 1 then
            for m = 1, h do
              for n = 1, w do
                self.slot_panels[i + m - 1][k + n - 1] = false
              end
            end

            slot:SetSize((slot_size + slot_padding) * w - slot_padding, (slot_size + slot_padding) * h - slot_padding)
            slot:rebuild()
          end
        end
      end

      self.slot_panels[i][k] = slot
      self.scroll:AddItem(slot)
    end
  end

  hook.run('OnInventoryRebuild', self)
end

--- Sets the size of a single slot.
-- @param size [Number size in pixels]
function PANEL:set_slot_size(size)
  self.slot_size = size
end

--- Sets the gap between the slots.
-- @param padding [Number gap in pixels]
function PANEL:set_slot_padding(padding)
  self.slot_padding = padding
end

--- Sets the icon that is drawn in the slots of the inventory.
-- @param icon [String FontAwesome icon id ('fa-...') or path to a material; nil for no icon]
function PANEL:set_icon(icon)
  self.icon = icon
end

--- Returns the inventory that the panel displays.
-- @return [Inventory]
function PANEL:get_inventory()
  return Inventories.find(self:get_inventory_id())
end

--- Returns the id of the inventory that the panel displays.
-- @return [Number]
function PANEL:get_inventory_id()
  return self.inventory_id
end

--- Returns the width of the inventory in a number of slots.
-- @return [Number]
function PANEL:get_inventory_width()
  return self:get_inventory():get_width()
end

--- Returns the height of the inventory in a number of slots.
-- @return [Number]
function PANEL:get_inventory_height()
  return self:get_inventory():get_height()
end

--- Returns the size of the inventory in a number of slots.
-- @return [Number width, Number height]
function PANEL:get_inventory_size()
  return self:get_inventory():get_size()
end

--- Returns the type of the inventory.
-- @return [String]
function PANEL:get_inventory_type()
  return self:get_inventory():get_type()
end

--- Returns the slots grid of the inventory.
-- @return [Hash slots, indexed by y and then by x; every slot is an array of instance ids]
function PANEL:get_slots()
  return self:get_inventory():get_slots()
end

--- Returns the instance ids of the items located in the specified slot of the inventory.
-- @param x [Number]
-- @param y [Number]
-- @return [Array<Number> instance ids, or nil if the slot is out of the inventory bounds]
function PANEL:get_slot(x, y)
  return self:get_inventory():get_slot(x, y)
end

--- Returns the entity that the inventory belongs to.
-- @return [Entity]
function PANEL:get_owner()
  return self:get_inventory():get_owner()
end

--- Returns the size of a single slot.
-- @return [Number size in pixels]
function PANEL:get_slot_size()
  return self.slot_size
end

--- Returns the gap between the slots.
-- @return [Number gap in pixels]
function PANEL:get_slot_padding()
  return self.slot_padding
end

--- Checks if the inventory is multislot.
-- @return [Boolean]
function PANEL:is_multislot()
  return self:get_inventory():is_multislot()
end

--- Checks if the inventory is disabled.
-- @return [Boolean]
function PANEL:is_disabled()
  return self:get_inventory():is_disabled()
end

--- Sets whether the slots display their numbers.
-- The value is stored on the panel under the name of this method,
-- so the method cannot be called on the same panel again.
-- @param bool [Boolean]
function PANEL:draw_inventory_slots(bool)
  self.draw_inventory_slots = bool
end

--- Returns the icon that is drawn in the slots of the inventory.
-- @return [String FontAwesome icon id or path to a material, or nil if there is no icon]
function PANEL:get_icon()
  return self.icon
end

vgui.Register('fl_inventory', PANEL, 'fl_base_panel')
