--- The `fl_inventory_item` panel is a single slot of an `fl_inventory` panel.
-- It displays the item or the stack of items in the slot as a model or an icon, can be
-- dragged onto other slots and opens the menu of the item when it is clicked. An item
-- can draw on its slot with its `paint_slot` and `paint_over_slot` callbacks and adjust
-- the model view with `adjust_model_panel`.

local IsValid = IsValid
local isnumber = isnumber
local math_scale = math.scale
local draw_simple_text = draw.SimpleText
local surface_set_draw_color = surface.SetDrawColor
local surface_draw_rect = surface.DrawRect
local surface_draw_outlined_rect = surface.DrawOutlinedRect

local slot_color = Color(30, 30, 30, 100)
local slot_color_empty = slot_color:darken(25)
local slot_color_same = slot_color:lighten(30)
local slot_color_stack = Color(200, 200, 60)
local slot_color_valid = Color(60, 200, 60, 160)
local slot_color_invalid = Color(200, 60, 60, 160)
local slot_icon_color = Color(255, 255, 255, 100)
local slot_count_color = Color(225, 225, 225)
local slot_number_color = Color(175, 175, 175)
local faded_backgrounds = setmetatable({}, { __mode = 'k' })

local PANEL = {}
PANEL.item_data = nil
PANEL.item_count = 0
PANEL.instance_ids = {}
PANEL.slot_number = nil
PANEL.icon = nil
PANEL.icon_material = nil
PANEL.rotated = false

--- Draws the slot: its background, the drag and drop highlight and the slot icon.
-- Calls the paint_slot callback of the item afterward.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  local draw_color = slot_color
  local item_obj = self.item_data
  local drop_slot = Flux.inventory_drop_slot

  if IsValid(drop_slot) and drop_slot:get_inventory_id() == self:get_inventory_id() then
    local drag_slot = Flux.inventory_drag_slot

    if IsValid(drag_slot) then
      local slot_w, slot_h = drag_slot:get_item_size()
      local drop_x, drop_y = drop_slot:get_item_pos()
      local x, y = self:get_item_pos()

      if self.is_hovered or self:is_multislot() and drop_x <= x and drop_y <= y
      and drop_x + slot_w > x and drop_y + slot_h > y then
        if item_obj then
          if drag_slot.item_data != item_obj then
            local slot_data = drag_slot.item_data

            if slot_data.id == item_obj.id and slot_data.stackable
            and drag_slot.item_count < slot_data.max_stack
            and drop_slot.item_count < slot_data.max_stack then
              draw_color = slot_color_stack
            else
              draw_color = slot_color_invalid
            end
          else
            draw_color = slot_color_same
          end
        else
          if drop_slot.out_of_bounds or drop_slot.disabled then
            draw_color = slot_color_invalid
          else
            draw_color = slot_color_valid
          end
        end
      end
    end
  else
    if !item_obj then
      draw_color = slot_color_empty
    else
      if item_obj.special_color then
        surface_set_draw_color(item_obj.special_color)
        surface_draw_outlined_rect(0, 0, w, h)
        surface_draw_outlined_rect(1, 1, w - 2, h - 2)
      end

      if self:IsHovered() then
        surface_set_draw_color(255, 255, 255)
        surface_draw_outlined_rect(1, 1, w - 2, h - 2)
      end
    end
  end

  if self.disabled then
    self.icon = 'fa-times'
  end

  local is_dragging = self:IsDragging()

  if !is_dragging and item_obj and item_obj.background_color then
    local background_color = item_obj.background_color
    local faded_color = faded_backgrounds[background_color]

    if !faded_color then
      faded_color = background_color:alpha(100)
      faded_backgrounds[background_color] = faded_color
    end

    surface_set_draw_color(faded_color.r, faded_color.g, faded_color.b, faded_color.a)
    surface_draw_rect(0, 0, w, h)
  end

  local icon = self.icon

  if icon and !is_dragging then
    local icon_size = h * 0.75

    if icon:start_with('fa') then
      local icon_w, icon_h = FontAwesome:get_icon_size(icon, icon_size)

      FontAwesome:draw(icon, w * 0.5 - icon_w * 0.5, h * 0.5 - icon_h * 0.5, icon_size, slot_icon_color)
    else
      local icon_material = self.icon_material or Material(icon, 'smooth')

      self.icon_material = icon_material

      surface_set_draw_color(slot_icon_color)
      surface.SetMaterial(icon_material)
      surface.DrawTexturedRect(w * 0.5 - icon_size * 0.5, h * 0.5 - icon_size * 0.5, icon_size, icon_size)
    end
  end

  surface_set_draw_color(draw_color.r, draw_color.g, draw_color.b, draw_color.a)
  surface_draw_rect(0, 0, w, h)

  Theme.hook('PaintItemSlot', self, w, h)

  if item_obj and item_obj.paint_slot then
    item_obj:paint_slot(w, h)
  end
end

