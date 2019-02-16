local PANEL = {}
PANEL.item_data = nil
PANEL.item_count = 0
PANEL.instance_ids = {}
PANEL.is_hovered = false
PANEL.slot_number = nil

function PANEL:Paint(w, h)
  local draw_color = Color(0, 0, 0, 150)

  if self.is_hovered and !self:IsHovered() then
    self.is_hovered = false
  end

  if !self.is_hovered then
    if !self.item_data then
      draw_color = draw_color:darken(25)
    else
      if self.item_data.special_color then
        surface.SetDrawColor(self.item_data.special_color)
        surface.DrawOutlinedRect(0, 0, w, h)
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
      end

      if self:IsHovered() then
        surface.SetDrawColor(Color(255, 255, 255))
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
      end
    end
  else
    local item_table = self.item_data
    local cur_slot = fl.inventory_drag_slot

    if item_table then
      if IsValid(cur_slot) and cur_slot.item_data != item_table then
        local slot_data = cur_slot.item_data

        if slot_data.id == item_table.id and slot_data.stackable and cur_slot.item_count < slot_data.max_stack then
          draw_color = Color(200, 200, 60)
        else
          draw_color = Color(200, 60, 60, 160)
        end
      else
        draw_color = draw_color:lighten(30)
      end
    else
      draw_color = Color(60, 200, 60, 160)
    end
  end

  draw.RoundedBox(0, 0, 0, w, h, draw_color)

  if self.item_count >= 2 then
    DisableClipping(true)
      draw.SimpleText(self.item_count, theme.get_font('text_smallest'), 52, 50, Color(200, 200, 200))
    DisableClipping(false)
  end

  if isnumber(self.slot_number) then
    DisableClipping(true)
      draw.SimpleText(self.slot_number, theme.get_font('text_smallest'), 4, 50, Color(200, 200, 200))
    DisableClipping(false)
  end
end

function PANEL:OnMousePressed(...)
  self.mouse_pressed = CurTime()
  fl.inventory_drag_slot = self

  self.BaseClass.OnMousePressed(self, ...)
end

function PANEL:OnMouseReleased(...)
  local x, y = self:LocalToScreen(0, 0)
  local w, h = self:GetSize()

  if surface.mouse_in_rect(x, y, w, h) then
    if self.item_data and self.mouse_pressed and self.mouse_pressed > (CurTime() - 0.15) then
      fl.inventory_drag_slot = nil

      if #self.instance_ids > 1 then
        hook.run('PlayerUseItemMenu', self.instance_ids)
      else
        hook.run('PlayerUseItemMenu', self.item_data)
      end
    end
  end

  self.BaseClass.OnMouseReleased(self, ...)
end

function PANEL:set_item(instance_id)
  if istable(instance_id) then
    if #instance_id > 1 then
      self:set_item_multi(instance_id)

      return
    else
      return self:set_item(instance_id[1])
    end
  end

  if isnumber(instance_id) then
    self.item_data = item.find_instance_by_id(instance_id)

    if self.item_data then
      self.item_count = 1
      self.instance_ids = { instance_id }
    end

    self:rebuild()
  end
end

function PANEL:set_item_multi(ids)
  local item_data = item.find_instance_by_id(ids[1])

  if item_data and !item_data.stackable then return end

  self.item_data = item_data
  self.item_count = #ids
  self.instance_ids = ids
  self:rebuild()
end

function PANEL:combine(panel2)
  for i = 1, #panel2.instance_ids do
    if #self.instance_ids < self.item_data.max_stack then
      table.insert(self.instance_ids, panel2.instance_ids[1])
      table.remove(panel2.instance_ids, 1)
    end
  end

  self.item_count = #self.instance_ids
  self:rebuild()

  panel2.item_count = #panel2.instance_ids

  if panel2.item_count > 0 then
    panel2:rebuild()
  else
    panel2:reset()
  end
end

function PANEL:reset()
  self.item_data = nil
  self.item_count = 0

  self:rebuild()
  self:undraggable()
end

function PANEL:rebuild()
  if !self.item_data then
    if IsValid(self.spawn_icon) then
      self.spawn_icon:safe_remove()
    end

    self:undraggable()

    return
  else
    self:Droppable('fl_item')
  end

  if IsValid(self.spawn_icon) then
    self.spawn_icon:SetVisible(false)
    self.spawn_icon:Remove()
  end

  self.spawn_icon = vgui.Create('SpawnIcon', self)
  self.spawn_icon:SetPos(2, 2)
  self.spawn_icon:SetSize(60, 60)
  self.spawn_icon:SetModel(self.item_data.model, self.item_data.skin)
  self.spawn_icon:SetMouseInputEnabled(false)
