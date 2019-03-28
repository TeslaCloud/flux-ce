local PANEL = {}
PANEL.item_data = nil
PANEL.item_count = 0
PANEL.instance_ids = {}
PANEL.is_hovered = false
PANEL.slot_number = nil

function PANEL:Paint(w, h)
  local draw_color = Color(30, 30, 30, 100)

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
    local cur_slot = Flux.inventory_drag_slot

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

  Theme.hook('PaintItemSlot', self, w, h)
end

function PANEL:PaintOver(w, h)
  if self.item_count >= 2 then
    DisableClipping(true)
      draw.SimpleText(self.item_count, Theme.get_font('text_smallest'), 52, 50, Color(225, 225, 225))
    DisableClipping(false)
  end

  if !self:IsDragging() then
    if isnumber(self.slot_number) then
      DisableClipping(true)
        draw.SimpleText(self.slot_number, Theme.get_font('text_smallest'), 4, 50, Color(175, 175, 175))
      DisableClipping(false)
    end
  end

  Theme.hook('PaintOverItemSlot', self, w, h)
end

function PANEL:OnMousePressed(...)
  self.mouse_pressed = CurTime()
  Flux.inventory_drag_slot = self

  self.BaseClass.OnMousePressed(self, ...)
end

function PANEL:OnMouseReleased(...)
  local x, y = self:LocalToScreen(0, 0)
  local w, h = self:GetSize()

  if surface.mouse_in_rect(x, y, w, h) then
    if self.item_data and self.mouse_pressed and self.mouse_pressed > (CurTime() - 0.15) then
      Flux.inventory_drag_slot = nil

      hook.run('PlayerUseItemMenu', self.instance_ids[#self.instance_ids])
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
    self.item_data = Item.find_instance_by_id(instance_id)

    if self.item_data then
      self.item_count = 1
      self.instance_ids = { instance_id }
    end

    self:rebuild()
  end
end

function PANEL:set_item_multi(ids)
  local item_data = Item.find_instance_by_id(ids[1])

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
  self.instance_ids = {}
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
  self.spawn_icon:SetModel(self.item_data:get_icon_model() or self.item_data:get_model(), self.item_data.skin)
  self.spawn_icon:SetMouseInputEnabled(false)
end

function PANEL:get_inventory_panel()
  return self.inventory
end

function PANEL:set_inventory_panel(panel)
  self.inventory = panel
end

vgui.Register('fl_inventory_item', PANEL, 'DPanel')