--- Draws the amount of items in the stack and the number of the slot.
-- Calls the paint_over_slot callback of the item afterward.
-- @param w [Number]
-- @param h [Number]
function PANEL:PaintOver(w, h)
  local item_count = self.item_count

  if item_count >= 2 then
    DisableClipping(true)
      draw_simple_text(
        item_count,
        Theme.get_font('text_smallest'),
        w - math_scale(12),
        h - math_scale(14),
        slot_count_color
      )
    DisableClipping(false)
  end

  local slot_number = self.slot_number

  if !self:IsDragging() and isnumber(slot_number) then
    DisableClipping(true)
      draw_simple_text(
        slot_number,
        Theme.get_font('text_smallest'),
        math_scale(4),
        h - math_scale(14),
        slot_number_color
      )
    DisableClipping(false)
  end

  Theme.hook('PaintOverItemSlot', self, w, h)

  local item_obj = self.item_data

  if item_obj and item_obj.paint_over_slot then
    item_obj:paint_over_slot(w, h)
  end
end

--- Remembers the slot as the one that the item is being dragged from.
-- @param ... [Vararg arguments passed on to the base panel]
function PANEL:OnMousePressed(...)
  self.mouse_pressed = CurTime()
  Flux.inventory_drag_slot = self

  self.BaseClass.OnMousePressed(self, ...)
end

--- Opens the menu of the item if the slot was clicked rather than dragged.
-- @param ... [Vararg arguments passed on to the base panel]
function PANEL:OnMouseReleased(...)
  local x, y = self:LocalToScreen(0, 0)
  local w, h = self:GetSize()

  if surface.mouse_in_rect(x, y, w, h) then
    if self.item_data and self.mouse_pressed and self.mouse_pressed > (CurTime() - 0.15) then
      Flux.inventory_drag_slot = nil

      --- Called on the client when the local player clicks an inventory slot that has an
      -- item in it, to open the menu of the item. The Items plugin handles the hook by
      -- building the menu; it also runs the hook itself, with true as a second argument, for
      -- items that lie in the world.
      -- @param instance_id [Number Instance id of the item; the last one of the stack if the
      --   slot holds several items]
      hook.Run('PlayerUseItemMenu', self.instance_ids[#self.instance_ids])
    end
  end

  self.BaseClass.OnMouseReleased(self, ...)
end

--- Sets the item that the slot displays.
-- @param instance_id [Number/List<Number> instance id, or instance ids of a stack of items]
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

--- Sets the stack of items that the slot displays.
-- Does nothing if the items are not stackable.
-- @param ids [List<Number> instance ids of the items in the stack]
function PANEL:set_item_multi(ids)
  local item_data = Item.find_instance_by_id(ids[1])

  if item_data and !item_data.stackable then return end

  self.item_data = item_data
  self.item_count = #ids
  self.instance_ids = ids
  self.rotated = item_data.rotated
  self:rebuild()
end

--- Moves the items from the stack of another slot to this one, as many as the stack can fit.
-- @param panel2 [Panel the fl_inventory_item panel to take the items from]
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

--- Empties the slot and makes it undraggable.
function PANEL:reset()
  self.instance_ids = {}
  self.item_data = nil
  self.item_count = 0
  self.rotated = false

  self:rebuild()
  self:undraggable()
end

--- Recreates the icon or the model of the item along with its tooltip.
-- Makes the slot draggable only if it has an item.
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
      self.item_data:adjust_icon_panel(self.icon_panel, self)
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
    local cam_data = table.Copy(self.item_data:get_icon_data())

    entity:SetSequence(entity:idle_animation())

    if !cam_data then
      cam_data = PositionSpawnIcon(entity, entity:GetPos(), true)
      cam_data.fov = cam_data.fov * 1.1
    end

    local pos, ang, fov = cam_data.origin, cam_data.angles, cam_data.fov
    local rotated = self:is_rotated()
    local w, h = self:get_item_size()

    if !self:is_multislot() and rotated and w != h then
      fov = fov * (w > h and w / h or h / w)
    end

    self.model_panel:SetCamPos(pos)
    self.model_panel:SetFOV(rotated and fov * (w / h) or fov)
    self.model_panel:SetLookAng(rotated and Angle(ang.p, ang.y, ang.r - 90) or ang)

    if self.item_data.adjust_model_panel then
      self.item_data:adjust_model_panel(self.model_panel, self)
    end
  end

  self:SetToolTip(t(self.item_data:get_name())..'\n'..t(self.item_data:get_description()))
end

--- Returns the size of the item in a number of slots, considering its rotation.
-- @return [Number width, Number height; 1, 1 if the slot is empty]
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

--- Returns the position of the slot in the inventory.
-- @return [Number x, Number y]
function PANEL:get_item_pos()
  return self.slot_x, self.slot_y
end

--- Returns the id of the inventory that the slot belongs to.
-- @return [Number]
function PANEL:get_inventory_id()
  return self.inventory_id
end

--- Checks if the inventory that the slot belongs to is multislot.
-- @return [Boolean]
function PANEL:is_multislot()
  return self.multislot
end

--- Rotates the item in the slot, swapping the width and the height of the panel.
function PANEL:turn()
  local w, h = self:GetSize()
  self:SetWidth(h)
  self:SetHeight(w)
  self.rotated = !self.rotated
  self:rebuild()
end

--- Checks if the item in the slot is displayed rotated.
-- @return [Boolean]
function PANEL:is_rotated()
  return self.rotated
end

--- Checks if the item has been rotated in the panel since it was placed in the inventory.
-- @return [Boolean]
function PANEL:was_rotated()
  return self.rotated != self.item_data.rotated
end

vgui.Register('fl_inventory_item', PANEL, 'DPanel')
