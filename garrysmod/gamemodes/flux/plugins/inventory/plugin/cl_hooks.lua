function fl_inventory:AddTabMenuItems(menu)
  menu:AddMenuItem("inventory", {
    title = "Inventory",
    panel = "fl_inventory",
    icon = "fa-inbox",
    callback = function(menuPanel, button)
      local inv = menuPanel.activePanel
      inv:SetPlayer(fl.client)
      inv:SetTitle("Inventory")
    end
  })
end

function fl_inventory:create_hotbar()
  fl.client.hotbar = vgui.Create('fl_hotbar')
  return fl.client.hotbar
end

function fl_inventory:Initialize()
  self:create_hotbar()
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

spawnmenu.AddCreationTab("Items", function()
  local panel = vgui.Create("flItemSpawner")

  panel:Dock(FILL)
  panel:Rebuild()

  return panel
end, "icon16/wand.png", 40)

netstream.Hook("RefreshInventory", function()
  if fl.tabMenu and fl.tabMenu.activePanel and fl.tabMenu.activePanel.Rebuild then
    fl.tabMenu.activePanel:Rebuild()
  end
end)
