--- The `fl_inventory_container` panel is a fullscreen view that shows another inventory
-- next to the main inventory and the pockets of the local player, so that items can be
-- dragged between them. A player without a character, such as a gamemaster in
-- gamemaster mode, has no inventories of their own and sees the other inventory alone.
-- The server opens it for a single inventory, such as that of a container, or for all
-- inventories of another player. When it is removed it tells the server that the
-- inventories have been closed. It shows no hotbar, but while the cursor is over an item of
-- the main inventory or the pockets of the local player, the number keys put it on the hotbar
-- and the drop key drops one of it into the world (see `lib/cl_hotbar_input.lua`).

local math_scale = math.scale
local math_scale_x = math.scale_x
local default_scrim_color = Color(10, 12, 18, 150)

local PANEL = {}
PANEL.title = 'ui.inventory.container'

--- Creates the fullscreen panel with the close button
-- and the local player's main inventory and pockets, if they have them.
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

  self:create_own_inventories(PLAYER:get_inventories())

  draw.set_blur_size(6)
  Flux.blur_update_fps = 0
end

--- Creates the panels of the local player's main inventory and pockets, at the center of
-- the screen. Those the player does not have are left out.
-- @param own [Map the local player's inventories by type]
function PANEL:create_own_inventories(own)
  local scrw, scrh = ScrW(), ScrH()
  local main_w, main_h, pockets_h, title_h = 0, 0, 0, 0

  if own.main_inventory then
    self.main_inventory = own.main_inventory:create_panel(self)
    self.main_inventory:set_title('ui.inventory.main_inventory')
    self.main_inventory:SizeToContents()
    self.main_inventory:rebuild()

    main_w, main_h = self.main_inventory:GetSize()
  end

  if own.pockets then
    self.pockets = own.pockets:create_panel(self)
    self.pockets:set_slot_size(math_scale(48))
    self.pockets:set_title('ui.inventory.pockets')
    self.pockets:SizeToContents()

    title_h = select(2, util.text_size(self.pockets.title, Theme.get_font('text_normal_large')))
    pockets_h = self.pockets:GetTall()
  end

  local x = scrw * 0.5 - main_w - math_scale(8)
  local y = scrh * 0.5 - main_h * 0.5 - pockets_h * 0.5 - title_h * 0.5

  if IsValid(self.main_inventory) then
    self.main_inventory:SetPos(x, y)
  end

  if IsValid(self.pockets) then
    self.pockets:SetPos(x, y + main_h + title_h + math_scale(16))
    self.pockets:rebuild()
  end
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

--- Tells the server that the opened inventories have been closed.
function PANEL:OnRemove()
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
-- where those would be if the local player has none. Inventories that the other player
-- does not have are left out.
-- @param owner [Player the player that the inventories belong to]
-- @param inventory_ids [List<Number> ids of the inventories]
function PANEL:open_player_inventories(owner, inventory_ids)
  self.player = owner
  self.container = {}

  self.inventory_ids = inventory_ids

  for _, inventory_id in pairs(inventory_ids) do
    local inventory = Inventories.find(inventory_id)

    if inventory then
      self.container[inventory.type] = inventory:create_panel(self)
    end
  end

  local container = self.container

  self:lay_out_player_storage(container.main_inventory, container.pockets)
  self:lay_out_player_equipment(container.main_inventory or container.pockets)

  for _, inventory_panel in pairs(container) do
    inventory_panel:rebuild()
  end
end

--- Sizes and positions the panels of the main inventory and the pockets of another player:
-- next to those of the local player, or at the center of the screen if the local player has
-- none. Either of them may be nil.
-- @param main_inventory [Panel]
-- @param pockets [Panel]
function PANEL:lay_out_player_storage(main_inventory, pockets)
  local scrw, scrh = ScrW(), ScrH()
  local main_w, main_h, pockets_h = 0, 0, 0

  if main_inventory then
    main_inventory:set_title(self.player:name())
    main_inventory:SizeToContents()

    main_w, main_h = main_inventory:GetSize()
  end

  if pockets then
    pockets:set_slot_size(math_scale(48))
    pockets:SizeToContents()

    pockets_h = pockets:GetTall()
  end

  local title_h = select(2, util.text_size(t'ui.inventory.pockets', Theme.get_font('text_normal_large')))
  local own_main, own_pockets = self.main_inventory, self.pockets
  local x, y

  if IsValid(own_main) then
    x, y = own_main.x + own_main:GetWide() + math_scale_x(12), own_main.y
  else
    x = scrw * 0.5 - main_w - math_scale(8)
    y = scrh * 0.5 - main_h * 0.5 - pockets_h * 0.5 - title_h * 0.5
  end

  if main_inventory then
    main_inventory:SetPos(x, y)
  end

  if pockets then
    pockets:SetPos(x, IsValid(own_pockets) and own_pockets.y or y + main_h + title_h + math_scale(16))
  end
end

--- Puts the panels of the equipment inventories of another player into two columns to the
-- right of a panel of theirs. Equipment inventories the player does not have are left out.
-- @param anchor [Panel the panel to the right of which the columns go; the columns go to the
--   center of the screen if it is nil]
function PANEL:lay_out_player_equipment(anchor)
  local container = self.container
  local equipment_left = vgui.Create('DIconLayout', self)
  equipment_left:SetSpaceY(math_scale(12))
  equipment_left:SetSize(math_scale_x(64))

  if anchor then
    equipment_left:MoveRightOf(anchor, math_scale_x(12))
    equipment_left:SetPos(equipment_left.x, anchor.y)
  else
    equipment_left:SetPos(ScrW() * 0.5, ScrH() * 0.25)
  end

  equipment_left.add_slot = function(pnl, id)
    local panel = container[id]

    if !panel then return end

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
  equipment_right:SetPos(equipment_right.x, equipment_left.y)
  equipment_right.add_slot = equipment_left.add_slot

  equipment_left:add_slot('equipment_back')
  equipment_left:add_slot('equipment_accessories')

  equipment_right:add_slot('equipment_helmet')
  equipment_right:add_slot('equipment_mask')
  equipment_right:add_slot('equipment_torso')
  equipment_right:add_slot('equipment_hands')
  equipment_right:add_slot('equipment_legs')
end

--- Returns the ids of the inventories that are opened in the panel.
-- @return [List<Number> ids, or nil if nothing has been opened yet]
function PANEL:get_inventory_ids()
  return self.inventory_ids
end

vgui.Register('fl_inventory_container', PANEL, 'fl_base_panel')
