--[[
	Flux © 2016-2018 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

THEME.author = "TeslaCloud Studios"
THEME.uniqueID = "hl2rp"
THEME.parent = "factory"

function THEME:OnLoaded()
	self:SetColor("Accent", Color(220, 180, 70))

	self:SetOption("MainMenu_SidebarLogo", "flux/hl2rp/combine.png")
	self:SetOption("MenuMusic", "sound/music/hl2_song19.mp3")
	self:SetOption("Bar_Height", 7)

	self:SetMaterial("Schema_Logo", "materials/flux/hl2rp/logo.png")
	self:SetMaterial("Gradient", "materials/flux/hl2rp/gradient.png")

	self:SetFont("Text_Bar", self:GetFont("MainFont"), math.max(font.Scale(14), 14), {weight = 600})
end

function THEME:DrawBarBackground(barInfo)
	local height = self:GetOption("Bar_Height")

	draw.RoundedBoxOutline(4, barInfo.x, barInfo.y + barInfo.height - height, barInfo.width, height, 1, self:GetColor("Accent"), 2)
end

function THEME:DrawBarHindrance(barInfo)
	local length = barInfo.width * (barInfo.hinderValue / barInfo.maxValue)
	local barHeight = self:GetOption("Bar_Height")
	local barY = barInfo.y + barInfo.height - (barHeight - 2)

	draw.RoundedBox(2, barInfo.x + barInfo.width - length, barY, length - 2, barHeight - 4, barInfo.hinderColor)
end

function THEME:DrawBarFill(barInfo)
	fl.bars:HinderValue("health", 30)

	local barHeight = self:GetOption("Bar_Height")
	local barX = barInfo.x + 2
	local barY = barInfo.y + barInfo.height - (barHeight - 2)
	local height = barHeight - 4

	if (barInfo.realFillWidth < barInfo.fillWidth) then
		draw.RoundedBox(2, barX, barY, (barInfo.fillWidth or barInfo.width) - 4, height, barInfo.color)
		draw.RoundedBox(2, barX, barY, barInfo.realFillWidth - 4, height, self:GetColor("Accent"))
	elseif (barInfo.realFillWidth > barInfo.fillWidth) then
		draw.RoundedBox(2, barX, barY, barInfo.realFillWidth - 4, height, barInfo.color)
		draw.RoundedBox(2, barX, barY, (barInfo.fillWidth or barInfo.width) - 4, height, self:GetColor("Accent"))
	else
		draw.RoundedBox(2, barX, barY, (barInfo.fillWidth or barInfo.width) - 4, height, self:GetColor("Accent"))
	end
end

function THEME:DrawBarTexts(barInfo)
	local font = theme.GetFont(barInfo.font)
	local accentColor = self:GetColor("Accent")

	draw.SimpleText(barInfo.text, font, barInfo.x, barInfo.y + barInfo.textOffset - 3, accentColor)

	if (barInfo.hinderDisplay and barInfo.hinderDisplay <= barInfo.hinderValue) then
		local width = barInfo.width
		local textWide = util.GetTextSize(barInfo.hinderText, font)
		local length = width * (barInfo.hinderValue / barInfo.maxValue)

		draw.SimpleText(barInfo.hinderText, font, barInfo.x + width - textWide, barInfo.y + barInfo.textOffset - 3, accentColor)
	end
end
