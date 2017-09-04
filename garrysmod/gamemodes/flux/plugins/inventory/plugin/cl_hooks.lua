function flInventory:AddTabMenuItems(menu)
	menu:AddMenuItem("inventory", {
		title = "Inventory",
		panel = "flInventory",
		icon = "fa-inbox",
		callback = function(menuPanel, button)
			local inv = menuPanel.activePanel
			inv:SetPlayer(fl.client)
			inv:SetTitle("Inventory")
		end
	})
end

spawnmenu.AddCreationTab("Items", function()
	local panel = vgui.Create("flItemSpawner")

	panel:Dock(FILL)
	panel:Rebuild()

	return panel
end, "icon16/wand.png", 40)