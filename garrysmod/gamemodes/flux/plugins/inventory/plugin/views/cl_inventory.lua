local PANEL = {}
PANEL.inventory = {}
PANEL.slots = {}
PANEL.inventory_type = 'main_inventory'
PANEL.player = nil

local slot_size = Font.scale(64)

function PANEL:Init()
  self.title = nil

  self.horizontal_scroll = vgui.create('DHorizontalScroller', self)
  self.horizontal_scroll.OnMouseWheeled = function(pnl, dlta)
    if !input.IsKeyDown(KEY_LSHIFT) then return end

    pnl.OffsetX = pnl.OffsetX + dlta * -30
    pnl:InvalidateLayout(true)

    return true
  end

  self.scroll = vgui.create('DScrollPanel', self)
  self.scroll.VBar.OnMouseWheeled = function(pnl, dlta)
    if !pnl:IsVisible() or input.IsKeyDown(KEY_LSHIFT) then return false end

    return pnl:AddScroll(dlta * -2)
  end

  self.horizontal_scroll:AddPanel(self.scroll)
end

function PANEL:Paint(w, h)
  Theme.hook('PaintInventoryBackground', self, w, h)
end

function PANEL:PaintOver(w, h)
  Theme.hook('PaintOverInventoryBackground', self, w, h)
end

function PANEL:resize()
  local max_w, max_h = self:get_max_size()
  local padding = self:get_slot_padding()
  local width = self.inv_w * (slot_size + padding) - padding
  local height = self.inv_h * (slot_size + padding) - padding

  if height >= max_h then
    width = width + 16
  end

  self.scroll:SetWide(width)
  self.horizontal_scroll:SetSize(math.min(width, max_w), math.min(height, max_h))
end

function PANEL:set_inventory(inventory)
  self.inventory = inventory

  self:set_inv_size(inventory.width, inventory.height)

  for i = 1, self.inv_h do
    self.inventory[i] = self.inventory[i] or {}

    for k = 1, self.inv_w do
      self.inventory[i][k] = self.inventory[i][k] or {}
    end
  end
end

function PANEL:set_player(player)
  self.player = player
  self:set_inventory(player:get_inventory(self.inventory_type))

  self:rebuild()
end

function PANEL:get_player()
  return self.player
end

function PANEL:set_inv_size(inv_w, inv_h)
  self.inv_w = inv_w or 8
  self.inv_h = inv_h or 8
end

function PANEL:slots_to_inventory()
  for i = 1, self.inv_h do
    for k = 1, self.inv_w do
      local slot = self.slots[i][k]

      if slot.item_data and #slot.instance_ids > 0 then
        self.inventory[i][k] = slot.instance_ids
      else
        self.inventory[i][k] = {}
      end
    end
  end

  Cable.send('fl_inventory_sync', self.inventory)
end

function PANEL:rebuild()
  dragndrop.Clear()

  self.scroll:Clear()
  self.slots = {}

  if IsValid(self.player) then
    self:set_inventory(self.player:get_inventory(self.inventory_type))
  end

  for i = 1, self.inv_h do
    for k = 1, self.inv_w do
      local inv_slot = vgui.create('fl_inventory_item', self)
      inv_slot:SetSize(slot_size, slot_size)
      inv_slot:SetPos((k - 1) * (slot_size + self:get_slot_padding()), (i - 1) * (slot_size + self:get_slot_padding()))
      inv_slot:set_inventory_panel(self)
      inv_slot.inv_x = k
      inv_slot.inv_y = i

      if self.draw_inventory_slots then
        inv_slot.slot_number = k + (i - 1) * self.inv_w
      end

      if self.inventory[i][k] and #self.inventory[i][k] > 0 then
        if #self.inventory[i][k] > 1 then
          inv_slot:set_item_multi(self.inventory[i][k])
        else
          inv_slot:set_item(self.inventory[i][k][1])
        end
      end

      self.slots[i] = self.slots[i] or {}
      self.slots[i][k] = inv_slot

      self.scroll:AddItem(inv_slot)

      inv_slot:Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
        if is_dropped then
          Flux.inventory_drag_slot = nil

          local split = false

          if input.IsKeyDown(KEY_LCONTROL) and dropped[1].item_count > 1 then
            split = {}

            for i2 = 1, dropped[1].item_count * 0.5 do
              table.insert(split, dropped[1].instance_ids[i2])
            end
          end

          Cable.send('fl_item_move', !split and dropped[1].instance_ids or split, self.inventory_type, receiver.inv_x, receiver.inv_y)
        else
          receiver.is_hovered = true
        end
      end, { 'Place' })

      self:GetParent():Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
        if is_dropped then
          hook.run('PlayerDropItem', dropped[1].item_data, dropped[1], mouse_x, mouse_y)
        end
      end, {})

      local player_panel = self:GetParent().player_model

      if IsValid(player_panel) then
        player_panel:Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
          if is_dropped then
            local item_table = dropped[1].item_data

            if item_table.equip_slot and !item_table:is_equipped() then
              dropped[1].item_data:do_menu_action('on_use')
            end
          end
        end, {})
      end

      self:Receiver('fl_item')
    end
  end

  self:SetSize(self:get_max_size())
  self:resize()
  self:SetSize(self.horizontal_scroll:GetSize())
end

function PANEL:set_max_size(max_w, max_h)
  self.max_w = max_w
  self.max_h = max_h
end

function PANEL:get_max_size()
  local parent = self:GetParent()
  local max_w, max_h

  if IsValid(parent) then
    max_w, max_h = parent:GetSize()
  end

  return self.max_w or max_w or ScrW(), self.max_h or max_h or ScrH()
end

function PANEL:set_slot_padding(num)
  self.slot_padding = num
end

function PANEL:get_slot_padding()
  return self.slot_padding or 1
end

vgui.Register('fl_inventory', PANEL, 'fl_base_panel')
