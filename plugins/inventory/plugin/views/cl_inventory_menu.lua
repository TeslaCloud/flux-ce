local PANEL = {}

function PANEL:Paint(w, h)
  Theme.hook('PaintTabInventoryBackground', self, w, h)
end

function PANEL:PerformLayout(w, h)

end

function PANEL:get_menu_size()
  return ScrW() * 0.66, ScrH() * 0.66
end

function PANEL:on_close()
  if IsValid(self.player_model) then
    self.player_model:safe_remove()
  end

  if IsValid(self.hotbar) then
    self.hotbar:safe_remove()
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
  self.player_model:SetFOV(47)
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

        if item_table.equip_slot and !item_table:is_equipped() then
          item_table:do_menu_action('on_use')
        end
      end
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

  self.equipment = PLAYER:get_inventory('equipment'):create_panel(self)
  self.equipment:set_slot_size(math.scale(80))
  self.equipment:set_slot_padding(math.scale(4))
  self.equipment:set_title('ui.inventory.equipment')
  self.equipment:SizeToContents()
  self.equipment:SetPos(w - self.equipment:GetWide(), h * 0.5 - self.equipment:GetTall() * 0.5)

  self.player_model:SetSize(w * 0.5 - self.equipment:GetWide(), h)
  self.player_model:SetPos(w - self.player_model:GetWide() - self.equipment:GetWide() - math.scale(8))

  self.main_inventory = PLAYER:get_inventory('main_inventory'):create_panel(self)
  self.main_inventory:set_title('ui.inventory.main_inventory')
  self.main_inventory:SizeToContents()

  self.pockets = PLAYER:get_inventory('pockets'):create_panel(self)
  self.pockets:set_slot_size(math.scale(48))
  self.pockets:set_title('ui.inventory.pockets')
  self.pockets:SizeToContents()

  local title_w, title_h = util.text_size(self.pockets.title, Theme.get_font('text_normal_large'))
  local x = self.player_model.x - self.main_inventory:GetWide() - math.scale(8)
  local y = h * 0.5 - self.main_inventory:GetTall() * 0.5 - self.pockets:GetTall() * 0.5 - title_h * 0.5

  self.main_inventory:SetPos(x, y)
  self.pockets:SetPos(x, y + self.main_inventory:GetTall() + title_h + math.scale(16))

  self.hotbar = PLAYER:get_inventory('hotbar'):create_panel(self:GetParent())
  self.hotbar:set_slot_size(math.scale(80))
  self.hotbar:set_slot_padding(math.scale(8))
  self.hotbar:draw_inventory_slots(true)
  self.hotbar:set_title('ui.inventory.hotbar')
  self.hotbar:SizeToContents()
  self.hotbar:SetPos(ScrW() * 0.5 - self.hotbar:GetWide() * 0.5, ScrH() - self.hotbar:GetTall() - math.scale(16))
end

vgui.Register('fl_inventory_menu', PANEL, 'fl_base_panel')
