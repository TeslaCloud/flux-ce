function PLUGIN:OnContextMenuOpen()
  if IsValid(fl.client.hotbar) then
    fl.client.hotbar:SetVisible(true)
    fl.client.hotbar:MakePopup()
    fl.client.hotbar:rebuild()
    fl.client.hotbar:MoveToFront()
    fl.client.hotbar:SetMouseInputEnabled(true)
  end
end

function PLUGIN:OnContextMenuClose()
  if IsValid(fl.client.hotbar) then
    fl.client.hotbar:rebuild()
    fl.client.hotbar:MoveToBack()
    fl.client.hotbar:SetMouseInputEnabled(false)
    fl.client.hotbar:SetKeyboardInputEnabled(false)
    fl.client.hotbar:SetVisible(false)
  end
end

function Inventory:AddTabMenuItems(menu)
  menu:add_menu_item('inventory', {
    title = 'Inventory',
    panel = 'Inventory',
    icon = 'fa-inbox',
    callback = function(menu_panel, button)
      local inv = menu_panel.active_panel
      inv:set_player(fl.client)
      inv:SetTitle('Inventory')
    end
  })
end

function Inventory:FLInitPostEntity()
  if IsValid(fl.client) then
    self:create_hotbar()
  end
end

function Inventory:PostCharacterLoaded()
  if !IsValid(fl.client.hotbar) then
    self:create_hotbar()
  end

  if fl.client:Alive() and fl.client:has_initialized() then
    local hotbar = fl.client.hotbar
    local w, h = hotbar:GetSize()
    local cx, cy = ScrC()
    hotbar:SetVisible(true)
    hotbar:rebuild()
    hotbar:SetPos(cx - w * 0.5, ScrH() - h - font.scale(32))
  end
end

function Inventory:create_hotbar()
  fl.client.hotbar = vgui.Create('fl_hotbar')
  fl.client.hotbar:SetVisible(false)
  fl.client.hotbar:set_player(fl.client)
  fl.client.hotbar:rebuild()

  return fl.client.hotbar
end

cable.receive('fl_inventory_refresh', function()
  if fl.tab_menu and fl.tab_menu.active_panel and fl.tab_menu.active_panel.rebuild then
    fl.tab_menu.active_panel:rebuild()
  end

  if IsValid(fl.client.hotbar) then
    fl.client.hotbar:rebuild()
  end
end)

spawnmenu.AddCreationTab('Items', function()
  local panel = vgui.Create('fl_item_spawner')

  panel:Dock(FILL)
  panel:rebuild()

  return panel
end, 'icon16/wand.png', 40)
