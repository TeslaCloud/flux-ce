--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

THEME.author = "TeslaCloud Studios"
THEME.uniqueID = "hl2rp"
THEME.parent = "factory"

function THEME:OnLoaded()
	self:SetOption("MainMenu_SidebarLogo", "flux/hl2rp/combine.png")
	self:SetOption("MenuMusic", "sound/music/hl2_song19.mp3")

	self:SetMaterial("Schema_Logo", "materials/flux/hl2rp/logo.png")
	self:SetMaterial("Gradient", "materials/flux/hl2rp/gradient.png")
end

function THEME:DrawBarBackground(barInfo)
	surface.SetDrawColor(150, 150, 150, 200)
	surface.SetMaterial(self:GetMaterial("Gradient"))
	surface.DrawTexturedRect(barInfo.x, barInfo.y, barInfo.width, barInfo.height)
end

function THEME:DrawBarFill(barInfo)
	local color = barInfo.color:Darken(10)
	local x, y, w, h = barInfo.x, barInfo.y, barInfo.width, barInfo.height

	surface.SetDrawColor(color.r, color.g, color.b, 255)
	surface.SetMaterial(self:GetMaterial("Gradient"))

	render.SetScissorRect(x, y, x + (barInfo.fillWidth or w), y + h, true)
		surface.DrawTexturedRect(x, y, w, h)
	render.SetScissorRect(0, 0, 0, 0, false)
end

function THEME:DrawBarHindrance(barInfo)
	local length = barInfo.width * (barInfo.hinderValue / barInfo.maxValue)
	local color = barInfo.hinderColor:Darken(10)
	local y, h = barInfo.y, barInfo.height
	local hx = barInfo.x + barInfo.width - length

	surface.SetDrawColor(color.r, color.g, color.b, 255)
	surface.SetMaterial(self:GetMaterial("Gradient"))

	render.SetScissorRect(hx, y, hx + length, y + h, true)
		surface.DrawTexturedRect(hx, y, length, h)
	render.SetScissorRect(0, 0, 0, 0, false)
end