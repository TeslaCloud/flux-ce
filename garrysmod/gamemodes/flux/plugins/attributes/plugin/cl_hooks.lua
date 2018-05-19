--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flAttributes:OnThemeLoaded(activeTheme)
	activeTheme:AddPanel("CharCreation_Attributes", function(id, parent, ...)
		return vgui.Create("flCharCreationAttributes", parent)
	end)
end

function flAttributes:AddCharacterCreationMenuItems(panel, menu, sidebar)
	menu:AddButton("Attributes", function(btn)
		panel:OpenPanel("CharCreation_Attributes")
	end)
end
