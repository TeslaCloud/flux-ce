--- The `fl_inventory_menu` panel is the inventory tab of the tab menu.
-- It shows the main inventory and the pockets of the local player, the equipment slots
-- around a preview of their model, a field for editing the description of the character,
-- and the hotbar at the bottom of the screen, onto which items of the main inventory and the
-- pockets are dragged or put with the number keys. Dropping an equipable item onto the model
-- equips it. An item or an entry of the hotbar dropped onto the bare background of the tab has
-- its item dropped into the world (see `lib/cl_hotbar_input.lua`).

local math_scale = math.scale
local math_scale_x = math.scale_x

local PANEL = {}

--- Makes the bare background of the tab drop the item of an entry of the hotbar into the
-- world. The inventory panels make it drop their items.
function PANEL:Init()
  self:Receiver('fl_hotbar', Hotbar.receive_entry_in_world)
end

--- Draws the background of the inventory tab using the theme.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  Theme.hook('PaintTabInventoryBackground', self, w, h)
end

--- Returns the size that the tab menu gives to the panel.
-- @return [Number width, Number height]
function PANEL:get_menu_size()
  return ScrW() * 0.66, ScrH() * 0.66
end

--- Called by the tab menu when it closes. Removes the player model and fades the hotbar out.
function PANEL:on_close()
  if IsValid(self.player_model) then
    self.player_model:safe_remove()
  end

  if IsValid(self.hotbar) then
    self.hotbar:AlphaTo(0, Theme.get_option('menu_anim_duration'), 0, function()
      self.hotbar:safe_remove()
    end)
  end
end

--- Called by the tab menu when it switches to another panel. Removes the hotbar.
function PANEL:on_change()
  if IsValid(self.hotbar) then
    self.hotbar:safe_remove()
  end
end

--- Called by the tab menu when the panel opens. Creates the player model with the description
-- editor, the equipment slots, the main inventory, the pockets and the hotbar.
function PANEL:rebuild()
  local w, h = self:GetSize()
  local model_padding = math_scale(4)

  self.player_model = vgui.Create('DModelPanel', self)
  self.player_model:DockPadding(model_padding, model_padding, model_padding, model_padding)
  self.player_model:SetFOV(35)
  self.player_model:SetCamPos(Vector(80, 0, 50))
  self.player_model:SetLookAt(Vector(0, 0, 37))
  self.player_model:SetAnimated(true)
  self.player_model.angles = Angle(0, 0, 0)

  self.player_model.DragMousePress = function(pnl)
    pnl.press_x, pnl.press_y = gui.MousePos()
    pnl.pressed = true
  end

  self.player_model.DragMouseRelease = function(pnl)
    pnl.pressed = false
  end

  self.player_model.LayoutEntity = function(pnl, ent)
    if pnl.pressed then
      local mx, my = gui.MousePos()

      pnl.angles -= Angle(0, (pnl.press_x or mx) - mx, 0)
      pnl.press_x, pnl.press_y = mx, my
    end

    ent:SetAngles(pnl.angles)
  end

  self.player_model.rebuild = function(pnl)
    pnl:SetModel(PLAYER:GetModel())

    local ent = pnl:GetEntity()
    ent:SetSequence(ent:idle_animation())
    ent:SetSkin(PLAYER:GetSkin())
    ent:SetColor(PLAYER:GetColor())
    ent:SetMaterial(PLAYER:GetMaterial())
    ent:set_bodygroups(PLAYER:bodygroups())
  end

  self.player_model:rebuild()

  self.player_model:Receiver('fl_item', function(_receiver, dropped_panels, is_dropped, _menu_index, _mouse_x, _mouse_y)
    local dropped = dropped_panels[1]

    if is_dropped then
      if dropped.item_data then
        local item_obj = dropped.item_data

        if !item_obj:is_equipped() then
          item_obj:do_menu_action('on_equip')
        end

        Inventories.find(dropped:get_inventory_id()).panel:rebuild()
      end
    else
      Flux.inventory_drop_slot = nil
    end
  end)

  self.desc = vgui.Create('fl_text_entry', self.player_model)
  self.desc:Dock(BOTTOM)
  self.desc:SetText(PLAYER:get_phys_desc())
  self.desc:SetFont(Theme.get_font('main_menu_normal'))
  self.desc:set_limit(Config.get('characters_max_desc_len'))
  self.desc.is_applied = function(pnl)
    local text = pnl:GetValue()

    if text != pnl.checked_text then
      pnl.checked_text = text
      pnl.normalized_text = Characters.normalize_desc(text)
    end

    return pnl.normalized_text == PLAYER:get_phys_desc()
  end

  self.desc.save = function(pnl)
    if pnl:is_applied() then
      return false
    end

    Cable.send('fl_character_physdesc', pnl:GetValue())

    return true
  end

  self.desc:SetFont(Theme.get_font('main_menu_small'))
  self.desc:SetTall(math_scale(36))
  self.desc.Paint = function(pnl, desc_w, desc_h)
    local radius = Theme.get_option('corner_radius_small', math_scale(4))
    local text_color = Theme.get_color('text')
    local border

    if pnl:HasFocus() then
      border = Theme.get_color('accent')
    else
      border = Theme.get_color(pnl:is_applied() ? 'success' : 'warning')
    end

    Theme.hook('PaintCard', 0, 0, desc_w, desc_h, radius, Theme.get_color('field'), border)

    pnl:DrawTextEntryText(text_color, ColorAlpha(Theme.get_color('accent'), 120), text_color)
  end

  self.desc.OnEnter = function(pnl)
    local err = !pnl:save()

    surface.PlaySound(err ? 'buttons/button10.wav' : 'buttons/button14.wav')
  end

  self.player_model:SetSize(w * 0.3, h)

  self.equipment_right = vgui.Create('DIconLayout', self)
  self.equipment_right:SetSpaceY(math_scale(12))
  self.equipment_right:SetSize(math_scale_x(100), h)
  self.equipment_right:SetPos(w - self.equipment_right:GetWide())

  self.player_model:SetPos(w - self.player_model:GetWide() - self.equipment_right:GetWide() - math_scale_x(12))

  self.equipment_left = vgui.Create('DIconLayout', self)
  self.equipment_left:SetSpaceY(math_scale(12))
  self.equipment_left:SetSize(math_scale_x(100), h)
  self.equipment_left:SetPos(self.player_model.x - self.equipment_left:GetWide() - math_scale_x(12))

  self:add_equipment_slot(self.equipment_right, 'equipment_helmet')
  self:add_equipment_slot(self.equipment_right, 'equipment_mask')
  self:add_equipment_slot(self.equipment_right, 'equipment_torso')
  self:add_equipment_slot(self.equipment_right, 'equipment_hands')
  self:add_equipment_slot(self.equipment_right, 'equipment_legs')
  self:add_equipment_slot(self.equipment_left, 'equipment_back')
  self:add_equipment_slot(self.equipment_left, 'equipment_accessories', math_scale(12))

  self.equipment_right:InvalidateLayout(true)
  self.equipment_right:SizeToContents()
  self.equipment_right:SetPos(self.equipment_right.x, h * 0.5 - self.equipment_right:GetTall() * 0.5)

  self.equipment_left:InvalidateLayout(true)
  self.equipment_left:SizeToContents()
  self.equipment_left:SetPos(self.equipment_left.x, h * 0.5 - self.equipment_left:GetTall() * 0.5)

  self:create_storage(h)

  self.hotbar = Hotbar.create_panel(self:GetParent())
  self.hotbar:set_title('ui.hotbar.title')
