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