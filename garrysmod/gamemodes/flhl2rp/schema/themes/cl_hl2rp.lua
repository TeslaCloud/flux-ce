--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

THEME.author = "TeslaCloud Studios"
THEME.uniqueID = "hl2rp"
THEME.parent = "factory"
THEME.shouldReload = true

function THEME:OnLoaded()
	self:SetOption("MainMenu_SidebarLogo", "flux/hl2rp/combine.png")
	self:SetOption("MenuMusic", "sound/music/hl2_song19.mp3")

	self:SetMaterial("Schema_Logo", "materials/flux/hl2rp/logo.png")
end