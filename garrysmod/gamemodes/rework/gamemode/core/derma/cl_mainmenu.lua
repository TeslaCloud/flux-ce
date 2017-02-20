--[[
	Rework © 2016-2017 TeslaCloud Studios
	Do not share or re-distribute before
	the framework is publicly released.
--]]

local PANEL = {}
PANEL.prevButton = nil

function PANEL:Init()
	self:SetPos(0, 0)
	self:SetSize(ScrW(), ScrH())

	self:RecreateSidebar(true)

	self:MakePopup()

	theme.Hook("CreateMainMenu", self)
end

function PANEL:Paint(w, h)
	theme.Hook("PaintMainMenu", self, w, h)
end

function PANEL:Think()
	theme.Hook("MainMenuThink", self)
end

function PANEL:RecreateSidebar(bShouldCreateButtons)
	if (IsValid(self.sidebar)) then
		self.sidebar:SafeRemove()
	end

	-- Hot Fix for an error that occurred when auto-reloading while in initial main menu.
	if (!theme.GetOption("MainMenu_SidebarLogo")) then
		timer.Simple(0.05, function() self:RecreateSidebar(true) end)

		return
	end

	self.sidebar = vgui.Create("rwSidebar", self)
	self.sidebar:SetPos(theme.GetOption("MainMenu_SidebarX"), theme.GetOption("MainMenu_SidebarY"))
	self.sidebar:SetSize(theme.GetOption("MainMenu_SidebarWidth"), theme.GetOption("MainMenu_SidebarHeight"))
	self.sidebar:SetMargin(theme.GetOption("MainMenu_SidebarMargin"))
	self.sidebar:AddSpace(8)

	self.logo = vgui.Create("DImage", self)
	self.logo:SetSize(theme.GetOption("MainMenu_LogoWidth"), theme.GetOption("MainMenu_LogoHeight"))
	self.logo:SetImage(theme.GetOption("MainMenu_SidebarLogo"))

	self.sidebar:AddPanel(self.logo, true)

	self.sidebar:AddSpace(theme.GetOption("MainMenu_SidebarLogoSpace"))

	if (bShouldCreateButtons) then
		hook.Run("AddMainMenuItems", self, self.sidebar)
	else
		local backButton = vgui.Create("rwButton")
		backButton:SetSize(theme.GetOption("MainMenu_SidebarWidth"), theme.GetOption("MainMenu_SidebarButtonHeight"))
		backButton:SetIcon("fa-chevron-left")
		backButton:SetIconSize(16)
		backButton:SetFont(theme.GetFont("Text_NormalSmaller"))
		backButton:SetTitle("BACK")

		backButton.DoClick = function(btn)
			self:RecreateSidebar(true)

			if (self.menu.Close) then
				self.menu:Close()
			else
				self.menu:SafeRemove()
			end
		end

		self.sidebar:AddPanel(backButton)
		self.sidebar:AddSpace(9)
	end
end

function PANEL:OpenMenu(panel, data)
	if (!IsValid(self.menu)) then
		self.menu = theme.CreatePanel(panel, self)

		if (self.menu.SetData) then
			self.menu:SetData(data)
		end
	else
		if (self.menu.Close) then
			self.menu:Close(function()
				self:OpenMenu(panel, data)
			end)
		else
			self.menu:SafeRemove()
			self:OpenMenu(panel, data)
		end
	end
end

function PANEL:AddButton(text, callback)
	local button = vgui.Create("rwButton", self)
	button:SetSize(theme.GetOption("MainMenu_SidebarWidth"), theme.GetOption("MainMenu_SidebarButtonHeight"))
	button:SetText(text)
	button:SetDrawBackground(true)
	button:SetFont(theme.GetFont("Text_NormalSmaller"))
	button:SetTextAutoposition(true)

	button.DoClick = function(btn)
		btn:SetActive(true)

		if (IsValid(self.prevButton) and self.prevButton != btn) then
			self.prevButton:SetActive(false)
		end

		self.prevButton = btn

		if (isfunction(callback)) then
			callback(btn)
		elseif (isstring(callback)) then
			self:OpenMenu(callback)
		end
	end

	self.sidebar:AddPanel(button)

	return button
end

vgui.Register("rwMainMenu", PANEL, "EditablePanel");