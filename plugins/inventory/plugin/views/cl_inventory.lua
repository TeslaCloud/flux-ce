local PANEL = {}
PANEL.title = nil
PANEL.slot_size = math.scale(64)
PANEL.slot_padding = math.scale(1)
PANEL.draw_inventory_slots = false

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
      local w, h = dropped:GetSize()
      local slot_w, slot_h = dropped:get_item_size()
      local drop_slot = Flux.inventory_drop_slot
      local is_multislot = self:is_multislot()

      w, h = w * ((!is_multislot or slot_w == 1) and 0 or 0.25), h * ((!is_multislot or slot_h == 1) and 0 or 0.25)

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

function PANEL:Paint(w, h)
  Theme.hook('PaintInventoryBackground', self, w, h)
end

function PANEL:PaintOver(w, h)
  Theme.hook('PaintOverInventoryBackground', self, w, h)
end

function PANEL:SizeToContents()
  local slot_size, slot_padding = self:get_slot_size(), self:get_slot_padding()
  local width = (slot_size + slot_padding) * self:get_inventory_width() - slot_padding
  local height = (slot_size + slot_padding) * self:get_inventory_height() - slot_padding

  self:SetSize(width, height)
end

function PANEL:start_dragging(dropped)
  local w, h = dropped:get_item_size()
  local x, y = dropped:get_item_pos()
  local slot_size = self:get_slot_size()
  local slot_padding = self:get_slot_padding()

  dropped:SetVisible(false)

  for i = y, y + h - 1 do
    for k = x, x + w - 1 do
      if i == y and k == x then
        local slot = vgui.create('fl_inventory_item', self.scroll)
        slot:SetSize(slot_size, slot_size)
        slot:SetPos((k - 1) * (slot_size + slot_padding), (i - 1) * (slot_size + slot_padding))
        slot.slot_x = k
        slot.slot_y = i
        slot.inventory_id = self:get_inventory_id()
        slot.multislot = self:is_multislot()

        local icon = self:get_icon()

        if icon then
          slot.icon = icon
        end

        if self.draw_inventory_slots == true then
          slot.slot_number = k + (i - 1) * self:get_inventory_width()
        end
      elseif self:is_multislot() then
        local slot = self.slot_panels[i][k]
        slot:reset()
        slot:SetVisible(true)
      end
    end
  end
end

function PANEL:on_drop(dropped)
  local drop_slot = Flux.inventory_drop_slot

  if drop_slot.out_of_bounds then self:rebuild() return end

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

function PANEL:set_inventory_id(inventory_id)
  self.inventory_id = inventory_id

  self:rebuild()
end

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

function PANEL:set_slot_size(size)
  self.slot_size = size
end

function PANEL:set_slot_padding(padding)
  self.slot_padding = padding
end

function PANEL:set_icon(icon)
  self.icon = icon
end

function PANEL:get_inventory()
  return Inventories.find(self:get_inventory_id())
end

function PANEL:get_inventory_id()
  return self.inventory_id
end

function PANEL:get_inventory_width()
  return self:get_inventory():get_width()
end

function PANEL:get_inventory_height()
  return self:get_inventory():get_height()
end

function PANEL:get_inventory_size()
  return self:get_inventory():get_size()
end

function PANEL:get_inventory_type()
  return self:get_inventory():get_type()
end

function PANEL:get_slots()
  return self:get_inventory():get_slots()
end

function PANEL:get_slot(x, y)
  return self:get_inventory():get_slot(x, y)
end

function PANEL:get_slot_size()
  return self.slot_size
end

function PANEL:get_slot_padding()
  return self.slot_padding
end

function PANEL:is_multislot()
  return self:get_inventory():is_multislot()
end

function PANEL:draw_inventory_slots(bool)
  self.draw_inventory_slots = bool
end

function PANEL:get_icon()
  return self.icon
end

vgui.Register('fl_inventory', PANEL, 'fl_base_panel')
