local PANEL = {}
PANEL.itemData = nil
PANEL.itemCount = 0
PANEL.instance_ids = {}
PANEL.isHovered = false
PANEL.slot_number = nil

function PANEL:SetItem(instance_id)
  if istable(instance_id) then
    if #instance_id > 1 then
      self:SetItemMulti(instance_id)

      return
    else
      return self:SetItem(instance_id[1])
    end
  end

  if isnumber(instance_id) then
    self.itemData = item.FindInstanceByID(instance_id)

    if self.itemData then
      self.itemCount = 1
      self.instance_ids = {instance_id}
    end

    self:Rebuild()
  end
end

function PANEL:SetItemMulti(ids)
  local itemData = item.FindInstanceByID(ids[1])

  if itemData and !itemData.stackable then return end

  self.itemData = itemData
  self.itemCount = #ids
  self.instance_ids = ids
  self:Rebuild()
end

function PANEL:Combine(panel2)
  for i = 1, #panel2.instance_ids do
    if #self.instance_ids < self.itemData.max_stack then
      table.insert(self.instance_ids, panel2.instance_ids[1])
      table.remove(panel2.instance_ids, 1)
    end
  end

  self.itemCount = #self.instance_ids
  self:Rebuild()

  panel2.itemCount = #panel2.instance_ids

  if panel2.itemCount > 0 then
    panel2:Rebuild()
  else
    panel2:Reset()
  end
end

function PANEL:Reset()
  self.itemData = nil
  self.itemCount = 0

  self:Rebuild()
  self:UnDraggable()
end

function PANEL:Paint(w, h)
  local drawColor = Color(0, 0, 0, 150)

  if self.isHovered and !self:IsHovered() then
    self.isHovered = false
  end

  if !self.isHovered then
    if !self.itemData then
      drawColor = drawColor:darken(25)
    else
      if self.itemData.special_color then
        surface.SetDrawColor(self.itemData.special_color)
        surface.DrawOutlinedRect(0, 0, w, h)
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
      end

      if self:IsHovered() then
        surface.SetDrawColor(Color(255, 255, 255))
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
      end
    end
  else
    local item_table = self.itemData
    local curSlot = fl.inventoryDragSlot

    if item_table then
      if IsValid(curSlot) and curSlot.itemData != item_table then
        local slotData = curSlot.itemData

        if slotData.id == item_table.id and slotData.stackable and curSlot.itemCount < slotData.max_stack then
          drawColor = Color(200, 200, 60)
        else
          drawColor = Color(200, 60, 60, 160)
        end
      else
        drawColor = drawColor:lighten(30)
      end
    else
      drawColor = Color(60, 200, 60, 160)
    end
  end

  draw.RoundedBox(0, 0, 0, w, h, drawColor)

  if self.itemCount >= 2 then
    DisableClipping(true)
      draw.SimpleText(self.itemCount, theme.get_font('text_smallest'), 52, 50, Color(200, 200, 200))
    DisableClipping(false)
  end

  if isnumber(self.slot_number) then
    DisableClipping(true)
      draw.SimpleText(self.slot_number, theme.get_font('text_smallest'), 4, 50, Color(200, 200, 200))
    DisableClipping(false)
  end
end

function PANEL:Rebuild()
  if !self.itemData then
    if IsValid(self.spawnIcon) then
      self.spawnIcon:safe_remove()
    end

    self:UnDraggable()

    return
  else
    self:Droppable('flItem')
  end

  if IsValid(self.spawnIcon) then
    self.spawnIcon:SetVisible(false)
    self.spawnIcon:Remove()
  end

  self.spawnIcon = vgui.Create('SpawnIcon', self)
  self.spawnIcon:SetPos(2, 2)
  self.spawnIcon:SetSize(60, 60)
  self.spawnIcon:SetModel(self.itemData.model, self.itemData.skin)
  self.spawnIcon:SetMouseInputEnabled(false)
end

function PANEL:OnMousePressed(...)
  self.mousePressed = CurTime()
  fl.inventoryDragSlot = self

  self.BaseClass.OnMousePressed(self, ...)
end

function PANEL:OnMouseReleased(...)
  local x, y = self:LocalToScreen(0, 0)
  local w, h = self:GetSize()

  if surface.mouse_in_rect(x, y, w, h) then
    if self.itemData and self.mousePressed and self.mousePressed > (CurTime() - 0.15) then
      fl.inventoryDragSlot = nil

      if #self.instance_ids > 1 then
        hook.run('PlayerUseItemMenu', self.instance_ids)
      else
        hook.run('PlayerUseItemMenu', self.itemData)
      end
    end
  end

  self.BaseClass.OnMouseReleased(self, ...)
