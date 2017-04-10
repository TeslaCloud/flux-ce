--[[
	Flux © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

-- Create the default theme that other themes will derive from.
THEME.author = "TeslaCloud Studios"
THEME.uniqueID = "factory"
THEME.shouldReload = true

function THEME:OnLoaded()
	local scrW, scrH = ScrW(), ScrH()

	self:SetOption("Frame_HeaderSize", 24)
	self:SetOption("Frame_LineWeight", 2)
	self:SetOption("MainMenu_SidebarWidth", 200)
	self:SetOption("MainMenu_SidebarHeight", scrH)
	self:SetOption("MainMenu_SidebarX", 0)
	self:SetOption("MainMenu_SidebarY", 0)
	self:SetOption("MainMenu_SidebarMargin", -1)
	self:SetOption("MainMenu_SidebarLogo", "flux/flux_icon.png")
	self:SetOption("MainMenu_SidebarLogoSpace", 16)
	self:SetOption("MainMenu_SidebarButtonHeight", font.Scale(42)) -- We can cheat and scale buttons the same way we scale fonts!
	self:SetOption("MainMenu_LogoHeight", 100)
	self:SetOption("MainMenu_LogoWidth", 110)
	self:SetOption("FinishButtonOffsetX", 0)
	self:SetOption("FinishButtonOffsetY", 0)
	self:SetOption("MenuMusic", "")

	self:SetColor("Accent", Color(90, 90, 190))
	self:SetColor("Main", Color(50, 50, 50))
	self:SetColor("MainDark", Color(40, 40, 40))
	self:SetColor("Outline", Color(65, 65, 65))
	self:SetColor("Background", Color(20, 20, 20))
	self:SetColor("Text", Color(255, 255, 255))
	self:SetColor("SchemaText", Color(255, 255, 255))
	self:SetColor("MainMenu_Background", Color(0, 0, 0))

	self:SetFont("MenuTitles", "fl_frame_title")
	self:SetFont("Text_3D2D", "flMainFont", 128)
	self:SetFont("Text_Largest", "flMainFont", font.Scale(90))
	self:SetFont("Text_Larger", "flMainFont", font.Scale(60))
	self:SetFont("Text_Large", "flMainFont", font.Scale(48))
	self:SetFont("Text_NormalLarge", "flMainFont", font.Scale(36))
	self:SetFont("Text_Normal", "flMainFont", font.Scale(24))
	self:SetFont("Text_NormalSmaller", "flMainFont", font.Scale(22))
	self:SetFont("Text_Small", "flMainFont", font.Scale(18))
	self:SetFont("Text_Smaller", "flMainFont", font.Scale(16))
	self:SetFont("Text_Smallest", "flMainFont", font.Scale(14))
	self:SetFont("Text_Tiny", "flMainFont", font.Scale(11))

	-- Set from schema theme.
	-- self:SetMaterial("Schema_Logo", "materials/flux/hl2rp/logo.png")

	self:AddPanel("TabMenu", function(id, parent, ...)
		return vgui.Create("flTabMenu", parent)
	end)

	self:AddPanel("MainMenu", function(id, parent, ...)
		return vgui.Create("flMainMenu", parent)
	end)

	self:AddPanel("CharacterCreation", function(id, parent, ...)
		return vgui.Create("flCharacterCreation", parent)
	end)

	self:AddPanel("CharCreation_General", function(id, parent, ...)
		return vgui.Create("flCharCreationGeneral", parent)
	end)

	self:AddPanel("CharCreation_Model", function(id, parent, ...)
		return vgui.Create("flCharCreationModel", parent)
	end)

	self:AddPanel("CharCreation_Faction", function(id, parent, ...)
		return vgui.Create("flCharCreationFaction", parent)
	end)
end

function THEME:CreateMainMenu(panel) end

function THEME:PaintFrame(panel, width, height)
	local title = panel:GetTitle()
	local accentColor = panel:GetAccentColor()
	local headerSize = self:GetOption("Frame_HeaderSize")
	local lineWeight = self:GetOption("Frame_LineWeight")

	surface.SetDrawColor(accentColor)
	surface.DrawRect(0, 0, width, headerSize)

	surface.SetDrawColor(accentColor:Darken(30))
	surface.DrawRect(0, headerSize - lineWeight, width, lineWeight)

	surface.SetDrawColor(self:GetColor("MainDark"))
	surface.DrawRect(0, headerSize, width, height - headerSize)

	if (title) then
		local font = font.GetSize(self:GetFont("Text_Small"), 16)
		local _, fontSize = util.GetFontSize(font)

		draw.SimpleText(title, font, 6, 3 * (16 / fontSize), panel:GetTextColor())
	end
end

function THEME:PaintMainMenu(panel, width, height)
	local wide = self:GetOption("MainMenu_SidebarWidth") / 2
	local title, desc = Schema:GetName(), Schema:GetDescription()
	local logo = self:GetMaterial("Schema_Logo")
	local titleW, titleH = util.GetTextSize(title, self:GetFont("Text_Largest"))
	local descW, descH = util.GetTextSize(desc, self:GetFont("Text_Normal"))

	surface.SetDrawColor(self:GetColor("MainMenu_Background"))
	surface.DrawRect(0, 0, width, width)

	if (!logo) then
		draw.SimpleText(title, self:GetFont("Text_Largest"), wide + width / 2 - titleW / 2, 150, self:GetColor("SchemaText"))
	else
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(logo)
		surface.DrawTexturedRect(wide + width / 2 - 300, 150, 600, 130)
	end

	draw.SimpleText(desc, self:GetFont("Text_Normal"), wide + width / 2 - descW / 2, 350, self:GetColor("SchemaText"))
end

function THEME:PaintButton(panel, w, h)
	local curAmt = panel.m_CurAmt
	local textColor = panel.m_TextColorOverride or self:GetColor("Text"):Darken(curAmt)
	local title = panel.m_Title
	local font = panel.m_Font
	local icon = panel.m_Icon

	if (panel.m_DrawBackground) then
		if (!panel.m_Active) then
			surface.SetDrawColor(self:GetColor("Outline"))
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(self:GetColor("Main"):Lighten(curAmt))
			surface.DrawRect(1, 1, w - 2, h - 2)
		else
			surface.SetDrawColor(self:GetColor("Outline"))
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(self:GetColor("MainDark"))
			surface.DrawRect(1, 1, w - 1, h - 2)
		end
	end

	if (icon) then
		fl.fa:Draw(icon, (panel.m_IconSize and h / 2 - panel.m_IconSize / 2) or 3, (panel.m_IconSize and h / 2 - panel.m_IconSize / 2) or 3, (panel.m_IconSize or h - 6), textColor)
	end

	if (title and title != "") then
		local width, height = util.GetTextSize(title, font)

		if (panel.m_Autopos) then
			if (icon) then
				draw.SimpleText(title, font, h + 2, h / 2 - height / 2, textColor)
			else
				draw.SimpleText(title, font, w / 2 - width / 2, h / 2 - height / 2, textColor)
			end
		else
			draw.SimpleText(title, font, 0, h / 2 - height / 2, textColor)
		end
	end
end

function THEME:PaintSidebar(panel, width, height)
	draw.RoundedBox(0, 0, 0, width, height, self:GetColor("MainDark"):Lighten(10))
end

function THEME:DrawBarBackground(barInfo)
	draw.RoundedBox(barInfo.cornerRadius, barInfo.x, barInfo.y, barInfo.width, barInfo.height, self:GetColor("MainDark"))
end

function THEME:DrawBarHindrance(barInfo)
	local length = barInfo.width * (barInfo.hinderValue / barInfo.maxValue)

	draw.RoundedBox(barInfo.cornerRadius, barInfo.x + barInfo.width - length - 1, barInfo.y + 1, length, barInfo.height - 2, barInfo.hinderColor)
end

function THEME:DrawBarFill(barInfo)
	draw.RoundedBox(barInfo.cornerRadius, barInfo.x + 1, barInfo.y + 1, (barInfo.fillWidth or barInfo.width) - 2, barInfo.height - 2, barInfo.color)
end

function THEME:DrawBarTexts(barInfo)
	draw.SimpleText(barInfo.text, barInfo.font, barInfo.x + 8, barInfo.y + barInfo.textOffset, Color(255, 255, 255))

	if (barInfo.hinderDisplay and barInfo.hinderDisplay <= barInfo.hinderValue) then
		local width = barInfo.width
		local textWide = util.GetTextSize(barInfo.hinderText, barInfo.font)
		local length = width * (barInfo.hinderValue / barInfo.maxValue)

		render.SetScissorRect(barInfo.x + width - length, barInfo.y, barInfo.x + width, barInfo.y + barInfo.height, true)
			draw.SimpleText(barInfo.hinderText, barInfo.font, barInfo.x + width - textWide - 8, barInfo.y + barInfo.textOffset, Color(255, 255, 255))
		render.SetScissorRect(0, 0, 0, 0, false)
	end
end

function THEME:AdminPanelPaintOver(panel, width, height)
	local smallestFont = font.GetSize(self:GetFont("Text_Smallest"), 14)
	local textColor = self:GetColor("Text")
	local versionString = "Admin Mod Version: v0.2.0 (indev)"

	DisableClipping(true)
		draw.RoundedBox(0, 0, height, width, 16, self:GetColor("Background"))

		draw.SimpleText(fl.client:SteamName().." ("..fl.client:GetUserGroup()..")", smallestFont, 6, height + 1, textColor)

		local w, h = util.GetTextSize(versionString, smallestFont)

		draw.SimpleText(versionString, smallestFont, width - w - 6, height + 1, textColor)
	DisableClipping(false)
end