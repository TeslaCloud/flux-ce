--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

function flFactions:OnThemeLoaded(activeTheme)
	activeTheme:AddPanel("CharCreation_Faction", function(id, parent, ...)
		return vgui.Create("flCharCreationFaction", parent)
	end)
end

function flFactions:AddCharacterCreationMenuItems(panel, menu, sidebar)
	menu:AddButton("Faction", function(btn)
		panel:OpenPanel("CharCreation_Faction")
	end)
end