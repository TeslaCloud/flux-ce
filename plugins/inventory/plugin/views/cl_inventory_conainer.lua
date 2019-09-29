local PANEL = {}
PANEL.title = 'ui.inventory.container'

function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  self:SetSize(scrw, scrh)
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

  self.main_inventory = PLAYER:get_inventory('main_inventory'):create_panel(self)
  self.main_inventory:set_title('ui.inventory.main_inventory')
  self.main_inventory:SizeToContents()
  self.main_inventory:rebuild()

  self.pockets = PLAYER:get_inventory('pockets'):create_panel(self)
  self.pockets:set_slot_size(math.scale(48))
  self.pockets:set_title('ui.inventory.pockets')
  self.pockets:SizeToContents()

  local title_w, title_h = util.text_size(self.pockets.title, Theme.get_font('text_normal_large'))
  local x = scrw * 0.5 - self.main_inventory:GetWide() - math.scale(8)
  local y = scrh * 0.5 - self.main_inventory:GetTall() * 0.5 - self.pockets:GetTall() * 0.5 - title_h * 0.5

  self.main_inventory:SetPos(x, y)
  self.pockets:SetPos(x, y + self.main_inventory:GetTall() + title_h + math.scale(16))
  self.pockets:rebuild()

  self.hotbar = PLAYER:get_inventory('hotbar'):create_panel(self)
  self.hotbar:set_slot_size(math.scale(80))
  self.hotbar:set_slot_padding(math.scale(8))
  self.hotbar:draw_inventory_slots(true)
  self.hotbar:set_title('ui.inventory.hotbar')
  self.hotbar:SizeToContents()
  self.hotbar:SetPos(ScrW() * 0.5 - self.hotbar:GetWide() * 0.5, ScrH() - self.hotbar:GetTall() - math.scale(16))
  self.hotbar:rebuild()

  draw.set_blur_size(6)
  Flux.blur_update_fps = 0
end

function PANEL:Paint(w, h)
  draw.blur_panel(self)

  Theme.hook('PaintInventoryContainerBackground', self, w, h)
end

function PANEL:OnRemove()
  if IsValid(self.hotbar) then
    self.hotbar:safe_remove()
  end

  Flux.blur_update_fps = 8

  Cable.send('fl_inventory_close', self:get_inventory_id())
end

function PANEL:OnKeyCodePressed(key)
  if key == KEY_TAB or key == KEY_E then
    self:safe_remove()
  end
end

function PANEL:open_inventory(inventory_id)
  local inventory = Inventories.find(inventory_id)

  self.inventory = inventory:create_panel(self)
  self.inventory:set_title(inventory.title)
  self.inventory:SizeToContents()
  self.inventory:SetPos(ScrW() * 0.5, ScrH() * 0.5 - self.inventory:GetTall() * 0.5)

  self.inventory_id = inventory_id
end

function PANEL:get_inventory_id()
  return self.inventory_id
end

vgui.Register('fl_inventory_container', PANEL, 'fl_base_panel')
