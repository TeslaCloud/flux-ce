function PLUGIN:OnContextMenuOpen()
  if IsValid(PLAYER.hotbar) then
    timer.remove('fl_hotbar_popup')

    PLAYER.hotbar:SetAlpha(255)
    PLAYER.hotbar:SetVisible(true)
    PLAYER.hotbar:MakePopup()
    PLAYER.hotbar:MoveToFront()
    PLAYER.hotbar:SetMouseInputEnabled(true)
    PLAYER.hotbar:rebuild()
  end
end

function PLUGIN:OnContextMenuClose()
  if IsValid(PLAYER.hotbar) then
    timer.remove('fl_hotbar_popup')

    PLAYER.hotbar:MoveToBack()
    PLAYER.hotbar:SetMouseInputEnabled(false)
    PLAYER.hotbar:SetKeyboardInputEnabled(false)
    PLAYER.hotbar:SetVisible(false)
    PLAYER.hotbar:rebuild()

    PLAYER.hotbar.next_popup = CurTime() + 0.5
  end
end

function Inventory:AddTabMenuItems(menu)
  menu:add_menu_item('inventory', {
    title = 'Inventory',
    panel = 'fl_inventory_menu',
    icon = 'fa-inbox',
    default = true,
    callback = function(menu_panel, button)
      local inv = menu_panel.active_panel
      inv:SetTitle('Inventory')
    end
  })
end

function Inventory:PostCharacterLoaded()
  if !IsValid(PLAYER.hotbar) then
    self:create_hotbar()
  end
end

function Inventory:create_hotbar()
  PLAYER.hotbar = vgui.Create('fl_inventory_hotbar')
  PLAYER.hotbar:SetVisible(false)
  PLAYER.hotbar:set_player(PLAYER)
  PLAYER.hotbar:set_slot_padding(8)
  PLAYER.hotbar:rebuild()

  return PLAYER.hotbar
end

function Inventory:popup_hotbar()
  local cur_alpha = 300

  PLAYER.hotbar:SetVisible(true)
  PLAYER.hotbar:SetAlpha(255)

  timer.create('fl_hotbar_popup', 0.01, cur_alpha, function()
    if IsValid(Flux.tab_menu) and Flux.tab_menu:IsVisible() or cur_alpha <= 0 then
      PLAYER.hotbar:SetVisible(false)
      timer.remove('fl_hotbar_popup')
    end

    cur_alpha = cur_alpha - 2

    PLAYER.hotbar:SetAlpha(cur_alpha)
  end)
end

Cable.receive('fl_inventory_refresh', function(inv_type, old_inv_type)
  if Flux.tab_menu and Flux.tab_menu.active_panel and Flux.tab_menu.active_panel.rebuild then
    Flux.tab_menu.active_panel:rebuild()
  end

  if IsValid(PLAYER.hotbar) then
    PLAYER.hotbar:rebuild()

    if (!IsValid(Flux.tab_menu) or (IsValid(Flux.tab_menu) and !Flux.tab_menu:IsVisible())) and
    (inv_type == 'hotbar' or old_inv_type == 'hotbar') and
    !PLAYER.hotbar:IsVisible() then
      if !PLAYER.hotbar.next_popup or PLAYER.hotbar.next_popup < CurTime() then
        Inventory:popup_hotbar()
      end
    end
  end

  hook.run('OnInventoryRefresh', inv_type, old_inv_type)
end)

spawnmenu.AddCreationTab('Items', function()
  local panel = vgui.Create('fl_item_spawner')

  panel:Dock(FILL)
  panel:rebuild()

  return panel
end, 'icon16/wand.png', 40)
