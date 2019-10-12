local PANEL = {}

function PANEL:Paint(w, h)
  Theme.hook('PaintTabInventoryBackground', self, w, h)
end

function PANEL:get_menu_size()
  return ScrW() * 0.66, ScrH() * 0.66
end

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

function PANEL:on_change()
  if IsValid(self.hotbar) then
    self.hotbar:safe_remove()
  end
end

function PANEL:rebuild()
  local w, h = self:GetSize()

  self.player_model = vgui.Create('DModelPanel', self)
  self.player_model:DockPadding(math.scale(4), math.scale(4), math.scale(4), math.scale(4))
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

      pnl.angles = pnl.angles - Angle(0, (pnl.press_x or mx) - mx, 0)
      pnl.press_x, pnl.press_y = mx, my
    end

    ent:SetAngles(pnl.angles)
  end

  self.player_model.rebuild = function(pnl)
    pnl:SetModel(PLAYER:GetModel())

    local ent = pnl:GetEntity()
    ent:SetSequence(ent:get_idle_anim())
    ent:SetSkin(PLAYER:GetSkin())
    ent:SetColor(PLAYER:GetColor())
    ent:SetMaterial(PLAYER:GetMaterial())
    ent:set_bodygroups(PLAYER:get_bodygroups())
  end

  self.player_model:rebuild()

  self.player_model:Receiver('fl_item', function(receiver, dropped, is_dropped, menu_index, mouse_x, mouse_y)
    local dropped = dropped[1]

    if is_dropped then
      if dropped.item_data then
        local item_table = dropped.item_data

        if item_table:is('equippable') and !item_table:is_equipped() then
          item_table:do_menu_action('on_equip')
        end

        Inventories.find(dropped:get_inventory_id()).panel:rebuild()
      end
    else
      Flux.inventory_drop_slot = nil
    end
  end)

  self.desc = vgui.create('DTextEntry', self.player_model)
  self.desc:Dock(BOTTOM)
  self.desc:SetText(PLAYER:get_phys_desc())
  self.desc:SetFont(Theme.get_font('main_menu_normal'))
  self.desc.saved = true
  self.desc.save = function(pnl)
    local text = pnl:GetValue()

    if text:len() >= Config.get('character_min_desc_len') and text:len() <= Config.get('character_max_desc_len')
    and text != PLAYER:get_phys_desc() then
      Cable.send('fl_character_desc_change', text)
      pnl.saved = true

      return true
    else
      return false
    end
  end

  self.desc.PaintOver = function(pnl, w, h)
    local color = pnl.saved and Color('lightgreen') or Color('orange')

    surface.SetDrawColor(color)
    surface.DrawOutlinedRect(0, 0, w, h)
  end

  self.desc.OnChange = function(pnl, text)
    if text != PLAYER:get_phys_desc() then
      pnl.saved = false
    end
  end

  self.desc.OnEnter = function(pnl)
    local err = !pnl:save()

    surface.PlaySound(err and 'buttons/button10.wav' or 'buttons/button14.wav')
  end

  self.player_model:SetSize(w * 0.3 , h)

  self.equipment_right = vgui.create('DIconLayout', self)
  self.equipment_right:SetSpaceY(math.scale(12))
  self.equipment_right:SetSize(math.scale_x(100), h)
  self.equipment_right:SetPos(w - self.equipment_right:GetWide())

  self.player_model:SetPos(w - self.player_model:GetWide() - self.equipment_right:GetWide() - math.scale_x(12))

  self.equipment_left = vgui.create('DIconLayout', self)
  self.equipment_left:SetSpaceY(math.scale(12))
  self.equipment_left:SetSize(math.scale_x(100), h)
  self.equipment_left:SetPos(self.player_model.x - self.equipment_left:GetWide() - math.scale_x(12))

  self.equipment_helmet = PLAYER:get_inventory('equipment_helmet'):create_panel(self)
  self.equipment_helmet:set_slot_size(math.scale(100))
  self.equipment_helmet:set_title()
  self.equipment_helmet:SizeToContents()
  self.equipment_helmet:rebuild()
  self.equipment_right:Add(self.equipment_helmet)

  self.equipment_mask = PLAYER:get_inventory('equipment_mask'):create_panel(self)
  self.equipment_mask:set_slot_size(math.scale(100))
  self.equipment_mask:set_title()
  self.equipment_mask:SizeToContents()
  self.equipment_mask:rebuild()
  self.equipment_right:Add(self.equipment_mask)

  self.equipment_torso = PLAYER:get_inventory('equipment_torso'):create_panel(self)
  self.equipment_torso:set_slot_size(math.scale(100))
  self.equipment_torso:set_title()
  self.equipment_torso:SizeToContents()
  self.equipment_torso:rebuild()
  self.equipment_right:Add(self.equipment_torso)

  self.equipment_hands = PLAYER:get_inventory('equipment_hands'):create_panel(self)
  self.equipment_hands:set_slot_size(math.scale(100))
  self.equipment_hands:set_title()
  self.equipment_hands:SizeToContents()
  self.equipment_hands:rebuild()
  self.equipment_right:Add(self.equipment_hands)

  self.equipment_legs = PLAYER:get_inventory('equipment_legs'):create_panel(self)
  self.equipment_legs:set_slot_size(math.scale(100))
  self.equipment_legs:set_title()
  self.equipment_legs:SizeToContents()
  self.equipment_legs:rebuild()
  self.equipment_right:Add(self.equipment_legs)

  self.equipment_back = PLAYER:get_inventory('equipment_back'):create_panel(self)
  self.equipment_back:set_slot_size(math.scale(100))
  self.equipment_back:set_title()
  self.equipment_back:SizeToContents()
  self.equipment_back:rebuild()
  self.equipment_left:Add(self.equipment_back)

  self.equipment_accessories = PLAYER:get_inventory('equipment_accessories'):create_panel(self)
  self.equipment_accessories:set_slot_size(math.scale(100))
  self.equipment_accessories:set_slot_padding(math.scale(12))
  self.equipment_accessories:set_title()
  self.equipment_accessories:SizeToContents()
  self.equipment_accessories:rebuild()
  self.equipment_left:Add(self.equipment_accessories)

  self.equipment_right:InvalidateLayout(true)
  self.equipment_right:SizeToContents()
  self.equipment_right:SetPos(self.equipment_right.x, h * 0.5 - self.equipment_right:GetTall() * 0.5)

  self.equipment_left:InvalidateLayout(true)
  self.equipment_left:SizeToContents()
  self.equipment_left:SetPos(self.equipment_left.x, h * 0.5 - self.equipment_left:GetTall() * 0.5)

  self.main_inventory = PLAYER:get_inventory('main_inventory'):create_panel(self)
  self.main_inventory:SizeToContents()
  self.main_inventory:rebuild()

  self.pockets = PLAYER:get_inventory('pockets'):create_panel(self)
  self.pockets:set_slot_size(math.scale(48))
  self.pockets:SizeToContents()

  local title_w, title_h = util.text_size(self.pockets.title, Theme.get_font('text_normal_large'))
  local x = self.equipment_left.x - self.main_inventory:GetWide() - math.scale(12)
  local y = h * 0.5 - self.main_inventory:GetTall() * 0.5 - self.pockets:GetTall() * 0.5 - title_h * 0.5

  self.main_inventory:SetPos(x, y)
  self.pockets:SetPos(x, y + self.main_inventory:GetTall() + title_h + math.scale(16))
  self.pockets:rebuild()

  self.hotbar = PLAYER:get_inventory('hotbar'):create_panel(self:GetParent())
  self.hotbar:set_slot_size(math.scale(80))
  self.hotbar:set_slot_padding(math.scale(8))
  self.hotbar:draw_inventory_slots(true)
  self.hotbar:SizeToContents()
  self.hotbar:SetPos(ScrW() * 0.5 - self.hotbar:GetWide() * 0.5, ScrH() - self.hotbar:GetTall() - math.scale(16))
  self.hotbar:rebuild()
end

vgui.Register('fl_inventory_menu', PANEL, 'fl_base_panel')