end

--- Adds the panel of one of the local player's equipment inventories to a column of the
-- equipment slots and keeps it in the field of the panel named after the inventory type.
-- Does nothing if the player has no such inventory.
-- @param layout [Panel the DIconLayout of the column]
-- @param inv_type [String type of the equipment inventory]
-- @param slot_padding=nil [Number space between the slots of the inventory]
function PANEL:add_equipment_slot(layout, inv_type, slot_padding)
  local inventory = PLAYER:get_inventory(inv_type)

  if !inventory then return end

  local panel = inventory:create_panel(self)
  panel:set_slot_size(math_scale(100))

  if slot_padding then
    panel:set_slot_padding(slot_padding)
  end

  panel:set_title()
  panel:SizeToContents()
  panel:rebuild()

  layout:Add(panel)

  self[inv_type] = panel
end

--- Creates the panels of the local player's main inventory and pockets, to the left of the
-- equipment slots, the pockets below the main inventory. Either is left out if the player
-- does not have it.
-- @param h [Number height of the panel]
function PANEL:create_storage(h)
  local main_inventory = PLAYER:get_inventory('main_inventory')
  local pockets = PLAYER:get_inventory('pockets')
  local main_w, main_h, pockets_h, title_h = 0, 0, 0, 0

  if main_inventory then
    self.main_inventory = main_inventory:create_panel(self)
    self.main_inventory:SizeToContents()
    self.main_inventory:rebuild()

    main_w, main_h = self.main_inventory:GetSize()
  end

  if pockets then
    self.pockets = pockets:create_panel(self)
    self.pockets:set_slot_size(math_scale(48))
    self.pockets:SizeToContents()

    title_h = select(2, util.text_size(self.pockets.title, Theme.get_font('text_normal_large')))
    pockets_h = self.pockets:GetTall()
  end

  local x = self.equipment_left.x - main_w - math_scale(12)
  local y = h * 0.5 - main_h * 0.5 - pockets_h * 0.5 - title_h * 0.5

  if IsValid(self.main_inventory) then
    self.main_inventory:SetPos(x, y)
  end

  if IsValid(self.pockets) then
    self.pockets:SetPos(x, y + main_h + title_h + math_scale(16))
    self.pockets:rebuild()
  end
end

vgui.Register('fl_inventory_menu', PANEL, 'fl_base_panel')
