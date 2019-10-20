local PANEL = {}
PANEL.item_data = nil
PANEL.item_count = 0
PANEL.instance_ids = {}
PANEL.slot_number = nil
PANEL.icon = nil
PANEL.icon_material = nil
PANEL.rotated = false

function PANEL:Paint(w, h)
  local draw_color = Color(30, 30, 30, 100)
  local drop_slot = Flux.inventory_drop_slot

  if IsValid(drop_slot) and drop_slot:get_inventory_id() == self:get_inventory_id() then
    local drag_slot = Flux.inventory_drag_slot
    
    if IsValid(drag_slot) then
      local slot_w, slot_h = drag_slot:get_item_size()
      local drop_x, drop_y = drop_slot:get_item_pos()
      local x, y = self:get_item_pos()

      if self.is_hovered or self:is_multislot() and drop_x <= x and drop_y <= y
      and drop_x + slot_w > x and drop_y + slot_h > y then
        local item_obj = self.item_data

        if item_obj then
          if drag_slot.item_data != item_obj then
            local slot_data = drag_slot.item_data

            if slot_data.id == item_obj.id and slot_data.stackable
            and drag_slot.item_count < slot_data.max_stack
            and drop_slot.item_count < slot_data.max_stack then
              draw_color = Color(200, 200, 60)
            else
              draw_color = Color(200, 60, 60, 160)
            end
          else
            draw_color = draw_color:lighten(30)
          end
        else
          if drop_slot.out_of_bounds or drop_slot.disabled then
            draw_color = Color(200, 60, 60, 160)
          else
            draw_color = Color(60, 200, 60, 160)
          end
        end
      end
    end
  else
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
  end

  if self.disabled then
    self.icon = 'fa-times'
  end

  if !self:IsDragging() and self.item_data and self.item_data.background_color then
    draw.RoundedBox(0, 0, 0, w, h, self.item_data.background_color:alpha(100))
  end

  if self.icon and !self:IsDragging() then
    local icon = self.icon
    local icon_size = h * 0.75

    if icon:starts('fa') then
      local icon_text = FontAwesome:get(icon)
      local icon_w, icon_h = util.text_size(icon_text, Font.size('flFontAwesome', icon_size))

      FontAwesome:draw(icon, w * 0.5 - icon_w * 0.5, h * 0.5 - icon_h * 0.5, icon_size, Color(255, 255, 255, 100))
    else
      self.icon_material = self.icon_material or Material(self.icon, 'smooth')

      surface.SetDrawColor(Color(255, 255, 255, 100))
      surface.SetMaterial(self.icon_material)
      surface.DrawTexturedRect(w * 0.5 - icon_size * 0.5, h * 0.5 - icon_size * 0.5, icon_size, icon_size)
    end
  end

  draw.RoundedBox(0, 0, 0, w, h, draw_color)

  Theme.hook('PaintItemSlot', self, w, h)

  if self.item_data and self.item_data.paint_slot then
    self.item_data:paint_slot(w, h)
  end
end

function PANEL:PaintOver(w, h)
  if self.item_count >= 2 then
    DisableClipping(true)
      draw.SimpleText(self.item_count, Theme.get_font('text_smallest'), w - math.scale(12), h - math.scale(14), Color(225, 225, 225))
    DisableClipping(false)
  end

  if !self:IsDragging() then
    if isnumber(self.slot_number) then
      DisableClipping(true)
        draw.SimpleText(self.slot_number, Theme.get_font('text_smallest'), math.scale(4), h - math.scale(14), Color(175, 175, 175))
      DisableClipping(false)
    end
  end

  Theme.hook('PaintOverItemSlot', self, w, h)

  if self.item_data and self.item_data.paint_over_slot then
    self.item_data:paint_over_slot(w, h)
  end
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
      self.rotated = self.item_data.rotated
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
  self.rotated = item_data.rotated
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
  self.rotated = false

  self:rebuild()
  self:undraggable()
end

function PANEL:rebuild()
  if !self.item_data then
    self:undraggable()

    return
  else
    self:Droppable('fl_item')
  end

  local icon = self.item_data:get_icon_material()

  if icon then
    if IsValid(self.icon_panel) then
      self.icon_panel:safe_remove()
    end

    icon = Material(icon)

    local rotated = self:is_rotated()

    self.icon_panel = vgui.Create('fl_base_panel', self)
    self.icon_panel:Dock(FILL)
    self.icon_panel:SetMouseInputEnabled(false)
    self.icon_panel.Paint = function(pnl, w, h)
      surface.SetDrawColor(255, 255, 255, 255)
      surface.SetMaterial(icon)
      surface.DrawTexturedRectRotated(w * 0.5, h * 0.5, rotated and h or w, rotated and w or h, rotated and 90 or 0)
    end

    if self.item_data.adjust_icon_panel then
      self.item_data.adjust_icon_panel(self.icon_panel, self)
    end
  else
    if IsValid(self.model_panel) then
      self.model_panel:safe_remove()
    end

    local model = self.item_data:get_icon_model() or self.item_data:get_model()

    self.model_panel = vgui.Create('DModelPanel', self)
    self.model_panel:Dock(FILL)
    self.model_panel:SetModel(model, self.item_data:get_skin())
    self.model_panel:SetMouseInputEnabled(false)
    self.model_panel:SetAnimated(true)
    self.model_panel.LayoutEntity = function(pnl, ent)
    end

    local entity = self.model_panel:GetEntity()
    local cam_data = table.copy(self.item_data:get_icon_data())

    entity:SetSequence(entity:idle_animation())

    if !cam_data then
      cam_data = PositionSpawnIcon(entity, entity:GetPos(), true)
      cam_data.fov = cam_data.fov * 1.1
    end

    local pos, ang, fov = cam_data.origin, cam_data.angles, cam_data.fov
    local rotated = self:is_rotated()
    local w, h = self:get_item_size()

    self.model_panel:SetCamPos(pos)
    self.model_panel:SetFOV(rotated and fov * (w / h) or fov)
    self.model_panel:SetLookAng(rotated and Angle(ang.p, ang.y, ang.r - 90) or ang)

    if self.item_data.adjust_model_panel then
      self.item_data:adjust_model_panel(self.model_panel, self)
    end
  end

  self:SetToolTip(t(self.item_data:get_name())..'\n'..t(self.item_data:get_description()))
end

function PANEL:get_item_size()
  if self.item_data then
    if !self:is_rotated() then
      return self.item_data.width, self.item_data.height
    else
      return self.item_data.height, self.item_data.width
    end
  end

  return 1, 1
end

function PANEL:get_item_pos()
  return self.slot_x, self.slot_y
end

function PANEL:get_inventory_id()
  return self.inventory_id
end

function PANEL:is_multislot()
  return self.multislot
end

function PANEL:turn()
  local w, h = self:GetSize()
  self:SetWidth(h)
  self:SetHeight(w)
  self.rotated = !self.rotated
  self:rebuild()
end

function PANEL:is_rotated()
  return self.rotated
end

function PANEL:was_rotated()
  return self.rotated != self.item_data.rotated
end

vgui.Register('fl_inventory_item', PANEL, 'DPanel')