end

vgui.Register('fl_inventory_item', PANEL, 'DPanel')

local PANEL = {}
PANEL.inventory = {}
PANEL.slots = {}
PANEL.inventory_slots = 8
PANEL.inventory_type = 'inventory'
PANEL.player = nil

function PANEL:set_inventory(inv)
  self.inventory = inv
end

function PANEL:set_player(player)
  self.player = player
  self:set_inventory(player:get_inventory(self.inventory_type))

  self:rebuild()
end

function PANEL:set_slots(num)
  self.inventory_slots = num

  self:rebuild()
end

function PANEL:slots_to_inventory()
  for k, v in ipairs(self.slots) do
    if v.slot_num and v.item_data and #v.instance_ids > 0 then
      self.inventory[v.slot_num] = v.instance_ids
    else
      self.inventory[v.slot_num] = {}
    end
  end

  cable.send('fl_inventory_sync', self.inventory)
end

function PANEL:get_menu_size()
  return font.scale(560), font.scale(self.inventory_slots * 0.125 * 68 + 36)
end

function PANEL:rebuild()
  dragndrop.Clear()

  local multiplier = self.inventory_slots / 8

  self:SetSize(560, multiplier * 68 + 36)

  if IsValid(self.player) then
    self:set_inventory(self.player:get_inventory(self.inventory_type))
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
    local inv_slot = self.list:Add('fl_inventory_item')
    inv_slot:SetSize(64, 64)
    inv_slot.slot_num = i

    if self.draw_inventory_slots then
      inv_slot.slot_number = i
    end

    if self.inventory[i] and #self.inventory[i] > 0 then
      if #self.inventory[i] > 1 then
        inv_slot:set_item_multi(self.inventory[i])
      else
        inv_slot:set_item(self.inventory[i][1])
      end
    end

    inv_slot:Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
      if is_dropped then
        fl.inventory_drag_slot = nil

        if receiver.item_data then
          if (receiver.item_data.id == dropped[1].item_data.id and
            receiver.slot_num != dropped[1].slot_num and receiver.item_data.stackable) then
            receiver:combine(dropped[1])
            self:slots_to_inventory()

            return
          else
            receiver.is_hovered = false

            return
          end
        end

        local split = false

        if input.IsKeyDown(KEY_LCONTROL) and dropped[1].item_count > 1 then
          split = {{}, {}}

          for i2 = 1, dropped[1].item_count do
            if i2 <= math.floor(dropped[1].item_count * 0.5) then
              table.insert(split[1], dropped[1].instance_ids[i2])
            else
              table.insert(split[2], dropped[1].instance_ids[i2])
            end
          end
        end

        if !split then
          receiver:set_item(dropped[1].instance_ids)
        else
          receiver:set_item_multi(split[1])
          dropped[1]:set_item_multi(split[2])
        end

        receiver.is_hovered = false

        if !split then
          dropped[1]:reset()
        else
          dropped[1]:rebuild()
        end

        self:slots_to_inventory()
      else
        receiver.is_hovered = true
      end
    end, { 'Place' })

    self.slots[i] = inv_slot
  end

  self:GetParent():Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
    if is_dropped then
      hook.run('PlayerDropItem', dropped[1].item_data, dropped[1], mouse_x, mouse_y)
    end
  end, {})
end

vgui.Register('fl_inventory', PANEL, 'fl_base_panel')

local PANEL = {}

function PANEL:Paint(w, h)
  draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 150))
end

function PANEL:get_menu_size()
  return ScrW() / 1.5, ScrH() / 1.5
end

function PANEL:on_close()
  self.hotbar:AlphaTo(0, theme.get_option('menu_anim_duration'), 0)
end

function PANEL:on_change()
  self.hotbar:safe_remove()
end

function PANEL:rebuild()
  if IsValid(self.inventory) or IsValid(self.hotbar) then
    self.inventory:rebuild()
    self.hotbar:rebuild()

    return
  end

  self.inventory = vgui.create('fl_inventory', self)
  self.inventory:set_player(fl.client)

  local w, h = self:GetSize()
  local width, height = self.inventory:GetSize()

  if width < w / 2 then
    local x, y = self.inventory:GetPos()

    self.inventory:SetPos(w / 2 - width - 2, y)
  end

  if height < h then
    local x, y = self.inventory:GetPos()

    self.inventory:SetPos(x, h / 2 - height / 2)
  end

  self.hotbar = vgui.Create('fl_hotbar', self:GetParent())
  self.hotbar:set_slot_padding(8)
  self.hotbar:set_player(fl.client)
  self.hotbar:rebuild()
end

vgui.Register('fl_inventory_menu', PANEL, 'fl_base_panel')
