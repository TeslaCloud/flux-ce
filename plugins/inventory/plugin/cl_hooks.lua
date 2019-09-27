function Inventories:OnContextMenuOpen()
  PLAYER.hotbar = Inventories:create_hotbar()

  timer.remove('fl_hotbar_popup')

  PLAYER.hotbar:SetAlpha(255)
  PLAYER.hotbar:SetVisible(true)
  PLAYER.hotbar:MakePopup()
  PLAYER.hotbar:MoveToFront()
  PLAYER.hotbar:SetMouseInputEnabled(true)
  PLAYER.hotbar:rebuild()
end

function Inventories:OnContextMenuClose()
  if IsValid(PLAYER.hotbar) then
    timer.remove('fl_hotbar_popup')

    PLAYER.hotbar:MoveToBack()
    PLAYER.hotbar:SetMouseInputEnabled(false)
    PLAYER.hotbar:SetKeyboardInputEnabled(false)
    PLAYER.hotbar:SetVisible(false)

    PLAYER.hotbar.next_popup = CurTime() + 0.5
  end
end

function Inventories:AddTabMenuItems(menu)
  menu:add_menu_item('inventory', {
    title = 'Inventory',
    panel = 'fl_inventory_menu',
    icon = 'fa-briefcase',
    default = true,
    callback = function(menu_panel, button)
      local inv = menu_panel.active_panel
      inv:SetTitle('Inventory')
    end
  })
end

function Inventories:create_hotbar()
  local hotbar = PLAYER:get_inventory('hotbar'):create_panel()
  hotbar:set_slot_size(math.scale(80))
  hotbar:set_slot_padding(math.scale(8))
  hotbar:draw_inventory_slots(true)
  hotbar:set_title()
  hotbar:SizeToContents()
  hotbar:SetPos(ScrW() * 0.5 - hotbar:GetWide() * 0.5, ScrH() - hotbar:GetTall() - math.scale(16))

  return hotbar
end

function Inventories:popup_hotbar()
  local cur_alpha = 300

  PLAYER.hotbar:SetVisible(true)
  PLAYER.hotbar:SetAlpha(255)
  PLAYER.hotbar:rebuild()

  timer.create('fl_hotbar_popup', 0.01, cur_alpha, function()
    if IsValid(Flux.tab_menu) and Flux.tab_menu:IsVisible() or cur_alpha <= 0 then
      PLAYER.hotbar:SetVisible(false)
      timer.remove('fl_hotbar_popup')
    end

    cur_alpha = cur_alpha - 2

    PLAYER.hotbar:SetAlpha(cur_alpha)
  end)
end

Cable.receive('fl_inventory_sync', function(data)
  local inventory = Inventories.stored[data.id] or Inventory.new(data.id)
  inventory.id = data.id
  inventory.type = data.inv_type
  inventory.width = data.width
  inventory.height = data.height
  inventory.slots = data.slots
  inventory.multislot = data.multislot
  inventory.owner = data.owner

  if data.owner and data.owner == PLAYER then
    PLAYER.inventories = PLAYER.inventories or {}
    PLAYER.inventories[inventory.type] = inventory
  end

  if IsValid(inventory.panel) then
    inventory.panel:rebuild()
  end

  hook.run('OnInventorySync', inventory)
end)

Cable.receive('fl_create_hotbar', function()
  PLAYER.hotbar = Inventories:create_hotbar()
  PLAYER.hotbar:SetVisible(false)
end)

Cable.receive('fl_rebuild_player_panel', function()
  if IsValid(Flux.tab_menu) and Flux.tab_menu:IsVisible() then
    local active_panel = Flux.tab_menu.active_panel

    if IsValid(active_panel) and active_panel.id == 'inventory' then
      local player_model = active_panel.player_model

      if IsValid(player_model) then
        player_model:rebuild()
      end
    end
  end
end)

spawnmenu.AddCreationTab('Items', function()
  local panel = vgui.Create('fl_item_spawner')

  panel:Dock(FILL)
  panel:rebuild()

  return panel
end, 'icon16/wand.png', 40)
