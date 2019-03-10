function PLUGIN:OnContextMenuOpen()
  if IsValid(Flux.client.hotbar) then
    timer.remove('fl_hotbar_popup')

    Flux.client.hotbar:SetAlpha(255)
    Flux.client.hotbar:SetVisible(true)
    Flux.client.hotbar:MakePopup()
    Flux.client.hotbar:MoveToFront()
    Flux.client.hotbar:SetMouseInputEnabled(true)
    Flux.client.hotbar:rebuild()
  end
end

function PLUGIN:OnContextMenuClose()
  if IsValid(Flux.client.hotbar) then
    timer.remove('fl_hotbar_popup')

    Flux.client.hotbar:MoveToBack()
    Flux.client.hotbar:SetMouseInputEnabled(false)
    Flux.client.hotbar:SetKeyboardInputEnabled(false)
    Flux.client.hotbar:SetVisible(false)
    Flux.client.hotbar:rebuild()

    Flux.client.hotbar.next_popup = CurTime() + 0.5
  end
end

function Inventory:AddTabMenuItems(menu)
  menu:add_menu_item('inventory', {
    title = 'Inventory',
    panel = 'fl_inventory_menu',
    icon = 'fa-inbox',
    callback = function(menu_panel, button)
      local inv = menu_panel.active_panel
      inv:SetTitle('Inventory')
    end
  })
end

function Inventory:PostCharacterLoaded()
  if !IsValid(Flux.client.hotbar) then
    self:create_hotbar()
  end
end

function Inventory:create_hotbar()
  Flux.client.hotbar = vgui.Create('fl_hotbar')
  Flux.client.hotbar:SetVisible(false)
  Flux.client.hotbar:set_player(Flux.client)
  Flux.client.hotbar:set_slot_padding(8)
  Flux.client.hotbar:rebuild()

  return Flux.client.hotbar
end

function Inventory:popup_hotbar()
  if IsValid(Flux.client.hotbar) then
    local cur_alpha = 300

    Flux.client.hotbar:SetVisible(true)
    Flux.client.hotbar:SetAlpha(255)

    timer.create('fl_hotbar_popup', 0.01, cur_alpha, function()
      if Flux.tab_menu:IsVisible() then
        Flux.client.hotbar:SetVisible(false)
        timer.remove('fl_hotbar_popup')
      end

      cur_alpha = cur_alpha - 2

      Flux.client.hotbar:SetAlpha(cur_alpha)
    end)
  end
end

cable.receive('fl_inventory_refresh', function(inv_type, old_inv_type)
  if Flux.tab_menu and Flux.tab_menu.active_panel and Flux.tab_menu.active_panel.rebuild then
    Flux.tab_menu.active_panel:rebuild()
  end

  if IsValid(Flux.client.hotbar) then
    Flux.client.hotbar:rebuild()

    if !Flux.tab_menu:IsVisible() and inv_type == 'hotbar' or old_inv_type == 'hotbar' then
      if !Flux.client.hotbar.next_popup or Flux.client.hotbar.next_popup < CurTime() then
        Inventory:popup_hotbar()
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