end

vgui.Register('flInventoryItem', PANEL, 'DPanel')

local PANEL = {}
PANEL.inventory = {}
PANEL.slots = {}
PANEL.inventory_slots = 8
PANEL.inventory_type = 'inventory'
PANEL.player = nil

function PANEL:SetInventory(inv)
  self.inventory = inv
end

function PANEL:SetPlayer(player)
  self.player = player
  self:SetInventory(player:GetInventory(self.inventory_type))

  self:Rebuild()
end

function PANEL:SetSlots(num)
  self.inventory_slots = num

  self:Rebuild()
end

function PANEL:SlotsToInventory()
  for k, v in ipairs(self.slots) do
    if v.slotNum and v.itemData and #v.instance_ids > 0 then
      self.inventory[v.slotNum] = v.instance_ids
    else
      self.inventory[v.slotNum] = {}
    end
  end

  cable.send('InventorySync', self.inventory)
end

function PANEL:GetMenuSize()
  return font.scale(560), font.scale(self.inventory_slots * 0.125 * 68 + 36)
end

function PANEL:Rebuild()
  dragndrop.Clear()

  local multiplier = self.inventory_slots / 8

  self:SetSize(560, multiplier * 68 + 36)

  if IsValid(self.player) then
    self:SetInventory(self.player:GetInventory(self.inventory_type))
  end

  self.scroll = self.scroll or vgui.Create('DScrollPanel', self) //Create the Scroll panel
  self.scroll:SetSize(self:GetWide(), self:GetTall())
  self.scroll:SetPos(10, 32)

  if IsValid(self.list) then
    self.list:Clear()
  end

  self.list = self.list or vgui.Create('DIconLayout', self.scroll)
  self.list:SetSize(self:GetWide(), self:GetTall())
  self.list:SetPos(0, 0)
  self.list:SetSpaceY(4)
  self.list:SetSpaceX(4)

  for i = 1, self.inventory_slots do
    local invSlot = self.list:Add('flInventoryItem')
    invSlot:SetSize(64, 64)
    invSlot.slotNum = i

    if self.draw_inventory_slots then
      invSlot.slot_number = i
    end

    if self.inventory[i] and #self.inventory[i] > 0 then
      if #self.inventory[i] > 1 then
        invSlot:SetItemMulti(self.inventory[i])
      else
        invSlot:SetItem(self.inventory[i][1])
      end
    end

    invSlot:Receiver('flItem', function(receiver, dropped, isDropped, menuIndex, mouseX, mouseY)
      if isDropped then
        fl.inventoryDragSlot = nil

        if receiver.itemData then
          if (receiver.itemData.id == dropped[1].itemData.id and
            receiver.slotNum != dropped[1].slotNum and receiver.itemData.stackable) then
            receiver:Combine(dropped[1])
            self:SlotsToInventory()

            return
          else
            receiver.isHovered = false

            return
          end
        end

        local split = false

        if input.IsKeyDown(KEY_LCONTROL) and dropped[1].itemCount > 1 then
          split = {{}, {}}

          for i2 = 1, dropped[1].itemCount do
            if i2 <= math.floor(dropped[1].itemCount * 0.5) then
              table.insert(split[1], dropped[1].instance_ids[i2])
            else
              table.insert(split[2], dropped[1].instance_ids[i2])
            end
          end
        end

        if !split then
          receiver:SetItem(dropped[1].instance_ids)
        else
          receiver:SetItemMulti(split[1])
          dropped[1]:SetItemMulti(split[2])
        end

        receiver.isHovered = false

        if !split then
          dropped[1]:Reset()
        else
          dropped[1]:Rebuild()
        end

        self:SlotsToInventory()
      else
        receiver.isHovered = true
      end
    end, {'Place'})

    self.slots[i] = invSlot
  end

  self:GetParent():Receiver('flItem', function(receiver, dropped, isDropped, menuIndex, mouseX, mouseY)
    if isDropped then
      hook.run('PlayerDropItem', dropped[1].itemData, dropped[1], mouseX, mouseY)
    end
  end, {})
end

vgui.Register('fl_inventory', PANEL, 'fl_base_panel')
