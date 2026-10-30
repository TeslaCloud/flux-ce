--- The `fl_inventory_container` panel is a fullscreen view that shows another inventory
-- next to the main inventory, the pockets and the hotbar of the local player, so that
-- items can be dragged between them. A player without a character, such as a gamemaster in
-- gamemaster mode, has no inventories of their own and sees the other inventory alone.
-- The server opens it for a single inventory, such as that of a container, or for all
-- inventories of another player. When it is removed it tells the server that the
-- inventories have been closed.

local math_scale = math.scale
local math_scale_x = math.scale_x
local default_scrim_color = Color(10, 12, 18, 150)

local PANEL = {}
PANEL.title = 'ui.inventory.container'

--- Creates the fullscreen panel with the close button
-- and the local player's main inventory, pockets and hotbar, if they have them.
function PANEL:Init()
  local scrw, scrh = ScrW(), ScrH()

  self:SetSize(scrw, scrh)
  self:Center()
  self:MakePopup()

  local close_size = math_scale(40)
  local close_margin = math_scale(16)

  self.button_close = vgui.Create('fl_button', self)
  self.button_close:SetSize(close_size, close_size)
  self.button_close:SetPos(self:GetWide() - close_size - close_margin, close_margin)
  self.button_close:SetDrawBackground(true)
  self.button_close:set_draw_outline(true)
  self.button_close:set_background_color(Theme.get_color('surface'))
  self.button_close:set_centered(true)
  self.button_close:set_icon('fa-times')
  self.button_close:set_icon_size(math_scale(18))
  self.button_close:SetTooltip(t'ui.close')
  self.button_close.DoClick = function(_btn)
    self:safe_remove()
  end

  local own = PLAYER:get_inventories()

  if own.main_inventory and own.pockets and own.hotbar then
    self:create_own_inventories(own)
  end

  draw.set_blur_size(6)
  Flux.blur_update_fps = 0
end

