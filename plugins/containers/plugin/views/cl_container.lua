local PANEL = {}

function PANEL:Init()
  self:SetSize(ScrW(), ScrH())
  self:Center()
  self:MakePopup()

  self.button_close = vgui.Create('fl_button', self)
  self.button_close:SetSize(32, 32)
  self.button_close:SetPos(self:GetWide() - self.button_close:GetWide() - 2, 2)
  self.button_close:SetDrawBackground(false)
  self.button_close:set_centered(true)
  self.button_close:set_icon('fa-times')
  self.button_close:set_icon_size(self.button_close:GetSize())
  self.button_close.DoClick = function(btn)
    self:safe_remove()
  end

  draw.set_blur_size(6)
  Flux.blur_update_fps = 0
end

function PANEL:Paint(w, h)
  draw.blur_panel(self)

  Theme.hook('PaintContainerBackground', self, w, h)
end

function PANEL:OnRemove()
  if IsValid(self.hotbar) then
    self.hotbar:safe_remove()
  end

  Flux.blur_update_fps = 8

  Cable.send('fl_container_closed', self:get_target_entity())

  Flux.container = nil
end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_TAB or key == KEY_E then
    self:safe_remove()
  end
end

function PANEL:set_target_entity(entity)
  self.target_entity = entity
end

function PANEL:get_target_entity()
  return self.target_entity
end

function PANEL:rebuild()
  local target_ent = self:get_target_entity()
  local ent_inv = target_ent:get_nv('inventory')

  if IsValid(self.inventory) then
    self.inventory:rebuild()
    self.hotbar:rebuild()
    self.pockets:rebuild()
    self.target_inventory:set_inventory(ent_inv)
    self.target_inventory:rebuild()

    return
  end

  self.inventory = vgui.create('fl_inventory', self)
  self.inventory:set_player(PLAYER)
  self.inventory:set_title('ui.inventory.main_inventory')

  local w, h = self:GetSize()
  local width, height = self.inventory:GetSize()

  self.pockets = vgui.create('fl_inventory', self)
  self.pockets.inventory_type = 'pockets'
  self.pockets:set_max_size(self.inventory:GetWide(), nil)
  self.pockets:set_player(PLAYER)
  self.pockets:set_title('ui.inventory.pockets')

  if width < w / 2 then
    local x, y = self.inventory:GetPos()

    self.inventory:SetPos(w / 2 - width - 8, y)
  end

  local pockets_title_w, pockets_title_h = util.text_size(self.pockets.title, Theme.get_font('text_normal_large'))

  height = height + pockets_title_h + 16

  if height < h then
    local x, y = self.inventory:GetPos()

    self.inventory:SetPos(x, h / 2 - height / 2)
  end

  local x, y = self.inventory:GetPos()

  self.pockets:SetPos(x, y + height)

  self.hotbar = vgui.Create('fl_inventory_hotbar', self)
  self.hotbar:set_slot_padding(8)
  self.hotbar:set_player(PLAYER)
  self.hotbar:set_title('ui.inventory.hotbar')
  self.hotbar:rebuild()

  if IsValid(target_ent) then
    local container_data = Container.all()[target_ent:GetModel()]

    self.target_inventory = vgui.create('fl_inventory', self)
    self.target_inventory.inventory_type = 'container'
    self.target_inventory.entity = self.target_entity
    self.target_inventory:set_inventory(ent_inv)
    self.target_inventory:set_title(t(container_data.name))
    self.target_inventory:rebuild()

    self.target_inventory:SetPos(ScrW() / 2 + 8, ScrH() / 2 - self.target_inventory:GetTall() / 2)
  end
end

vgui.Register('fl_container', PANEL, 'fl_base_panel')
