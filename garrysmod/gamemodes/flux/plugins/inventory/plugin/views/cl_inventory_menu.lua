local PANEL = {}

function PANEL:Paint(w, h)
  Theme.hook('PaintTabInventoryBackground', self, w, h)
end

function PANEL:get_menu_size()
  return ScrW() / 1.5, ScrH() / 1.5
end

function PANEL:on_close()
  if IsValid(self.hotbar) then
    self.hotbar:AlphaTo(0, Theme.get_option('menu_anim_duration'), 0)
  end

  if IsValid(self.player_model) then
    self.player_model:safe_remove()
  end
end

function PANEL:on_change()
  self.hotbar:safe_remove()
end

function PANEL:rebuild()
  if IsValid(self.inventory) then
    self.inventory:rebuild()
    self.hotbar:rebuild()
    self.equipment:rebuild()
    self.pockets:rebuild()

    timer.simple(0.05, function()
      if IsValid(self.player_model) then
        self.player_model:rebuild()
      end
    end)

    hook.run('OnInventoryRebuild', self, false)

    return
  end

  self.inventory = vgui.create('fl_inventory', self)
  self.inventory:set_player(PLAYER)
  self.inventory:set_title('inventory.main_inventory')

  local w, h = self:GetSize()
  local width, height = self.inventory:GetSize()

  self.pockets = vgui.create('fl_inventory', self)
  self.pockets.inventory_type = 'pockets'
  self.pockets:set_max_size(self.inventory:GetWide(), nil)
  self.pockets:set_player(PLAYER)
  self.pockets:set_title('inventory.pockets')

  if width < w / 2 then
    local x, y = self.inventory:GetPos()

    self.inventory:SetPos(w / 2 - width - 2, y)
  end

  local pockets_title_w, pockets_title_h = util.text_size(self.pockets.title, Theme.get_font('text_normal_large'))

  height = height + pockets_title_h + 16

  if height < h then
    local x, y = self.inventory:GetPos()

    self.inventory:SetPos(x, h / 2 - height / 2)
  end

  local x, y = self.inventory:GetPos()

  self.pockets:SetPos(x, y + height)

  self.hotbar = vgui.Create('fl_inventory_hotbar', self:GetParent())
  self.hotbar:set_slot_padding(8)
  self.hotbar:set_player(PLAYER)
  self.hotbar:set_title('inventory.hotbar')
  self.hotbar:rebuild()

  self.equipment = vgui.Create('fl_inventory', self)
  self.equipment.inventory_type = 'equipment'
  self.equipment:set_slot_padding(8)
  self.equipment:set_title('inventory.equipment')
  self.equipment:set_player(PLAYER)
  self.equipment:SetPos(w - self.equipment:GetWide(), h / 2 - self.equipment:GetTall() / 2)

  self.player_model = vgui.Create('DModelPanel', self)
  self.player_model:SetPos(w / 2, 0)
  self.player_model:SetSize(w / 2 - self.equipment:GetWide(), h)
  self.player_model:SetFOV(45)
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

  self.desc = vgui.create('DTextEntry', self)
  self.desc:SetSize(self.player_model:GetWide() - 8, Font.scale(24))
  self.desc:SetPos(self.player_model.x + 4, self.player_model.y + self.player_model:GetTall() - self.desc:GetTall() - 4)
  self.desc:SetText(PLAYER:get_phys_desc())
  self.desc:SetFont(Theme.get_font('main_menu_normal'))
  self.desc.OnEnter = function(pnl)
    local text = pnl:GetValue()

    if text:len() >= Config.get('character_min_desc_len') and text:len() <= Config.get('character_max_desc_len') then
      Cable.send('fl_character_desc_change', text)
    end
  end

  hook.run('OnInventoryRebuild', self, true)
end

vgui.Register('fl_inventory_menu', PANEL, 'fl_base_panel')