--- Creates the panels of the local player's main inventory and pockets, at the center of
-- the screen, and of their hotbar at the bottom.
-- @param own [Map the local player's inventories by type]
function PANEL:create_own_inventories(own)
  local scrw, scrh = ScrW(), ScrH()

  self.main_inventory = own.main_inventory:create_panel(self)
  self.main_inventory:set_title('ui.inventory.main_inventory')
  self.main_inventory:SizeToContents()
  self.main_inventory:rebuild()

  self.pockets = own.pockets:create_panel(self)
  self.pockets:set_slot_size(math_scale(48))
  self.pockets:set_title('ui.inventory.pockets')
  self.pockets:SizeToContents()

  local _title_w, title_h = util.text_size(self.pockets.title, Theme.get_font('text_normal_large'))
  local x = scrw * 0.5 - self.main_inventory:GetWide() - math_scale(8)
  local y = scrh * 0.5 - self.main_inventory:GetTall() * 0.5 - self.pockets:GetTall() * 0.5 - title_h * 0.5

  self.main_inventory:SetPos(x, y)
  self.pockets:SetPos(x, y + self.main_inventory:GetTall() + title_h + math_scale(16))
  self.pockets:rebuild()

  self.hotbar = own.hotbar:create_panel(self)
  self.hotbar:set_slot_size(math_scale(80))
  self.hotbar:set_slot_padding(math_scale(8))
  self.hotbar:draw_inventory_slots(true)
  self.hotbar:set_title('ui.inventory.hotbar')
  self.hotbar:SizeToContents()
  self.hotbar:SetPos(ScrW() * 0.5 - self.hotbar:GetWide() * 0.5, ScrH() - self.hotbar:GetTall() - math_scale(16))
  self.hotbar:rebuild()
end

--- Draws the blurred and tinted background of the panel.
-- @param w [Number]
-- @param h [Number]
function PANEL:Paint(w, h)
  draw.blur_panel(self)

  surface.SetDrawColor(Theme.get_color('scrim', default_scrim_color))
  surface.DrawRect(0, 0, w, h)

  Theme.hook('PaintInventoryContainerBackground', self, w, h)
end

--- Removes the hotbar and tells the server that the opened inventories have been closed.
function PANEL:OnRemove()
  if IsValid(self.hotbar) then
    self.hotbar:safe_remove()
  end

  Flux.blur_update_fps = 8

  Cable.send('fl_inventory_close', self:get_inventory_ids())
end

--- Closes the panel when TAB or E is pressed.
-- @param key [Number KEY_ enumerator]
function PANEL:OnKeyCodePressed(key)
  if key == KEY_TAB or key == KEY_E then
    self:safe_remove()
  end
end

--- Shows the specified inventory next to the inventories of the local player, or at the
-- center of the screen if they have none.
-- Runs the 'ContainerOpened' hook afterward.
-- @param inventory_id [Number id of the inventory]
function PANEL:open_inventory(inventory_id)
  local inventory = Inventories.find(inventory_id)

  self.inventory = inventory:create_panel(self)
  self.inventory:set_title(inventory.title)
  self.inventory:SizeToContents()

  local x = (ScrW() - self.inventory:GetWide()) * 0.5

  if IsValid(self.main_inventory) then
    x = ScrW() * 0.5 + math_scale_x(4)
  end

  self.inventory:SetPos(x, ScrH() * 0.5 - self.inventory:GetTall() * 0.5)

  self.inventory_ids = { inventory_id }

  --- Called on the client when an `fl_inventory_container` panel has been set up to show
  -- an inventory next to those of the local player. It is not run when the panel shows
  -- the inventories of another player.
  -- @param panel [Panel The `fl_inventory_container` panel]
  -- @param inventory_id [Number Id of the inventory that has been opened]
  hook.Run('ContainerOpened', self, inventory_id)
end

--- Shows the inventories of another player next to the inventories of the local player, or
-- where those would be if the local player has none.
-- @param owner [Player the player that the inventories belong to]
-- @param inventory_ids [List<Number> ids of the inventories]
function PANEL:open_player_inventories(owner, inventory_ids)
  self.player = owner
  self.container = {}

  self.inventory_ids = inventory_ids

  for _, inventory_id in pairs(inventory_ids) do
    local inventory = Inventories.find(inventory_id)
    local inventory_panel = inventory:create_panel(self)

    self.container[inventory.type] = inventory_panel
  end

  local scrw, scrh = ScrW(), ScrH()
  local main_inventory = self.container.main_inventory
  local pockets = self.container.pockets
  local hotbar = self.container.hotbar

  main_inventory:set_title(self.player:name())
  main_inventory:SizeToContents()

  pockets:set_slot_size(math_scale(48))
  pockets:SizeToContents()

  hotbar:set_slot_size(math_scale(80))
  hotbar:set_slot_padding(math_scale(8))
  hotbar:draw_inventory_slots(true)
  hotbar:set_title('ui.inventory.hotbar')
  hotbar:SizeToContents()

  if IsValid(self.main_inventory) then
    local x = self.main_inventory.x + self.main_inventory:GetWide() + math_scale_x(12)

    main_inventory:SetPos(x, self.main_inventory.y)
    pockets:SetPos(x, self.pockets.y)

    self.hotbar:SetPos(scrw * 0.5 - self.hotbar:GetWide() - math_scale_x(6), self.hotbar.y)
    hotbar:SetPos(scrw * 0.5 + math_scale_x(6), self.hotbar.y)
  else
    local _title_w, title_h = util.text_size(t'ui.inventory.pockets', Theme.get_font('text_normal_large'))
    local x = scrw * 0.5 - main_inventory:GetWide() - math_scale(8)
    local y = scrh * 0.5 - main_inventory:GetTall() * 0.5 - pockets:GetTall() * 0.5 - title_h * 0.5

    main_inventory:SetPos(x, y)
    pockets:SetPos(x, y + main_inventory:GetTall() + title_h + math_scale(16))
    hotbar:SetPos(scrw * 0.5 - hotbar:GetWide() * 0.5, scrh - hotbar:GetTall() - math_scale(16))
  end

  local equipment_left = vgui.Create('DIconLayout', self)
  equipment_left:SetSpaceY(math_scale(12))
  equipment_left:SetSize(math_scale_x(64))
  equipment_left:MoveRightOf(self.container.main_inventory, math_scale_x(12))
  equipment_left:SetPos(equipment_left.x, self.container.main_inventory.y)
  equipment_left.add_slot = function(pnl, id)
    local panel = self.container[id]
    panel:set_title()

    if id == 'equipment_accessories' then
      panel:set_slot_padding(math_scale(12))
    end

    panel:SizeToContents()

    pnl:Add(panel)
  end

  local equipment_right = vgui.Create('DIconLayout', self)
  equipment_right:SetSpaceY(math_scale(12))
  equipment_right:SetSize(math_scale_x(64))
  equipment_right:MoveRightOf(equipment_left, math_scale_x(12))
  equipment_right:SetPos(equipment_right.x, self.container.main_inventory.y)
  equipment_right.add_slot = equipment_left.add_slot

  equipment_left:add_slot('equipment_back')
  equipment_left:add_slot('equipment_accessories')

  equipment_right:add_slot('equipment_helmet')
  equipment_right:add_slot('equipment_mask')
  equipment_right:add_slot('equipment_torso')
  equipment_right:add_slot('equipment_hands')
  equipment_right:add_slot('equipment_legs')

  for _, inventory_panel in pairs(self.container) do
    inventory_panel:rebuild()
  end
end

--- Returns the ids of the inventories that are opened in the panel.
-- @return [List<Number> ids, or nil if nothing has been opened yet]
function PANEL:get_inventory_ids()
  return self.inventory_ids
end

vgui.Register('fl_inventory_container', PANEL, 'fl_base_panel')
