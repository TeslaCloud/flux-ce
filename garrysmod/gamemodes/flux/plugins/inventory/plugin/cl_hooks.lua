function fl_inventory:AddTabMenuItems(menu)
  menu:AddMenuItem('inventory', {
    title = 'Inventory',
    panel = 'fl_inventory',
    icon = 'fa-inbox',
    callback = function(menuPanel, button)
      local inv = menuPanel.activePanel
      inv:SetPlayer(fl.client)
      inv:SetTitle('Inventory')
    end
  })
end

function PLUGIN:OnContextMenuOpen()
  if IsValid(fl.client.hotbar) then
    fl.client.hotbar:SetVisible(true)
    fl.client.hotbar:MakePopup()
    fl.client.hotbar:Rebuild()
    fl.client.hotbar:MoveToFront()
    fl.client.hotbar:SetMouseInputEnabled(true)
  end
end

function PLUGIN:OnContextMenuClose()
  if IsValid(fl.client.hotbar) then
    fl.client.hotbar:Rebuild()
    fl.client.hotbar:MoveToBack()
    fl.client.hotbar:SetMouseInputEnabled(false)
    fl.client.hotbar:SetKeyboardInputEnabled(false)
    fl.client.hotbar:SetVisible(false)
  end
end

function fl_inventory:create_hotbar()
  fl.client.hotbar = vgui.Create('fl_hotbar')
  fl.client.hotbar:SetPlayer(fl.client)
  fl.client.hotbar:SetVisible(false)
  return fl.client.hotbar
end

function fl_inventory:FLInitPostEntity()
  if IsValid(fl.client) then
    self:create_hotbar()
  end
end

function fl_inventory:PostCharacterLoaded()
  if !IsValid(fl.client.hotbar) then
    self:create_hotbar()
  end

  if fl.client:Alive() and fl.client:HasInitialized() then
    local hotbar = fl.client.hotbar
    local w, h = hotbar:GetSize()
    local cx, cy = ScrC()
    hotbar:SetVisible(true)
    hotbar:Rebuild()
    hotbar:SetPos(cx - w * 0.5, ScrH() - h - font.Scale(32))
  end
end

spawnmenu.AddCreationTab('Items', function()
  local panel = vgui.Create('flItemSpawner')

  panel:Dock(FILL)
  panel:Rebuild()

  return panel
end, 'icon16/wand.png', 40)

netstream.Hook('RefreshInventory', function()
  if fl.tab_menu and fl.tab_menu.activePanel and fl.tab_menu.activePanel.Rebuild then
    fl.tab_menu.activePanel:Rebuild()
  end

  if IsValid(fl.client.hotbar) then
    fl.client.hotbar:Rebuild()
  end
end)
